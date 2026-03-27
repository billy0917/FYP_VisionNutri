# Food Volume and Size Estimation - Current State

## Purpose

This document records the solution that is implemented in the app at the current moment for estimating food or object size and approximate volume.

It is a current-state engineering note, not a research proposal. If implementation and older documents disagree, this file should be treated as the source of truth for the present system behavior.

## Goal

The goal is to provide approximate:

- width
- length
- height
- bounding-box volume

for a captured object, then pass that information into the existing cameraInfo -> RAG -> final LLM nutrition analysis flow without breaking the current AI architecture.

## Current High-Level Strategy

The current solution is a hybrid of:

1. on-device MobileSAM segmentation
2. ARCore plane and depth hit testing
3. robust bounding-box estimation from sampled 3D points

The key design choice is:

- MobileSAM is used to guide which image regions likely belong to the object
- ARCore is still the source of physical scale
- the final dimensions are derived from 3D points, not from 2D image pixels alone

This means segmentation improves point selection, but does not directly produce centimeters.

## Current User Flow

### A. Camera Screen

On the normal camera screen:

1. The user captures or selects an image.
2. The app runs on-device MobileSAM on that still image.
3. The app shows a visual mask overlay so the user can inspect whether the object segmentation looks reasonable.
4. The user can optionally open the AR measurement screen.
5. The user can still manually trigger AI analysis after capture.

### B. AR Measurement Screen

On the AR measurement screen:

1. The user scans the table plane.
2. The user starts automatic scanning.
3. During scanning, the app periodically samples the scene.
4. The app tries to use a MobileSAM-guided sampling path first.
5. If that does not produce enough usable depth or point hits, the app falls back to the older center-grid sampling path.
6. The app estimates width, length, height, and approximate box volume.
7. The dimensions are returned to the normal analysis flow.

## Current Technical Pipeline

### 1. Still-Image MobileSAM Inference

Implemented in:

- [lib/core/services/volume_service.dart](lib/core/services/volume_service.dart)

The service currently:

- loads `mobilesam_encoder.onnx`
- loads `mobilesam_decoder.onnx`
- runs on-device inference with ONNX Runtime
- produces:
  - bbox metadata
  - coverage ratio
  - confidence label
  - overlay PNG bytes for visualization
  - foreground mask sample points for AR-guided sampling

The segmentation result is used in two ways:

1. for user-visible overlay on the camera screen
2. as an additional prompt context for the downstream AI pipeline

### 2. AR Scene Sampling

Implemented in:

- [lib/features/camera/screens/ar_measure_screen.dart](lib/features/camera/screens/ar_measure_screen.dart)

During AR scanning, each batch currently attempts this sequence:

1. capture the current AR scene as image bytes
2. run MobileSAM on that screenshot
3. extract mask-guided sample points
4. ask ARCore to hit-test only those screen points
5. keep only `depth` or `point` trackable hits
6. reject obvious outliers by height above the support plane

If the mask-guided route yields too few usable points, the app falls back to a fixed center-region grid sampling pass.

### 3. ARCore Plugin Extensions

The local patched pub-cache version of `arcore_flutter_plugin` currently exposes custom functionality used by the app:

- `takeScreenshotBytes()`
- `sampleHitTestPoints(...)`
- improved hit-selection priority for `depth_preferred`

The current priority order is effectively:

- `depth`
- `point`
- `plane`

This helps avoid the case where plane hits dominate and no real object depth points survive.

## Current Geometry Estimation

After the app gathers candidate 3D points, it currently estimates object dimensions using a plane-aligned bounding box.

Implemented in:

- [lib/features/camera/screens/ar_measure_screen.dart](lib/features/camera/screens/ar_measure_screen.dart)

Current method:

1. choose the detected support plane as the reference plane
2. use the plane's local X axis as one horizontal measurement axis
3. use the plane's local Z axis as the other horizontal measurement axis
4. project sampled 3D points onto those axes
5. compute robust spans for width and length
6. estimate height using a robust percentile of point heights above the plane

In simplified form:

