# Food Volume Estimation Solution with ARCore

## Purpose

This document records the current solution used in SmartDiet AI to estimate food dimensions and volume with ARCore on Android devices without requiring a reference card, ToF sensor, or LiDAR.

The goal is to provide a practical, mobile-friendly workflow that improves portion estimation quality for the nutrition pipeline while remaining usable on commodity smartphones such as the Vivo X100.

## Problem Definition

The app needs a way to estimate:

- width
- length
- height
- approximate volume

for a food item captured by smartphone camera, so that downstream AI nutrition estimation can reason from physical scale instead of image appearance alone.

The main constraints are:

- no reference object method
- target devices may not have ToF or LiDAR
- the workflow must be usable by ordinary users, not only technical users
- the solution must run inside a Flutter mobile app backed by ARCore

## Why Earlier Approaches Were Rejected

### 1. Reference Card / Reference Object

This approach is simple and often accurate, but it was explicitly rejected because it forces the user to place an extra physical object beside the food.

### 2. Manual Width / Length / Height Input

This approach has low engineering risk but poor usability. It depends too much on the user guessing dimensions, which defeats the purpose of AR-assisted measurement.

### 3. Pure Plane-Tap Measurement with Finger Touch

The earlier AR flow asked the user to tap food edges directly on screen. This had several problems:

- finger occludes the target
- tap position is unstable
- user cannot tell what 3D point ARCore actually hit
- interaction does not feel like a measuring tool

### 4. Full 3D Reconstruction / Mesh Pipeline

Academic methods based on multi-view reconstruction, point clouds, or dense mesh generation can be more accurate, but they are too heavy for the current product scope. They require more capture steps, more compute, and more implementation complexity than is reasonable for the current app.

## Research Basis

The current design combines two ideas:

### A. ARCore Hit-Test Measurement

ARCore can return world-space hit results for a screen location. This enables direct physical distance measurement between two locked 3D points.

This is suitable for measuring width and length on a detected table plane.

### B. ARCore Depth API

ARCore Depth API supports depth-from-motion even on devices without dedicated hardware depth sensors. With sufficient user motion and scene texture, ARCore can estimate depth for visible surfaces and improve hit-test quality.

This makes automatic height estimation feasible, with the caveat that it is less stable than plane-based width and length measurement.

## Current Solution Overview

The current solution is a hybrid AR measurement flow:

1. Detect the table plane with ARCore.
2. Use a center reticle instead of direct finger tapping.
3. Lock two plane points for width.
4. Lock two plane points for length.
5. Lock one table reference point near the food.
6. Lock one top point on the food using depth-supported hit testing.
7. Compute height from the vertical difference between the top point and the table point.
8. Allow the user to fine-tune height with a slider.
9. Compute bounding-box volume and pass the dimensions to the nutrition pipeline.

## Interaction Design

### Stage 1: Surface Scanning

The app first asks the user to slowly move the phone so ARCore can detect the tabletop and initialize stable tracking.

This stage exists because measurement quality is poor if the session has not yet built a stable spatial map.

### Stage 2: Reticle-Based Width and Length

Instead of touching arbitrary screen positions, the user uses a center reticle.

The workflow is:

- move phone so the reticle sits on the desired edge
- press a lock button
- repeat for the opposite edge

This improves usability because:

- the target is not covered by the finger
- the sampled point is visually clear
- the interaction feels like a real measurement tool

### Stage 3: Auto Height Measurement

Height is estimated in two steps:

- lock a table point beside the food as the base reference
- lock the topmost visible point of the food using a depth or point hit result

The system computes:

$$
height = |y_{top} - y_{base}| \times 100
$$

where the Y coordinates are in meters and the result is converted to centimeters.

### Stage 4: Height Fine-Tuning

Because food top surfaces can be difficult for monocular depth estimation, the app still allows final slider adjustment.

This is intentional. The AR system provides a better starting estimate, while the slider acts as a correction layer instead of the primary method.

