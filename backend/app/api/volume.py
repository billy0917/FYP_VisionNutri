"""Volume estimation API endpoint.

Accepts a base64-encoded food image and returns estimated volume,
dimensions, and confidence using Depth Anything V2.
"""

import base64
import io

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field
from PIL import Image

from app.services.depth_service import DepthService

router = APIRouter(tags=["volume"])


class VolumeRequest(BaseModel):
    image_base64: str = Field(..., description="Base64-encoded JPEG image")
    focal_length_35mm: float = Field(
        default=23.0,
        description="35mm-equivalent focal length (Vivo X100 main = 23mm)",
    )


@router.post("/volume/estimate")
def estimate_volume(request: VolumeRequest):
    """Estimate food volume from a single image using Depth Anything V2."""
    try:
        image_bytes = base64.b64decode(request.image_base64)
        image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid image: {e}")

    service = DepthService.get_instance()

    # Try to read focal length from EXIF; fall back to the request value
    exif_focal = service.extract_exif_focal(image_bytes)
    focal = exif_focal or request.focal_length_35mm

    result = service.estimate_volume(image, focal_length_35mm=focal)
    result["focal_length_35mm_used"] = focal
    return result
