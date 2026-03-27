/// SmartDiet AI - On-device central-object segmentation service.
///
/// Runs a MobileSAM-style ONNX encoder/decoder on the phone and returns a
/// foreground extent hint that can be injected into the RAG + LLM pipeline.
/// This is a scale cue, not a direct physical measurement.
library;

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

class MaskSamplePoint {
  final double xPx;
  final double yPx;

  const MaskSamplePoint({required this.xPx, required this.yPx});

  Map<String, double> toMap() => <String, double>{'x': xPx, 'y': yPx};
}

class VolumeEstimationResult {
  final int imageWidthPx;
  final int imageHeightPx;
  final int bboxLeftPx;
  final int bboxTopPx;
  final int bboxWidthPx;
  final int bboxHeightPx;
  final double foodPixelRatio;
  final double bboxWidthRatio;
  final double bboxHeightRatio;
  final double bboxCenterXRatio;
  final double bboxCenterYRatio;
  final double iouScore;
  final String confidence;
  final Uint8List? maskOverlayPngBytes;
  final List<MaskSamplePoint> maskSamplePoints;

  const VolumeEstimationResult({
    required this.imageWidthPx,
    required this.imageHeightPx,
    required this.bboxLeftPx,
    required this.bboxTopPx,
    required this.bboxWidthPx,
    required this.bboxHeightPx,
    required this.foodPixelRatio,
    required this.bboxWidthRatio,
    required this.bboxHeightRatio,
    required this.bboxCenterXRatio,
    required this.bboxCenterYRatio,
    required this.iouScore,
    required this.confidence,
    required this.maskOverlayPngBytes,
    required this.maskSamplePoints,
  });

  const VolumeEstimationResult.none()
    : imageWidthPx = 0,
      imageHeightPx = 0,
      bboxLeftPx = 0,
      bboxTopPx = 0,
      bboxWidthPx = 0,
      bboxHeightPx = 0,
      foodPixelRatio = 0,
      bboxWidthRatio = 0,
      bboxHeightRatio = 0,
      bboxCenterXRatio = 0,
      bboxCenterYRatio = 0,
      iouScore = 0,
      confidence = 'none',
      maskOverlayPngBytes = null,
      maskSamplePoints = const <MaskSamplePoint>[];

  bool get hasEstimate =>
      confidence != 'none' && bboxWidthPx > 0 && bboxHeightPx > 0;
  bool get hasMaskOverlay =>
      maskOverlayPngBytes != null && maskOverlayPngBytes!.isNotEmpty;
  bool get hasMaskSamplePoints => maskSamplePoints.length >= 8;

  String toPromptContext() {
    if (!hasEstimate) {
      return '';
    }
    return 'MobileSAM on-device segmentation: the centered foreground object mask covers '
        '~${(foodPixelRatio * 100).toStringAsFixed(0)}% of the image, with a tight bbox spanning '
        '~${(bboxWidthRatio * 100).toStringAsFixed(0)}% of image width and '
        '~${(bboxHeightRatio * 100).toStringAsFixed(0)}% of image height. '
        'The bbox center is near ${(bboxCenterXRatio * 100).toStringAsFixed(0)}% × '
        '${(bboxCenterYRatio * 100).toStringAsFixed(0)}% of the frame. '
        'Segmentation confidence: $confidence (IoU ${(iouScore * 100).toStringAsFixed(0)}%). '
        'Use this as a foreground extent cue only, not as direct physical centimeters unless combined with AR or other scale cues.';
  }
}

class VolumeService {
  static final VolumeService _instance = VolumeService._internal();
  static const String encoderAssetPath = 'assets/models/mobilesam_encoder.onnx';
  static const String decoderAssetPath = 'assets/models/mobilesam_decoder.onnx';
  static const int samInputSize = 1024;
  static const int lowResMaskSize = 256;

  factory VolumeService() => _instance;
  VolumeService._internal();

  OrtSession? _encoderSession;
  OrtSession? _decoderSession;
  bool _initAttempted = false;