## Dimension and Volume Computation

### Width

Width is computed from the Euclidean distance between two locked world-space points:

$$
width = ||p_{w1} - p_{w2}|| \times 100
$$

### Length

Length is computed the same way:

$$
length = ||p_{l1} - p_{l2}|| \times 100
$$

### Height

Height is based on the vertical difference between the table point and the top point:

$$
height = |y_{top} - y_{base}| \times 100
$$

### Volume

The current system uses a bounding-box approximation with a fill factor:

$$
volume \approx width \times length \times height \times 0.6
$$

This is not a true geometric volume. It is a practical portion-estimation proxy for irregular food shapes.

## Why the Fill Factor Exists

Foods are rarely cuboids. If the app directly uses:

$$
width \times length \times height
$$

the estimated volume is usually too large.

The factor `0.6` acts as a conservative shape correction for common plated foods such as rice, meat portions, vegetables, or mixed dishes. It is not universally correct, but it produces more realistic nutrition estimates than the raw box volume.

## Engineering Changes Required

The implementation required changes in two layers.

### Flutter UI Layer

The AR measurement screen was redesigned to:

- use a reticle workflow
- guide the user through measurement phases
- show current measurement state
- support automatic height measurement with fallback adjustment

### ARCore Plugin Layer

The legacy Flutter AR plugin did not expose enough ARCore functionality. It was extended to support:

- center-screen hit testing on demand
- return of hit trackable type such as plane, depth, or point
- enabling ARCore Depth Mode automatically when supported
- safer lifecycle handling to reduce crashes when leaving AR mode

## Benefits of the Current Solution

### Usability

- simpler than raw screen tapping
- more intuitive than manual dimension entry
- no external reference object needed

### Accuracy

- width and length rely on ARCore world geometry
- height can leverage ARCore depth-from-motion
- final manual correction is still available when depth is weak

### Product Fit

- works inside the current Flutter app
- suitable for mainstream Android phones
- provides explicit physical dimensions to the AI nutrition prompt

## Known Limitations

### 1. Height Is Still the Weakest Dimension

Width and length on a table plane are usually more stable than height.

Height can become noisy when:

- food surface is glossy or reflective
- food has weak texture
- lighting is poor
- the user has not moved enough for depth-from-motion to stabilize

### 2. Bounding-Box Volume Is an Approximation

The current volume is not true 3D reconstruction. It is a shaped box estimate with a correction factor. This is acceptable for portion estimation, but not for scientific volumetry.

### 3. Plugin Maintenance Risk

Some modifications were made in the local pub cache version of the ARCore Flutter plugin. This means:

- future dependency refreshes may overwrite the changes
- the patched plugin should eventually be vendored or replaced

## Recommended User Guidance

For best results, the user should:

- keep the phone roughly 30 to 50 cm above the food
- capture from near top-down view
- wait for table plane detection before measuring
- slightly move the phone before top-point measurement so depth can stabilize
- use the final slider if the auto height looks obviously wrong

## Future Improvements

### Short-Term

- multi-frame averaging for reticle hit results
- warnings for poor angle or poor distance
- confidence indicator for height measurement

### Mid-Term

- better shape priors by food category
- different fill factors for rice, soup, meat, bread, salad, and fruit
- dynamic fallback from auto height to assisted manual mode

### Long-Term

- native Android ARCore implementation instead of relying on an old Flutter plugin
- depth confidence filtering
- object silhouette extraction combined with AR depth
- coarse mesh or surface fitting for more realistic volume estimation

## Practical Position of This Solution

This solution should be seen as a pragmatic middle ground:

- much more usable than manual dimension entry
- much less intrusive than reference-object workflows
- much lighter than full 3D reconstruction
- accurate enough to improve AI nutrition estimation in real product conditions

It is not a scientific-grade volume system, but it is a product-grade AR measurement pipeline designed to balance usability, engineering cost, and estimation quality.
