# Food Volume Estimation Using Smartphone Cameras — State of the Art Research

> Compiled March 2026 for SmartDietAI

---

## Executive Summary

Food volume estimation from smartphone images is an active research area with several viable approaches ranging from simple (reference-object scaling) to complex (AR-based 3D reconstruction). For a **Flutter mobile app** that already does nutrition estimation via image recognition, the most practical path is a **hybrid approach**: monocular depth estimation using Depth Anything V2 (server-side or on-device) combined with a reference-object calibration for metric scale. Below is a comprehensive review.

---

## 1. Monocular Depth Estimation Approaches

### Key Idea
Predict a per-pixel depth map from a **single RGB image** using a deep neural network. The depth map gives relative distances from the camera, which can be used to reconstruct a 3D point cloud and estimate volume.

### Key Papers & Models

#### MiDaS (Ranftl et al., 2019) — arXiv:1907.01341
- **Approach**: Encoder-decoder CNN trained on a mix of 5 diverse depth datasets (including 3D films). Uses a scale-and-shift-invariant loss so incompatible annotations can be combined.
- **Key insight**: Mixing complementary datasets yields robust zero-shot generalization.
- **Accuracy**: State-of-the-art at time of release for zero-shot cross-dataset transfer.
- **Limitation**: Outputs **relative** depth (up to unknown scale and shift) — cannot directly give metric measurements without calibration.
- **GitHub**: https://github.com/isl-org/MiDaS

#### DPT — Dense Prediction Transformer (Ranftl et al., 2021) — arXiv:2103.13413
- **Approach**: Replaces CNN backbone with Vision Transformer (ViT). Assembles tokens from various ViT stages into multi-resolution representations, decoded with a convolutional decoder.
- **Key insight**: Global receptive field at every stage → finer-grained, more globally coherent depth predictions.
- **Accuracy**: Up to 28% improvement in relative performance over fully-convolutional networks on monocular depth.
- **GitHub**: https://github.com/intel-isl/DPT

#### Depth Anything V2 (Yang et al., 2024) — arXiv:2406.09414 — ⭐ RECOMMENDED
- **Approach**: DINOv2-based ViT backbone + DPT decoder. Three innovations: (1) synthetic training data instead of noisy real labels, (2) scaled-up teacher model (DINOv2-G), (3) student-teacher distillation on 62M real unlabeled images.
- **Models available**: Small (24.8M params), Base (97.5M), Large (335.3M), Giant (1.3B).
- **Accuracy**: 97.1% accuracy in relative depth ordering on DA-2K benchmark. Outperforms MiDaS, DPT, Marigold, and GeoWizard on KITTI and NYUv2.
- **Speed**: 10x+ faster than Stable Diffusion-based depth models.
- **Mobile deployment**:
  - ✅ **Apple Core ML**: Official models from Apple — 18ms inference on iPhone 12 Pro Max (Neural Engine)
  - ✅ **Android ONNX**: Community demo app (Depth-Anything-Android) using ONNX Runtime, supports V1 and V2, input sizes 256 and 512
  - ✅ **TensorRT**, **Transformers.js** (WebGPU real-time in browser)
- **Metric depth**: Fine-tuned variants available that output metric (absolute) depth in meters
- **License**: Small = Apache-2.0 ✅; Base/Large/Giant = CC-BY-NC-4.0
- **GitHub**: https://github.com/DepthAnything/Depth-Anything-V2

#### High Quality Monocular Depth via Transfer Learning (Alhashim & Wonka, 2018) — arXiv:1812.11941
- **Approach**: Standard encoder-decoder with pretrained encoder (DenseNet-169). Simple decoder with upsampling and concatenation.
- **Key insight**: Even a very simple decoder + good pretrained encoder produces high-quality, detailed depth maps.

### Converting Relative Depth → Metric Volume
Monocular depth models typically output **relative** depth (ordinal relationships preserved, but scale unknown). To get actual volume in cm³/mL:

1. **Reference object calibration**: Place a known-size object (coin, credit card) → solve for scale factor
2. **Camera intrinsics**: Use focal length (from EXIF) + known pixel size → convert to real-world units. Formula:
   - $Z_{real} = \frac{f \times S_{real}}{S_{pixel}}$ where $f$ is focal length, $S_{real}$ is real size, $S_{pixel}$ is pixel size