$$
width \approx span(points \cdot axis_X)
$$

$$
length \approx span(points \cdot axis_Z)
$$

$$
height \approx P_{90}(distance\_to\_plane)
$$

$$
volume \approx width \times length \times height
$$

This is currently a plane-aligned bounding box, not an oriented bounding box.

## Why the Current Approach Exists

The current architecture tries to solve the right problem in the right order:

1. segmentation tells the system where the object probably is
2. ARCore gives the system physical geometry and depth cues
3. the final AI stage receives explicit size context as text, instead of guessing from appearance alone

This is a practical compromise between:

- usability
- engineering complexity
- mobile performance
- compatibility with the existing AI pipeline

## What Is Working Right Now

At the current moment, the implemented system can do all of the following:

- run MobileSAM fully on-device inside the phone
- show a visual mask overlay on captured images
- keep the existing manual analysis flow intact
- attempt mask-guided AR sampling during automatic measurement
- fall back to grid sampling if mask-guided AR sampling is weak
- pass estimated dimensions into the existing downstream prompt flow

## Known Current Limitations

### 1. Transparent or Reflective Objects Are Still Difficult

Objects such as plastic bottles, glass, glossy packaging, and reflective surfaces often produce weak ARCore depth results.

In those cases, even correct segmentation may not produce enough reliable 3D points.

### 2. Final Box Geometry Is Still Plane-Aligned

Even if the sampled points mostly belong to the right object, the final width and length are still measured along the table plane axes.

This can overestimate size when the object is:

- rotated relative to the table axes
- diagonally placed
- long and thin
- asymmetrical

### 3. Plugin Changes Live in Local Pub Cache

The ARCore plugin modifications are currently local environment patches.

That means:

- clearing pub cache may remove them
- other machines will not automatically inherit them
- the patch should eventually be vendored or formalized

### 4. The Current Volume Is Approximate

The current `width * length * height` result is a bounding-box style approximation.

It is useful as a practical scale cue for food analysis, but it is not a true geometric volume reconstruction.

## Current Failure Modes

The system may still fail or degrade when:

- the table plane is not stable
- lighting is poor
- the object is highly transparent or reflective
- the object occupies too little image area
- ARCore returns mostly plane hits and too few object depth hits
- the object is too close to the edge of the scan area

## Why PCA / Oriented Bounding Box Is the Next Step

The next most important improvement is to replace the current plane-aligned width and length calculation with a PCA-based oriented bounding box.

The reason is simple:

- current segmentation-guided sampling improves which 3D points are collected
- but the final size calculation still assumes the object should be measured along the table axes

That is often wrong for rotated or elongated objects.

PCA / oriented bounding box would instead:

1. project the sampled object points onto the support plane
2. find the dominant object direction from the point cloud itself
3. measure width and length along the object's own principal axes

This should reduce width and length inflation for bottles, sandwiches, elongated plates, diagonally placed food, and other non-axis-aligned objects.

## Recommended Immediate Next Steps

### 1. Upgrade Geometry Estimation to PCA / Oriented Bounding Box

This is the most important next step because it improves the final box estimate after the sampling stage has already been improved.

### 2. Add AR Debug Overlay for Sampled Points

This would make it obvious whether a scan failed because:

- MobileSAM selected poor regions
- ARCore returned too few usable depth points
- the geometry fit itself is unstable

### 3. Add Confidence Gating

The system should eventually avoid reporting dimensions when:

- usable point count is too low
- point cloud spread is inconsistent
- estimated geometry is implausible

## Summary

The current system is not a pure image-based estimator and not a full 3D reconstruction pipeline.

It is a hybrid method:

- use MobileSAM to find likely object regions
- use ARCore to obtain scale-bearing 3D hits
- estimate a robust box from sampled object points
- send the resulting dimensions into the existing AI nutrition reasoning flow

At the current moment, this is the active solution in the app.

The biggest remaining weakness is not segmentation anymore. It is the final geometry fitting step, which is why PCA / oriented bounding box is the most logical next upgrade.