"""Food volume estimation using Depth Anything V2 monocular depth.

Pipeline
--------
1. Depth Anything V2 (Small, 25 M params) produces a per-pixel disparity map.
2. Border pixels define the table / surface plane.
3. Centre pixels above the surface plane are treated as food.
4. (height above surface) × (pixel real-world area) → volume in mL.

Assumptions
-----------
* Camera-to-food distance ≈ 40 cm (typical phone food photo).
* Scene depth range ≈ 25 cm.
* Larger predicted_depth values = closer to camera (disparity convention).
"""

import io
import math
import logging
from typing import Optional

import numpy as np
from PIL import Image, ExifTags

logger = logging.getLogger(__name__)

# --- Tuneable constants ---------------------------------------------------
_DEFAULT_DISTANCE_CM = 40.0   # assumed camera-to-table distance
_SCENE_DEPTH_RANGE_CM = 25.0  # approximate visible depth span
_MIN_FOOD_PIXELS = 50         # ignore if fewer food pixels found
_FOOD_THRESHOLD_RATIO = 0.03  # depth contrast above surface to count as food
_MAX_FOOD_HEIGHT_CM = 15.0    # clamp unrealistic heights


class DepthService:
    """Singleton wrapping Depth Anything V2 for food volume estimation."""

    _instance: Optional["DepthService"] = None
    _pipe = None

    def __init__(self):
        self._load_model()

    @classmethod
    def get_instance(cls) -> "DepthService":
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    # ------------------------------------------------------------------
    # Model management
    # ------------------------------------------------------------------
    def _load_model(self):
        if DepthService._pipe is not None:
            return
        from transformers import pipeline as hf_pipeline

        logger.info("Loading Depth-Anything-V2-Small-hf …")
        DepthService._pipe = hf_pipeline(
            "depth-estimation",
            model="depth-anything/Depth-Anything-V2-Small-hf",
            device="cpu",
        )
        logger.info("Depth model loaded.")

    # ------------------------------------------------------------------
    # EXIF helpers
    # ------------------------------------------------------------------
    @staticmethod
    def extract_exif_focal(raw_bytes: bytes) -> Optional[float]:
        """Return the 35mm-equivalent focal length from EXIF, or None."""
        try:
            img = Image.open(io.BytesIO(raw_bytes))
            exif = img._getexif()
            if exif:
                for tag_id, val in exif.items():
                    tag = ExifTags.TAGS.get(tag_id)
                    if tag == "FocalLengthIn35mmFilm" and val:
                        return float(val)
        except Exception:
            pass
        return None

    # ------------------------------------------------------------------
    # Core volume estimation
    # ------------------------------------------------------------------
    def estimate_volume(
        self,
        image: Image.Image,
        focal_length_35mm: float = 23.0,
    ) -> dict:
        """Return estimated volume and dimensions for food in *image*."""

        # --- 1. Run depth model -------------------------------------------
        result = self._pipe(image)
        depth_raw = result["predicted_depth"]
        depth: np.ndarray = np.array(depth_raw.squeeze(), dtype=np.float64)
        h, w = depth.shape

        d_min, d_max = float(depth.min()), float(depth.max())
        d_range = d_max - d_min
        if d_range < 1e-6:
            return self._empty_result()

        # Normalise: 0 = farthest, 1 = closest  (disparity convention)
        depth_n = (depth - d_min) / d_range

        # --- 2. Detect surface plane from border pixels -------------------
        bh = max(h // 8, 4)
        bw = max(w // 8, 4)
        border = np.concatenate([
            depth_n[:bh, :].ravel(),
            depth_n[-bh:, :].ravel(),
            depth_n[:, :bw].ravel(),
            depth_n[:, -bw:].ravel(),
        ])
        surface_level = float(np.median(border))

        # --- 3. Segment food in centre crop --------------------------------
        y1, y2 = h // 6, 5 * h // 6
        x1, x2 = w // 6, 5 * w // 6
        centre = depth_n[y1:y2, x1:x2]

        threshold = surface_level + _FOOD_THRESHOLD_RATIO
        food_mask = centre > threshold
        n_food = int(food_mask.sum())

        if n_food < _MIN_FOOD_PIXELS:
            return self._empty_result()

        # --- 4. Heights above surface -------------------------------------
        heights_norm = centre[food_mask] - surface_level
        heights_norm = np.clip(heights_norm, 0, None)

        # --- 5. Real-world scale ------------------------------------------
        fov_h = 2 * math.atan(36.0 / (2.0 * focal_length_35mm))
        scene_w_cm = 2 * _DEFAULT_DISTANCE_CM * math.tan(fov_h / 2.0)
        cm_per_px = scene_w_cm / w

        heights_cm = heights_norm * _SCENE_DEPTH_RANGE_CM
        heights_cm = np.clip(heights_cm, 0, _MAX_FOOD_HEIGHT_CM)

        pixel_area_cm2 = cm_per_px ** 2
        volume_cm3 = float((heights_cm * pixel_area_cm2).sum())
        food_area_cm2 = float(n_food * pixel_area_cm2)
        avg_h = float(heights_cm.mean()) if n_food else 0.0
        max_h = float(heights_cm.max()) if n_food else 0.0

        # Bounding-box dimensions
        ys, xs = np.where(food_mask)
        bbox_h_cm = float((ys.max() - ys.min()) * cm_per_px) if len(ys) else 0.0
        bbox_w_cm = float((xs.max() - xs.min()) * cm_per_px) if len(xs) else 0.0

        # Confidence heuristic
        contrast = float(centre[food_mask].mean() - surface_level)
        if contrast > 0.15 and n_food > 5000:
            conf = "high"
        elif contrast > 0.06 and n_food > 500:
            conf = "medium"
        else:
            conf = "low"

        return {
            "volume_ml": round(volume_cm3, 1),
            "food_area_cm2": round(food_area_cm2, 1),
            "avg_height_cm": round(avg_h, 1),
            "max_height_cm": round(max_h, 1),
            "bbox_width_cm": round(bbox_w_cm, 1),
            "bbox_length_cm": round(bbox_h_cm, 1),
            "food_pixel_ratio": round(n_food / centre.size, 3),
            "depth_contrast": round(contrast, 3),
            "confidence": conf,
            "assumed_distance_cm": _DEFAULT_DISTANCE_CM,
            "scene_width_cm": round(scene_w_cm, 1),
        }

    # ------------------------------------------------------------------
    @staticmethod
    def _empty_result() -> dict:
        return {
            "volume_ml": 0,
            "food_area_cm2": 0,
            "avg_height_cm": 0,
            "max_height_cm": 0,
            "bbox_width_cm": 0,
            "bbox_length_cm": 0,
            "food_pixel_ratio": 0,
            "depth_contrast": 0,
            "confidence": "none",
            "assumed_distance_cm": _DEFAULT_DISTANCE_CM,
            "scene_width_cm": 0,
        }