3. **Metric depth models**: Use Depth Anything V2 fine-tuned variants that directly output depth in meters

### Practical Assessment for Flutter App
| Aspect | Rating |
|--------|--------|
| Accuracy | ⭐⭐⭐ Good for relative shape; ±10-20% volume error expected |
| Input required | Single image ✅ |
| Mobile feasibility | ✅ Depth Anything V2 Small runs on-device via ONNX/CoreML |
| Main limitation | Needs calibration for metric scale |

---

## 2. ARCore / ARKit Based Approaches

### Key Idea
Use the AR framework's depth-from-motion algorithm and/or hardware ToF sensors to generate depth maps with **metric scale**, then reconstruct a 3D mesh of the food and compute volume.

### ARCore Depth API (Google)
- **How it works**: Depth-from-motion algorithm takes multiple frames as user moves the device. Compares images from different angles to estimate per-pixel distance. Uses ML to enhance depth even with minimal motion. Automatically fuses hardware depth sensor (ToF) data if available.
- **Range**: 0–65 meters; most accurate 0.5–5m
- **Resolution**: Depth images match camera frame timestamp and field-of-view
- **Requirements**: User must move device slightly; surfaces need texture (white walls = poor depth)
- **Device support**: Supported on many Android devices; ToF sensors on select flagships

### ARKit Depth API (Apple)
- **LiDAR Scanner**: iPhone 12 Pro and later, iPad Pro — provides direct metric depth
- **TrueDepth Camera**: iPhone X and later — structured light for close-range depth
- **ARKit Scene Reconstruction**: Creates a 3D mesh of the environment in real-time

### SNAQ App Study (Herzig et al., 2020) — JMIR mHealth
**The most relevant real-world validation study found:**
- **System**: iPhone X with built-in TrueDepth sensor (structured light) + custom computer vision pipeline
- **Pipeline**: Capture → CNN-based food segmentation → depth map → Delaunay triangulation → point cloud → RANSAC plane fitting (table) → per-food-item volume → density-based weight → macronutrient lookup
- **Tested on**: 48 meals, 128 food items (breakfast, cooked meals, snacks)
- **Results**:
  - Weight estimation: **14.0% mean absolute error**
  - Energy estimation: **12.7% mean absolute error** (41.2 kcal)
  - Carbohydrate: 14.8%, Protein: 13.0%, Fat: 12.3%
  - Processing time: **22.9 seconds** average
  - Segmentation success: 94.5% automatic (7/128 needed manual adjustment)
- **Key findings**: Viewing angle (45° vs 90°) had no effect on accuracy. Cooked meals harder than snacks/breakfast due to overlapping items.
- **Limitation**: Single phone model (iPhone X), no automated food recognition

### Practical Assessment for Flutter App
| Aspect | Rating |
|--------|--------|
| Accuracy | ⭐⭐⭐⭐ Best accuracy with LiDAR/ToF (~12-14% error) |
| Input required | AR session (user must move phone) or LiDAR scan |
| Mobile feasibility | ⚠️ Challenging — limited Flutter AR support; platform-specific |
| Main limitation | No mature Flutter AR plugin; requires platform channels |

### Flutter AR Integration Options
- **arcore_flutter_plugin**: Community package, limited maintenance, does NOT expose Depth API
- **ar_flutter_plugin**: Wraps ARCore + ARKit, but no depth API access
- **Platform channels**: Write native Kotlin/Swift code to access depth APIs, call from Flutter — **most viable but high effort**
- **Unity as a Library**: Embed Unity AR scene in Flutter — complex but powerful

---

## 3. Reference Object Methods

### Key Idea
Place a known-size object (coin, credit card, checkerboard) in the frame alongside the food. Detect the reference object, compute pixels-per-cm, then estimate food dimensions and volume.

### Key Papers

#### Food Portion Estimation via 3D Object Scaling (Vinod et al., CVPR 2024 Workshop)
- **Approach**: Uses a reference object to establish metric scale, then estimates portion size by scaling a 3D model of the food item.
- **Key insight**: Combining food recognition with 3D template matching and reference-based scaling achieves practical portion estimation.
- **Cited 23 times** as of 2026.

