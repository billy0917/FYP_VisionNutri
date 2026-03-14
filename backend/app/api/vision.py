"""
SmartDiet AI - Vision API Router
Exposes food image analysis endpoints.
"""

import base64
from typing import Optional

from fastapi import APIRouter, HTTPException, UploadFile, File
from pydantic import BaseModel

from ..services.vision_service import VisionService, FoodAnalysisResult

router = APIRouter(prefix="/api/v1/vision", tags=["vision"])

_vision_service = VisionService()


class AnalyzeFoodRequest(BaseModel):
    image_base64: Optional[str] = None
    image_url: Optional[str] = None
    additional_context: Optional[str] = None


@router.post("/analyze", response_model=FoodAnalysisResult)
async def analyze_food(request: AnalyzeFoodRequest):
    """
    Analyze a food image and return nutritional estimates.
    Accepts either a base64-encoded image or an image URL.
    """
    if not request.image_base64 and not request.image_url:
        raise HTTPException(
            status_code=422,
            detail="Either image_base64 or image_url must be provided",
        )

    try:
        result = await _vision_service.analyze_food(
            image_url=request.image_url,
            image_base64=request.image_base64,
            additional_context=request.additional_context,
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/upload-and-analyze", response_model=FoodAnalysisResult)
async def upload_and_analyze_food(
    file: UploadFile = File(...),
    additional_context: Optional[str] = None,
):
    """
    Upload a food image file and return nutritional estimates.
    """
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=422, detail="File must be an image")

    try:
        contents = await file.read()
        image_base64 = base64.b64encode(contents).decode("utf-8")

        result = await _vision_service.analyze_food(
            image_base64=image_base64,
            additional_context=additional_context,
        )
        return result
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
