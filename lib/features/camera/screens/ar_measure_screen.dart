library;

import 'dart:async';
import 'dart:math' as math;

import 'package:arcore_flutter_plugin/arcore_flutter_plugin.dart';
import 'package:flutter/material.dart';
import 'package:smart_diet_ai/core/services/volume_service.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

class FoodMeasurement {
  final double? widthCm;
  final double? lengthCm;
  final double? heightCm;
  final double? volumeMl;

  FoodMeasurement({this.widthCm, this.lengthCm, this.heightCm, this.volumeMl});

  String toPromptContext() {
    return 'ARCore-measured bounding-box dimensions: '
        'width ${widthCm?.toStringAsFixed(1)} cm, '
        'length ${lengthCm?.toStringAsFixed(1)} cm, '
        'height ${heightCm?.toStringAsFixed(1)} cm, '
        'bbox volume ~${volumeMl?.round()} mL.';
  }
}

typedef ArMeasurement = FoodMeasurement;

enum _Phase { scanSurface, autoScan, review }

class ArMeasureScreen extends StatefulWidget {
  const ArMeasureScreen({super.key});

  @override
  State<ArMeasureScreen> createState() => _ArMeasureScreenState();
}

class _ArMeasureScreenState extends State<ArMeasureScreen> {
  ArCoreController? _arCtrl;
  Timer? _scanTicker;

  _Phase _phase = _Phase.scanSurface;
  bool _planeReady = false;
  bool _closing = false;
  bool _isSampling = false;

  ArCorePlane? _supportPlane;
  String? _statusText;
  double _scanProgress = 0;
  int _sampleBatches = 0;
  final List<vm.Vector3> _objectPoints = <vm.Vector3>[];

  double _widthCm = 0;
  double _lengthCm = 0;
  double _heightCm = 0;
  double _volumeMl = 0;

  @override
  void dispose() {
    _scanTicker?.cancel();
    _disposeController();
    super.dispose();
  }

  void _onArCoreViewCreated(ArCoreController ctrl) {
    _arCtrl = ctrl;
    ctrl.onPlaneDetected = (plane) {
      if (_closing || !mounted) {
        return;
      }
      if (plane.type == ArCorePlaneType.HORIZONTAL_UPWARD_FACING) {
        final currentArea =
            (_supportPlane?.extendX ?? 0) * (_supportPlane?.extendZ ?? 0);
        final nextArea = (plane.extendX ?? 0) * (plane.extendZ ?? 0);
        if (_supportPlane == null || nextArea >= currentArea) {
          _supportPlane = plane;
        }
        if (!_planeReady) {
          setState(() {
            _planeReady = true;
            _statusText = '桌面已偵測，準備開始自動掃描';
          });
        }
      }
    };
  }