#### Model-Based Food Volume Estimation Using 3D/2D Registration (Chen et al., 2013)
- **Approach**: Uses fiducial markers (checkerboard) to calibrate camera, then fits 3D geometric models (cylinders, boxes, etc.) to segmented food regions.
- **Mean absolute volume error**: ~7.2%
- **Limitation**: Needs checkerboard visible in frame — poor usability

#### Mobile Structured Light System for Food 3D Reconstruction (Makhsous et al., 2019)
- **Approach**: Adds structured light projector to smartphone for depth sensing + video sequences
- **Mean absolute volume error**: ~5.8%
- **Limitation**: Requires custom hardware attachment

### Common Reference Objects Used in Literature
| Object | Diameter/Size | Pros | Cons |
|--------|---------------|------|------|
| US Quarter | 24.26mm | Common, circular, easy to detect | Small, US-only |
| Credit card | 85.6 × 53.98mm | Universal ISO standard | Must be flat, visible |
| Thumb/finger | ~20mm width | Always available | High variance, unreliable |
| Plate (known diameter) | ~26cm | Already in scene | Must know plate size |
| Custom printed card | configurable | App-specific, QR code + scale | User must print/carry |

### Practical Assessment for Flutter App
| Aspect | Rating |
|--------|--------|
| Accuracy | ⭐⭐⭐ Good (~7-15% error with good reference) |
| Input required | Single image + reference object in frame ✅ |
| Mobile feasibility | ✅ Excellent — pure image processing |
| Main limitation | User must place reference object — friction |

---

## 4. Deep Learning Direct Volume/Calorie Estimation

### Key Idea
Train end-to-end models that directly predict food volume, weight, or calories from images — skipping explicit 3D reconstruction.

### Key Papers

#### "Im2Calories" (Google, 2015)
- **Note**: The original Im2Calories paper by Meyers et al. was a Google internal presentation/research demo, not a formal arxiv paper. The concept: use a CNN to predict depth from a single food image, then estimate volume and calories. It generated significant media attention but was never publicly released.
- **Approach**: Multi-task CNN predicting (1) food segmentation, (2) per-pixel depth, (3) food labels → combine for calorie estimation
- **Significance**: Showed the concept is viable; inspired many follow-up works

#### DepthCalorieCam (Ando et al., MADiMa 2019)
- **Approach**: Mobile app using RGB-D cameras (Tango/ToF) for volume-based food calorie estimation
- **Method**: Food segmentation → depth map → voxel-based volume computation → calorie database lookup
- **Platform**: Android with depth-capable hardware

#### Single Image-Based Food Volume Estimation Using Monocular Depth Networks (Graikos et al., 2020)
- **Approach**: Uses pretrained monocular depth networks (like MiDaS) to predict depth from a single food image, then computes volume using 3D reconstruction
- **Key insight**: Off-the-shelf monocular depth models, when combined with proper calibration, can estimate food volume from a single photo
- **Cited 26 times**

#### Learning Metric Volume Estimation from Short Monocular Video (Steinbrener et al., Heliyon 2023)
- **Approach**: Uses short smartphone video sequences (not single image) to estimate volume of fruits/vegetables. Leverages multi-view geometry from video frames for more accurate depth.
- **Key insight**: Short video (a few seconds orbiting around the food) significantly improves accuracy over single-image methods.

#### Food Classification and Meal Intake Amount Estimation Through Deep Learning (Kim et al., Applied Sciences 2023)
- **Approach**: Capture plate before and after eating with smartphone. Use camera intrinsics (pose, focus) to generate 3D food shape. Deep learning for food classification + geometric volume computation.

#### Gonzalez et al. (Sensors 2025/2026) — YOLO + SAM + Depth Anything V2 Pipeline
**The most recent and directly relevant paper:**
- **Full pipeline**: YOLOv8 detection → SAM segmentation → Depth Anything V2 depth estimation → base plane correction → volume integration
- **Pipeline detail**:
  1. YOLO detects tray/plate bounding box
  2. SAM generates pixel-level masks per food item
  3. Depth Anything V2 (ViT-L) estimates depth map
  4. Base plane correction via least-squares fit on plate rim
  5. Volume = Σ (corrected_depth × pixel_area) over mask
  6. Weight = Volume × food-type density factor