  Future<VolumeEstimationResult> estimateVolume({
    required Uint8List imageBytes,
  }) async {
    if (kIsWeb) {
      return const VolumeEstimationResult.none();
    }

    final source = img.decodeImage(imageBytes);
    if (source == null) {
      return const VolumeEstimationResult.none();
    }

    final ready = await _ensureInitialized();
    if (!ready || _encoderSession == null || _decoderSession == null) {
      return const VolumeEstimationResult.none();
    }

    final prepared = _prepareImage(img.bakeOrientation(source));
    final result = await _runPromptedSegmentation(prepared);
    return result ?? const VolumeEstimationResult.none();
  }

  Future<bool> _ensureInitialized() async {
    if (_encoderSession != null && _decoderSession != null) {
      return true;
    }
    if (_initAttempted) {
      return false;
    }

    _initAttempted = true;
    try {
      OrtEnv.instance.init();
      final options = OrtSessionOptions();
      options.setIntraOpNumThreads(2);
      options.setSessionGraphOptimizationLevel(
        GraphOptimizationLevel.ortEnableAll,
      );

      final encoderAsset = await rootBundle.load(encoderAssetPath);
      final decoderAsset = await rootBundle.load(decoderAssetPath);
      _encoderSession = OrtSession.fromBuffer(
        encoderAsset.buffer.asUint8List(),
        options,
      );
      _decoderSession = OrtSession.fromBuffer(
        decoderAsset.buffer.asUint8List(),
        options,
      );
      return true;
    } catch (_) {
      _encoderSession?.release();
      _decoderSession?.release();
      _encoderSession = null;
      _decoderSession = null;
      return false;
    }
  }

  Future<VolumeEstimationResult?> _runPromptedSegmentation(
    _PreparedImage prepared,
  ) async {
    final encoderSession = _encoderSession;
    final decoderSession = _decoderSession;
    if (encoderSession == null || decoderSession == null) {
      return null;
    }

    final runOptions = OrtRunOptions();
    final encoderTensor = OrtValueTensor.createTensorWithDataList(
      <Float32List>[prepared.tensor],
      <int>[1, 3, samInputSize, samInputSize],
    );

    OrtValueTensor? imageEmbeddings;
    OrtValueTensor? pointCoordsTensor;
    OrtValueTensor? pointLabelsTensor;
    OrtValueTensor? maskInputTensor;
    OrtValueTensor? hasMaskTensor;
    OrtValueTensor? originalSizeTensor;
    List<OrtValue?>? decoderOutputs;

    try {
      final encoderInputs = <String, OrtValue>{
        encoderSession.inputNames.first: encoderTensor,
      };
      final encoderOutputs = encoderSession.run(runOptions, encoderInputs);
      imageEmbeddings = encoderOutputs.first as OrtValueTensor?;
      if (imageEmbeddings == null) {
        return null;
      }

      final prompts = _buildPromptTensors(prepared);
      pointCoordsTensor = prompts.pointCoords;
      pointLabelsTensor = prompts.pointLabels;
      maskInputTensor = OrtValueTensor.createTensorWithDataList(
        <Float32List>[Float32List(lowResMaskSize * lowResMaskSize)],
        <int>[1, 1, lowResMaskSize, lowResMaskSize],
      );
      hasMaskTensor = OrtValueTensor.createTensorWithDataList(
        <Float32List>[
          Float32List.fromList(<double>[0]),
        ],
        <int>[1],
      );
      originalSizeTensor = OrtValueTensor.createTensorWithDataList(
        <Float32List>[
          Float32List.fromList(<double>[
            prepared.originalHeight.toDouble(),
            prepared.originalWidth.toDouble(),
          ]),
        ],
        <int>[2],
      );

      final decoderInputs = <String, OrtValue>{
        _decoderInputName(decoderSession, 'image_embeddings'): imageEmbeddings,
        _decoderInputName(decoderSession, 'point_coords'): pointCoordsTensor,
        _decoderInputName(decoderSession, 'point_labels'): pointLabelsTensor,
        _decoderInputName(decoderSession, 'mask_input'): maskInputTensor,
        _decoderInputName(decoderSession, 'has_mask_input'): hasMaskTensor,
        _decoderInputName(decoderSession, 'orig_im_size'): originalSizeTensor,
      };
      decoderOutputs = decoderSession.run(runOptions, decoderInputs);
      return _postProcessMask(prepared, decoderOutputs);
    } catch (_) {
      return null;
    } finally {
      encoderTensor.release();
      imageEmbeddings?.release();
      pointCoordsTensor?.release();
      pointLabelsTensor?.release();
      maskInputTensor?.release();
      hasMaskTensor?.release();
      originalSizeTensor?.release();
      runOptions.release();
      if (decoderOutputs != null) {
        for (final value in decoderOutputs) {
          value?.release();
        }
      }
    }
  }