  Future<void> _restart() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _phase = _planeReady ? _Phase.review : _Phase.scanSurface;
      _statusText = _planeReady ? '已清除結果，可重新開始掃描' : '等待桌面偵測';
      _scanProgress = 0;
      _sampleBatches = 0;
      _objectPoints.clear();
      _widthCm = 0;
      _lengthCm = 0;
      _heightCm = 0;
      _volumeMl = 0;
    });
  }

  Future<void> _beginAutoScan() async {
    if (!_planeReady || _supportPlane == null || _phase == _Phase.autoScan) {
      return;
    }
    setState(() {
      _phase = _Phase.autoScan;
      _statusText = '請保持食物在中央框內，慢慢移動手機';
      _scanProgress = 0;
      _sampleBatches = 0;
      _objectPoints.clear();
    });

    const totalBatches = 8;
    _scanTicker?.cancel();
    _scanTicker = Timer.periodic(const Duration(milliseconds: 320), (
      timer,
    ) async {
      if (!mounted || _closing) {
        timer.cancel();
        return;
      }
      await _collectSampleBatch();
      if (!mounted || _closing) {
        timer.cancel();
        return;
      }

      final nextBatch = _sampleBatches + 1;
      setState(() {
        _sampleBatches = nextBatch;
        _scanProgress = nextBatch / totalBatches;
      });

      if (nextBatch >= totalBatches) {
        timer.cancel();
        _finishAutoScan();
      }
    });
  }

  void _disposeController() {
    if (_closing) {
      return;
    }
    _closing = true;
    final ctrl = _arCtrl;
    _arCtrl = null;
    try {
      ctrl?.dispose();
    } catch (_) {}
  }

  void _closeScreen([FoodMeasurement? result]) {
    _scanTicker?.cancel();
    _disposeController();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(result);
  }

  void _confirm() {
    _closeScreen(
      FoodMeasurement(
        widthCm: _widthCm,
        lengthCm: _lengthCm,
        heightCm: _heightCm,
        volumeMl: _volumeMl,
      ),
    );
  }

  String get _title => switch (_phase) {
    _Phase.scanSurface => '先掃描桌面',
    _Phase.autoScan => '自動估算尺寸中',
    _Phase.review => '檢查量測結果',
  };

  String get _subtitle => switch (_phase) {
    _Phase.scanSurface => '慢慢移動手機，等桌面網格穩定後再開始。',
    _Phase.autoScan => '中心框內會自動取樣深度點，估算食物的長寬高與 bbox 體積。',
    _Phase.review => '這些尺寸會原樣送進後面的 RAG + 大模型流程。',
  };

  int get _currentStep => switch (_phase) {
    _Phase.scanSurface => 0,
    _Phase.autoScan => 1,
    _Phase.review => 2,
  };

  Future<void> _collectSampleBatch() async {
    if (_arCtrl == null || _supportPlane == null || _isSampling || !mounted) {
      return;
    }

    final size = MediaQuery.sizeOf(context);
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    _isSampling = true;
    try {
      final roi = _scanRect(size);
      var hits = await _sampleMaskGuidedHits(size);
      var usedFallbackGrid = false;
      if (_countUsableHits(hits) < 8) {
        usedFallbackGrid = true;
        hits = await _arCtrl!.sampleHitTestGrid(
          left: roi.left,
          top: roi.top,
          width: roi.width,
          height: roi.height,
          rows: 5,
          cols: 7,
          mode: 'depth_preferred',
        );
      }

      if (!mounted || _supportPlane == null) {
        return;
      }

      final planeOrigin = vm.Vector3.copy(
        _supportPlane!.centerPose!.translation,
      );
      final planeRotation = _supportPlane!.centerPose!.rotation;
      final planeNormal = _rotateByQuaternion(
        vm.Vector3(0, 1, 0),
        planeRotation,
      )..normalize();

      final candidates = <vm.Vector3>[];
      for (final hit in hits ?? const <ArCoreHitTestResult>[]) {
        if (hit.trackableType != 'depth' && hit.trackableType != 'point') {
          continue;
        }
        final point = vm.Vector3.copy(hit.pose.translation);
        final heightCm = _signedDistanceToPlaneCm(
          point,
          planeOrigin,
          planeNormal,
        );
        if (heightCm < 0.8 || heightCm > 18) {
          continue;
        }
        candidates.add(point);
      }

      if (candidates.isNotEmpty) {
        setState(() {
          _objectPoints.addAll(candidates);
          _statusText = usedFallbackGrid
              ? '遮罩取樣不足，已改用網格補點；目前共 ${_objectPoints.length} 個深度點'
              : '已收集 ${_objectPoints.length} 個物體深度點';
        });
      } else if (usedFallbackGrid && mounted) {
        setState(() {
          _statusText = '遮罩取樣與網格補點都不足，請更靠近並避開反光';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _statusText = '取樣失敗，請維持食物在中央並再試一次';
        });
      }
    } finally {
      _isSampling = false;
    }
  }

  Future<List<ArCoreHitTestResult>?> _sampleMaskGuidedHits(Size size) async {
    final controller = _arCtrl;
    if (controller == null) {
      return null;
    }

    try {
      final screenshotBytes = await controller.takeScreenshotBytes();
      if (screenshotBytes == null || screenshotBytes.isEmpty) {
        return null;
      }

      final segmentation = await VolumeService().estimateVolume(
        imageBytes: screenshotBytes,
      );
      if (!segmentation.hasMaskSamplePoints) {
        return null;
      }

      final roi = _scanRect(size);
      final roiPoints = segmentation.maskSamplePoints
          .where((point) => roi.contains(Offset(point.xPx, point.yPx)))
          .map((point) => point.toMap())
          .toList();
      final samplePoints =
          (roiPoints.length >= 8
                  ? roiPoints
                  : segmentation.maskSamplePoints
                        .map((point) => point.toMap())
                        .toList())
              .take(48)
              .toList();
      if (samplePoints.length < 8) {
        return null;
      }

      if (mounted) {
        setState(() {
          _statusText = '使用 MobileSAM 前景遮罩取樣 ${samplePoints.length} 個點';
        });
      }

      final hits = await controller.sampleHitTestPoints(
        points: samplePoints,
        mode: 'depth_preferred',
      );
      return _countUsableHits(hits) >= 8 ? hits : null;
    } catch (_) {
      return null;
    }
  }

  int _countUsableHits(List<ArCoreHitTestResult>? hits) {
    if (hits == null || hits.isEmpty) {
      return 0;
    }
    return hits
        .where(
          (hit) => hit.trackableType == 'depth' || hit.trackableType == 'point',
        )
        .length;
  }

  void _finishAutoScan() {
    final plane = _supportPlane;
    if (plane == null || plane.centerPose == null) {
      setState(() {
        _phase = _Phase.review;
        _statusText = '找不到穩定桌面，請回到上一層重試';
      });
      return;
    }

    final measurement = _estimateBoundingBox(plane, _objectPoints);
    if (measurement == null) {
      setState(() {
        _phase = _Phase.review;
        _statusText = '深度點不足，請讓食物待在中央框內並重新掃描';
      });
      return;
    }

    setState(() {
      _phase = _Phase.review;
      _widthCm = measurement.widthCm;
      _lengthCm = measurement.lengthCm;
      _heightCm = measurement.heightCm;
      _volumeMl = measurement.volumeMl;
      _statusText = '已完成自動估算，可直接送去後續 AI 分析';
    });
  }

  _MeasurementEstimate? _estimateBoundingBox(
    ArCorePlane plane,
    List<vm.Vector3> points,
  ) {
    if (plane.centerPose == null || points.length < 8) {
      return null;
    }

    final planeOrigin = vm.Vector3.copy(plane.centerPose!.translation);
    final rotation = plane.centerPose!.rotation;
    final axisX = _rotateByQuaternion(vm.Vector3(1, 0, 0), rotation)
      ..normalize();
    final axisZ = _rotateByQuaternion(vm.Vector3(0, 0, 1), rotation)
      ..normalize();
    final normal = _rotateByQuaternion(vm.Vector3(0, 1, 0), rotation)
      ..normalize();

    final uValues = <double>[];
    final vValues = <double>[];
    final hValues = <double>[];

    for (final point in points) {
      final relative = point - planeOrigin;
      final heightCm = relative.dot(normal) * 100;
      if (heightCm < 0.8 || heightCm > 18) {
        continue;
      }
      uValues.add(relative.dot(axisX) * 100);
      vValues.add(relative.dot(axisZ) * 100);
      hValues.add(heightCm);
    }

    if (uValues.length < 8 || vValues.length < 8 || hValues.length < 8) {
      return null;
    }

    final widthSpan = _robustSpan(uValues);
    final lengthSpan = _robustSpan(vValues);
    final heightSpan = _robustPercentile(hValues, 0.9);
    if (widthSpan <= 0.5 || lengthSpan <= 0.5 || heightSpan <= 0.2) {
      return null;
    }

    final width = math.min(widthSpan, lengthSpan);
    final length = math.max(widthSpan, lengthSpan);
    final height = heightSpan;
    return _MeasurementEstimate(
      widthCm: width,
      lengthCm: length,
      heightCm: height,
      volumeMl: width * length * height,
    );
  }

  Rect _scanRect(Size size) {
    final width = size.width * 0.54;
    final height = size.height * 0.34;
    final left = (size.width - width) / 2;
    final top = size.height * 0.32;
    return Rect.fromLTWH(left, top, width, height);
  }

  double _robustSpan(List<double> values) {
    final sorted = [...values]..sort();
    final lower = _robustPercentile(sorted, 0.12);
    final upper = _robustPercentile(sorted, 0.88);
    return (upper - lower).abs();
  }

  double _robustPercentile(List<double> values, double percentile) {
    final sorted = List<double>.from(values)..sort();
    if (sorted.isEmpty) {
      return 0;
    }
    final position = (sorted.length - 1) * percentile.clamp(0, 1);
    final lowerIndex = position.floor();
    final upperIndex = position.ceil();
    if (lowerIndex == upperIndex) {
      return sorted[lowerIndex];
    }
    final fraction = position - lowerIndex;
    return sorted[lowerIndex] * (1 - fraction) + sorted[upperIndex] * fraction;
  }

  double _signedDistanceToPlaneCm(
    vm.Vector3 point,
    vm.Vector3 planeOrigin,
    vm.Vector3 planeNormal,
  ) {
    final relative = point - planeOrigin;
    return relative.dot(planeNormal) * 100;
  }

  vm.Vector3 _rotateByQuaternion(vm.Vector3 vector, vm.Vector4 rotation) {
    final q = vm.Vector3(rotation.x, rotation.y, rotation.z);
    final uv = q.cross(vector);
    final uuv = q.cross(uv);
    uv.scale(2.0 * rotation.w);
    uuv.scale(2.0);
    return vector + uv + uuv;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _closeScreen();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            ArCoreView(
              onArCoreViewCreated: _onArCoreViewCreated,
              enableTapRecognizer: false,
              enablePlaneRenderer: true,
              enableUpdateListener: true,
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [
                      _TopBanner(
                        title: _title,
                        subtitle: _subtitle,
                        planeReady: _planeReady,
                      ),
                      if (_phase != _Phase.scanSurface)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: _StepStrip(currentStep: _currentStep),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: IconButton(
                  onPressed: _closeScreen,
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
            if (_phase != _Phase.scanSurface)
              Center(
                child: _ScanGuide(rect: _scanRect(MediaQuery.sizeOf(context))),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: _phase == _Phase.scanSurface
                    ? _buildScanPanel()
                    : _buildMeasurePanel(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanPanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(210),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '這次會改成自動 bbox 掃描',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const _HintLine(text: '1. 手機放在食物正上方約 25-45 cm。'),
          const _HintLine(text: '2. 看到桌面網格後再開始。'),
          const _HintLine(text: '3. 食物放在中央框內，開始後慢慢移動手機約 2 秒。'),
          const _HintLine(text: '4. 系統會自動估算長寬高與 bbox volume。'),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _planeReady ? _beginAutoScan : null,
              icon: Icon(
                _planeReady ? Icons.play_arrow : Icons.hourglass_bottom,
              ),
              label: Text(_planeReady ? '開始自動掃描' : '正在等待桌面偵測'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurePanel() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(210),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: '寬度',
                  value: _widthCm > 0
                      ? '${_widthCm.toStringAsFixed(1)} cm'
                      : '--',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  label: '長度',
                  value: _lengthCm > 0
                      ? '${_lengthCm.toStringAsFixed(1)} cm'
                      : '--',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCard(
                  label: '高度',
                  value: _heightCm > 0
                      ? '${_heightCm.toStringAsFixed(1)} cm'
                      : '--',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _statusText ?? '請把主要食物保持在中央框內',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          if (_phase == _Phase.autoScan) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _scanProgress,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.greenAccent,
              ),
            ),
          ],
          if (_phase == _Phase.review && _volumeMl > 0) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(35),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'bbox 尺寸：約 ${_widthCm.toStringAsFixed(1)} × ${_lengthCm.toStringAsFixed(1)} × ${_heightCm.toStringAsFixed(1)} cm\n'
                'bbox volume：約 ${_volumeMl.round()} mL',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _restart,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重來'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _phase == _Phase.autoScan
                      ? null
                      : (_volumeMl > 0
                            ? _confirm
                            : (_planeReady ? _beginAutoScan : null)),
                  icon: Icon(
                    _phase == _Phase.autoScan
                        ? Icons.hourglass_bottom
                        : (_volumeMl > 0 ? Icons.check : Icons.play_arrow),
                  ),
                  label: Text(
                    _phase == _Phase.autoScan
                        ? '掃描中...'
                        : (_volumeMl > 0 ? '完成量測' : '重新掃描'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MeasurementEstimate {
  const _MeasurementEstimate({
    required this.widthCm,
    required this.lengthCm,
    required this.heightCm,
    required this.volumeMl,
  });

  final double widthCm;
  final double lengthCm;
  final double heightCm;
  final double volumeMl;
}

class _TopBanner extends StatelessWidget {
  const _TopBanner({
    required this.title,
    required this.subtitle,
    required this.planeReady,
  });

  final String title;
  final String subtitle;
  final bool planeReady;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(210),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: planeReady
                      ? Colors.green.withAlpha(60)
                      : Colors.orange.withAlpha(60),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  planeReady ? '桌面已偵測' : '掃描中',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepStrip extends StatelessWidget {
  const _StepStrip({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    const labels = ['掃描桌面', '自動取樣', '檢查結果'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index == currentStep;
        final done = index < currentStep;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == labels.length - 1 ? 0 : 4),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: done
                  ? Colors.green.withAlpha(180)
                  : active
                  ? Colors.white.withAlpha(220)
                  : Colors.black.withAlpha(130),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              labels[index],
              textAlign: TextAlign.center,
              style: TextStyle(
                color: active ? Colors.black87 : Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanGuide extends StatelessWidget {
  const _ScanGuide({required this.rect});

  final Rect rect;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          children: [
            Positioned.fromRect(
              rect: rect,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withAlpha(220),
                    width: 2,
                  ),
                  color: Colors.white.withAlpha(12),
                ),
              ),
            ),
            Positioned(
              left: rect.center.dx - 12,
              top: rect.center.dy - 12,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.greenAccent.withAlpha(220),
                    width: 2,
                  ),
                  color: Colors.greenAccent.withAlpha(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintLine extends StatelessWidget {
  const _HintLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 3),
            child: Icon(Icons.circle, size: 7, color: Colors.white70),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