- **Results**: Weight estimation errors of **5.07% (rice)** and **3.75% (chicken)**
- **Runtime**: ~13.7s per frame (SAM dominates at 91% of compute)
- **Key finding**: Monocular depth (Depth Anything V2) **outperformed stereo cameras** at practical distances (>1.5m), and is far cheaper
- **Limitation**: Volumes in arbitrary units without metric calibration; needs per-food-type density mapping

### Practical Assessment for Flutter App
| Aspect | Rating |
|--------|--------|
| Accuracy | ⭐⭐⭐⭐ 3-15% error depending on method |
| Input required | Single image or short video |
| Mobile feasibility | ⚠️ Heavy models — best as server-side pipeline |
| Main limitation | Training data scarcity; food-type-specific density required |

---

## 5. Open-Source Implementations & Libraries

### Depth Estimation Models
| Resource | Platform | License | Notes |
|----------|----------|---------|-------|
| [Depth-Anything-V2](https://github.com/DepthAnything/Depth-Anything-V2) | Python/PyTorch | Apache-2.0 (Small) | SOTA monocular depth, 7.8k ⭐ |
| [Depth-Anything-Android](https://github.com/shubham0204/Depth-Anything-Android) | Android/Kotlin | Apache-2.0 | ONNX-based on-device inference |
| [Apple CoreML Depth Anything V2](https://huggingface.co/apple/coreml-depth-anything-v2-small) | iOS/CoreML | Apache-2.0 | 18ms on iPhone 12 Pro |
| [Depth-Anything-ONNX](https://github.com/fabio-sim/Depth-Anything-ONNX) | Cross-platform | — | ONNX export pipeline |
| [Transformers.js WebGPU Depth](https://huggingface.co/spaces/Xenova/webgpu-realtime-depth-estimation) | Browser/WebGPU | — | Real-time in-browser demo |
| [MiDaS](https://github.com/isl-org/MiDaS) | Python/PyTorch | MIT | Classic robust depth model |
| [DPT](https://github.com/intel-isl/DPT) | Python/PyTorch | MIT | ViT-based dense prediction |

### Food Segmentation
| Resource | Use |
|----------|-----|
| [Segment Anything (SAM)](https://github.com/facebookresearch/segment-anything) | Zero-shot food segmentation |
| [FoodSAM](https://arxiv.org/abs/2308.05938) | SAM fine-tuned for food |
| [YOLOv8](https://docs.ultralytics.com/) | Food detection + bounding boxes |

### Flutter/Mobile Integration
| Resource | Use |
|----------|-----|
| [tflite_flutter](https://pub.dev/packages/tflite_flutter) | Run TFLite models in Flutter |
| [onnxruntime_flutter](https://pub.dev/packages/onnxruntime) | ONNX Runtime for Flutter (experimental) |
| [google_mlkit](https://pub.dev/packages/google_mlkit_commons) | ML Kit integration (segmentation, etc.) |
| Platform channels | Native Kotlin/Swift depth API access |

---

## 6. Recommended Implementation Strategy for SmartDietAI

### Approach: Tiered System (Simple → Advanced)

#### Tier 1 — Reference Object + 2D Estimation (Easiest, Fastest to Ship)
1. User takes a photo of food with a **credit card** or **known plate** in frame
2. Detect reference object → compute pixels-per-cm scale
3. Segment food items (existing pipeline or YOLO/SAM via backend)
4. Estimate food area in cm² from segmentation mask
5. Apply **food-type-specific thickness heuristics** (e.g., rice = 2cm avg height, salad = 5cm)
6. Volume ≈ area × estimated_height
7. Weight = volume × density → calories via your existing nutrition DB

**Expected accuracy**: ±20-30%  
**Effort**: Low  
**Input**: Single photo + reference object

#### Tier 2 — Monocular Depth + Reference Object (Best Balance)
1. User takes a single photo (reference object optional but recommended)
2. Send to **backend** running Depth Anything V2 (Small or Base)
3. Generate relative depth map
4. Segment food items (YOLO + SAM or your existing segmentation)
5. Apply base plane correction (fit plane to plate rim)
6. Integrate depth over food mask → relative volume
7. Calibrate to metric using:
   - Reference object scale, OR
   - Camera focal length from EXIF + known plate diameter assumption
8. Weight = metric_volume × density → nutrition lookup

**Expected accuracy**: ±10-15%  
**Effort**: Medium  
**Input**: Single photo (best with reference object)

#### Tier 3 — On-Device Depth + AR Enhancement (Most Accurate)
1. Depth Anything V2 Small via ONNX Runtime on-device (~18ms on iPhone)
2. Optional: Use ARCore/ARKit depth for devices with ToF/LiDAR (via platform channels)
3. Real-time depth overlay as user frames the food
4. Tap-to-measure: user taps plate rim for automatic scale calibration
5. Full 3D volume computation

**Expected accuracy**: ±5-14%  
**Effort**: High  
**Input**: Image or short AR session

### Backend Pipeline Architecture (Tier 2)

```
[Flutter App] 
    → capture photo + EXIF metadata
    → POST /api/volume-estimate
    
[Backend (Python/FastAPI)]
    → YOLOv8: detect plate, food items
    → SAM: pixel-level segmentation masks
    → Depth Anything V2 (ViT-S or ViT-B): depth map
    → Base plane correction (plate rim regression)
    → Per-food volume integration
    → Reference object / EXIF calibration → metric volume
    → Volume × density DB → weight → nutrition DB lookup
    → Return: {food_items: [{name, volume_ml, weight_g, calories, macros}]}
```

### Key Technical Decisions

| Decision | Recommendation | Reason |
|----------|---------------|--------|
| Depth model | Depth Anything V2 Small | Best accuracy/speed tradeoff, Apache-2.0, mobile-ready |
| Segmentation | SAM or SAM2 | Zero-shot, no food-specific training needed |
| Detection | YOLOv8 | Fast, accurate food detection |
| Scale calibration | Credit card detection + EXIF focal length | No special hardware needed |
| Processing location | Server-side (Tier 2) | Keeps app lightweight; can upgrade models easily |
| Food density DB | Build custom from USDA/your CFS data | Map food_id → density (g/mL) |

### What You Need to Build

1. **Density database**: Map each food in your CFS nutrition DB to a density value (g/cm³). Sources: USDA, published food density tables.
2. **Reference object detector**: Train or use template matching for credit card / coin detection.
3. **Depth estimation endpoint**: Add Depth Anything V2 to your FastAPI backend.
4. **Volume computation module**: Depth map → segmentation mask → plane correction → numerical integration.
5. **Flutter UI**: Camera overlay guide (show where to place reference object), results display.

---

## 7. Key References

| Paper | Year | Key Contribution |
|-------|------|-----------------|
| MiDaS (Ranftl et al.) | 2019 | Robust zero-shot monocular depth from mixed datasets |
| DPT (Ranftl et al.) | 2021 | Vision Transformer backbone for dense depth prediction |
| Depth Anything V2 (Yang et al.) | 2024 | SOTA monocular depth, mobile-ready, metric variants |
| SNAQ / Herzig et al. | 2020 | iPhone depth sensor food volumetry, 12-14% macro error |
| Graikos et al. | 2020 | Single-image food volume via monocular depth networks |
| Gonzalez et al. | 2025 | YOLO + SAM + Depth Anything V2 full pipeline, 3-5% error |
| Vinod et al. (CVPR-W) | 2024 | Food portion estimation via 3D object scaling |
| Tahir & Loo (Healthcare) | 2021 | Comprehensive survey of food volume methods (124 citations) |
| Lo et al. (IEEE JBHI) | 2020 | Review of image-based food classification + volume (179 citations) |
| Konstantakopoulos et al. (IEEE Reviews) | 2023 | Review of AI food recognition + volume systems (96 citations) |

---

## 8. Bottom Line

**For SmartDietAI specifically:**

Your app already does food image recognition → nutrition estimation via RAG. Adding volume estimation would make calorie estimates much more accurate (portion size accounts for ~50% of dietary estimation error per the literature).

**Start with Tier 2** (Depth Anything V2 on your existing Python backend + reference object calibration). This gives you:
- ±10-15% volume accuracy from a single photo
- No special hardware required
- Runs on your existing FastAPI backend
- Works across all phones (Android + iOS)
- Can be improved incrementally (add on-device depth, AR features later)

The key bottleneck is the **food density database** — you need to map each food item in your CFS nutrition database to a density value (g/mL) to convert volume → weight → calories. This is a data problem more than an engineering one.