  String _decoderInputName(OrtSession session, String preferredName) {
    for (final name in session.inputNames) {
      if (name.toLowerCase() == preferredName) {
        return name;
      }
    }
    return preferredName;
  }

  _PromptTensors _buildPromptTensors(_PreparedImage prepared) {
    final scale = prepared.scale;
    final maxX = math.max(prepared.originalWidth - 2, 1).toDouble();
    final maxY = math.max(prepared.originalHeight - 2, 1).toDouble();
    final centerX = (prepared.originalWidth / 2) * scale;
    final centerY = (prepared.originalHeight / 2) * scale;

    final coords = Float32List.fromList(<double>[
      centerX,
      centerY,
      1 * scale,
      1 * scale,
      maxX * scale,
      1 * scale,
      1 * scale,
      maxY * scale,
      maxX * scale,
      maxY * scale,
    ]);
    final labels = Float32List.fromList(<double>[1, 0, 0, 0, 0]);

    return _PromptTensors(
      pointCoords: OrtValueTensor.createTensorWithDataList(
        <Float32List>[coords],
        <int>[1, 5, 2],
      ),
      pointLabels: OrtValueTensor.createTensorWithDataList(
        <Float32List>[labels],
        <int>[1, 5],
      ),
    );
  }

  VolumeEstimationResult? _postProcessMask(
    _PreparedImage prepared,
    List<OrtValue?> outputs,
  ) {
    if (outputs.length < 2 || outputs.first == null || outputs[1] == null) {
      return null;
    }

    final maskTensor = outputs.first!.value;
    final iouTensor = outputs[1]!.value;
    if (maskTensor is! List || iouTensor is! List || maskTensor.isEmpty) {
      return null;
    }

    final iouList = _flattenNums(iouTensor);
    if (iouList.isEmpty) {
      return null;
    }
    var bestIndex = 0;
    var bestScore = iouList.first;
    for (var index = 1; index < iouList.length; index++) {
      if (iouList[index] > bestScore) {
        bestScore = iouList[index];
        bestIndex = index;
      }
    }

    final maskCandidates = maskTensor.first;
    if (maskCandidates is! List || maskCandidates.length <= bestIndex) {
      return null;
    }
    final bestMask = maskCandidates[bestIndex];
    if (bestMask is! List || bestMask.isEmpty) {
      return null;
    }

    final rows = bestMask.length;
    final cols = (bestMask.first as List).length;
    var minX = cols;
    var minY = rows;
    var maxX = -1;
    var maxY = -1;
    var area = 0;

    for (var y = 0; y < rows; y++) {
      final row = bestMask[y] as List;
      for (var x = 0; x < cols; x++) {
        final value = (row[x] as num).toDouble();
        if (value <= 0) {
          continue;
        }
        area++;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }

    if (area < 64 || maxX < minX || maxY < minY) {
      return null;
    }

    final bboxWidth = maxX - minX + 1;
    final bboxHeight = maxY - minY + 1;
    final imageArea = prepared.originalWidth * prepared.originalHeight;
    final maskAreaRatio = area / imageArea;
    final bboxWidthRatio = bboxWidth / prepared.originalWidth;
    final bboxHeightRatio = bboxHeight / prepared.originalHeight;
    final centerXRatio = (minX + bboxWidth / 2) / prepared.originalWidth;
    final centerYRatio = (minY + bboxHeight / 2) / prepared.originalHeight;
    final overlayBytes = _buildMaskOverlay(
      bestMask: bestMask,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
      imageWidth: prepared.originalWidth,
      imageHeight: prepared.originalHeight,
    );
    final maskSamplePoints = _buildMaskSamplePoints(
      bestMask: bestMask,
      imageWidth: prepared.originalWidth,
      imageHeight: prepared.originalHeight,
      minX: minX,
      minY: minY,
      maxX: maxX,
      maxY: maxY,
    );

    return VolumeEstimationResult(
      imageWidthPx: prepared.originalWidth,
      imageHeightPx: prepared.originalHeight,
      bboxLeftPx: minX,
      bboxTopPx: minY,
      bboxWidthPx: bboxWidth,
      bboxHeightPx: bboxHeight,
      foodPixelRatio: maskAreaRatio,
      bboxWidthRatio: bboxWidthRatio,
      bboxHeightRatio: bboxHeightRatio,
      bboxCenterXRatio: centerXRatio,
      bboxCenterYRatio: centerYRatio,
      iouScore: bestScore,
      confidence: _confidenceLabel(bestScore, maskAreaRatio),
      maskOverlayPngBytes: overlayBytes,
      maskSamplePoints: maskSamplePoints,
    );
  }

  List<MaskSamplePoint> _buildMaskSamplePoints({
    required List bestMask,
    required int imageWidth,
    required int imageHeight,
    required int minX,
    required int minY,
    required int maxX,
    required int maxY,
  }) {
    final points = <MaskSamplePoint>[];
    final maskHeight = bestMask.length;
    final maskWidth = (bestMask.first as List).length;
    final cellCols = 8;
    final cellRows = 6;

    final spanX = math.max(1, maxX - minX + 1);
    final spanY = math.max(1, maxY - minY + 1);

    for (var rowIndex = 0; rowIndex < cellRows; rowIndex++) {
      final cellTop = minY + ((rowIndex * spanY) / cellRows).floor();
      final cellBottom =
          minY + (((rowIndex + 1) * spanY) / cellRows).ceil() - 1;
      for (var colIndex = 0; colIndex < cellCols; colIndex++) {
        final cellLeft = minX + ((colIndex * spanX) / cellCols).floor();
        final cellRight =
            minX + (((colIndex + 1) * spanX) / cellCols).ceil() - 1;

        double? sampleX;
        double? sampleY;
        double bestDistance = double.infinity;
        final targetX = (cellLeft + cellRight) / 2;
        final targetY = (cellTop + cellBottom) / 2;

        for (
          var maskY = cellTop;
          maskY <= cellBottom && maskY < maskHeight;
          maskY++
        ) {
          if (maskY < 0) {
            continue;
          }
          final row = bestMask[maskY] as List;
          for (
            var maskX = cellLeft;
            maskX <= cellRight && maskX < maskWidth;
            maskX++
          ) {
            if (maskX < 0) {
              continue;
            }
            final value = (row[maskX] as num).toDouble();
            if (value <= 0) {
              continue;
            }
            final dx = maskX - targetX;
            final dy = maskY - targetY;
            final distance = dx * dx + dy * dy;
            if (distance < bestDistance) {
              bestDistance = distance;
              sampleX = ((maskX + 0.5) / maskWidth) * imageWidth;
              sampleY = ((maskY + 0.5) / maskHeight) * imageHeight;
            }
          }
        }

        if (sampleX != null && sampleY != null) {
          points.add(MaskSamplePoint(xPx: sampleX, yPx: sampleY));
        }
      }
    }

    return points;
  }

  Uint8List _buildMaskOverlay({
    required List bestMask,
    required int minX,
    required int minY,
    required int maxX,
    required int maxY,
    required int imageWidth,
    required int imageHeight,
  }) {
    final overlay = img.Image(
      width: imageWidth,
      height: imageHeight,
      numChannels: 4,
    )..clear(img.ColorRgba8(0, 0, 0, 0));

    final maskHeight = bestMask.length;
    final maskWidth = (bestMask.first as List).length;
    final scaleX = imageWidth / maskWidth;
    final scaleY = imageHeight / maskHeight;

    for (var maskY = 0; maskY < maskHeight; maskY++) {
      final row = bestMask[maskY] as List;
      final startY = (maskY * scaleY).floor();
      final endY = math.min(imageHeight, ((maskY + 1) * scaleY).ceil());
      for (var maskX = 0; maskX < maskWidth; maskX++) {
        final value = (row[maskX] as num).toDouble();
        if (value <= 0) {
          continue;
        }
        final startX = (maskX * scaleX).floor();
        final endX = math.min(imageWidth, ((maskX + 1) * scaleX).ceil());
        for (var y = startY; y < endY; y++) {
          for (var x = startX; x < endX; x++) {
            overlay.setPixelRgba(x, y, 28, 201, 126, 120);
          }
        }
      }
    }

    const borderRed = 255;
    const borderGreen = 145;
    const borderBlue = 77;
    const borderAlpha = 220;
    const borderThickness = 3;
    for (var inset = 0; inset < borderThickness; inset++) {
      final left = math.max(0, minX - inset);
      final top = math.max(0, minY - inset);
      final right = math.min(imageWidth - 1, maxX + inset);
      final bottom = math.min(imageHeight - 1, maxY + inset);

      for (var x = left; x <= right; x++) {
        overlay.setPixelRgba(
          x,
          top,
          borderRed,
          borderGreen,
          borderBlue,
          borderAlpha,
        );
        overlay.setPixelRgba(
          x,
          bottom,
          borderRed,
          borderGreen,
          borderBlue,
          borderAlpha,
        );
      }
      for (var y = top; y <= bottom; y++) {
        overlay.setPixelRgba(
          left,
          y,
          borderRed,
          borderGreen,
          borderBlue,
          borderAlpha,
        );
        overlay.setPixelRgba(
          right,
          y,
          borderRed,
          borderGreen,
          borderBlue,
          borderAlpha,
        );
      }
    }

    return Uint8List.fromList(img.encodePng(overlay));
  }

  List<double> _flattenNums(dynamic value) {
    if (value is List) {
      final result = <double>[];
      for (final item in value) {
        result.addAll(_flattenNums(item));
      }
      return result;
    }
    if (value is num) {
      return <double>[value.toDouble()];
    }
    return const <double>[];
  }

  String _confidenceLabel(double iouScore, double maskAreaRatio) {
    if (maskAreaRatio < 0.01) {
      return 'low';
    }
    if (iouScore >= 0.92) {
      return 'high';
    }
    if (iouScore >= 0.82) {
      return 'medium';
    }
    return 'low';
  }

  _PreparedImage _prepareImage(img.Image source) {
    final originalWidth = source.width;
    final originalHeight = source.height;
    final scale = samInputSize / math.max(originalWidth, originalHeight);
    final resizedWidth = math.max(1, (originalWidth * scale + 0.5).floor());
    final resizedHeight = math.max(1, (originalHeight * scale + 0.5).floor());

    final resized = img.copyResize(
      source,
      width: resizedWidth,
      height: resizedHeight,
      interpolation: img.Interpolation.linear,
    );

    final canvas = img.Image(
      width: samInputSize,
      height: samInputSize,
      numChannels: 3,
    );
    img.compositeImage(canvas, resized, dstX: 0, dstY: 0);

    const pixelMean = <double>[123.675, 116.28, 103.53];
    const pixelStd = <double>[58.395, 57.12, 57.375];
    final tensor = Float32List(3 * samInputSize * samInputSize);
    for (final pixel in canvas) {
      final offset = pixel.y * samInputSize + pixel.x;
      tensor[offset] = (pixel.r.toDouble() - pixelMean[0]) / pixelStd[0];
      tensor[samInputSize * samInputSize + offset] =
          (pixel.g.toDouble() - pixelMean[1]) / pixelStd[1];
      tensor[2 * samInputSize * samInputSize + offset] =
          (pixel.b.toDouble() - pixelMean[2]) / pixelStd[2];
    }

    return _PreparedImage(
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      scale: scale,
      tensor: tensor,
    );
  }
}

class _PreparedImage {
  const _PreparedImage({
    required this.originalWidth,
    required this.originalHeight,
    required this.scale,
    required this.tensor,
  });

  final int originalWidth;
  final int originalHeight;
  final double scale;
  final Float32List tensor;
}

class _PromptTensors {
  const _PromptTensors({required this.pointCoords, required this.pointLabels});

  final OrtValueTensor pointCoords;
  final OrtValueTensor pointLabels;
}
