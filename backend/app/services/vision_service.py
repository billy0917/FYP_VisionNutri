"""
SmartDiet AI - Vision Service
Handles food image analysis using OpenRouter API with multimodal models.
"""

import base64
import json
from typing import Optional

from openai import AsyncOpenAI
from pydantic import BaseModel

from ..core.config import settings


class FoodAnalysisResult(BaseModel):
    """Schema for food analysis results from AI vision model."""
    food_name: str
    calories: int
    protein: int  # in grams
    carbs: int    # in grams
    fat: int      # in grams
    reasoning: str
    confidence_score: Optional[float] = None


class VisionService:
    """Service for analyzing food images using OpenRouter multimodal models."""
    
    def __init__(self):
        self.client = AsyncOpenAI(
            base_url=settings.openrouter_base_url,
            api_key=settings.openrouter_api_key,
        )
        self.model = settings.openrouter_default_model
    
    async def analyze_food(
        self,
        image_url: Optional[str] = None,
        image_base64: Optional[str] = None,
        model: Optional[str] = None,
        additional_context: Optional[str] = None,
    ) -> FoodAnalysisResult:
        """
        Analyze a food image and estimate its macronutrients.
        
        Args:
            image_url: URL of the food image to analyze (optional).
            image_base64: Base64 encoded image data (optional).
            model: Optional model override (e.g., "google/gemini-pro-vision").
            additional_context: Optional context about the food or portion size.
        
        Returns:
            FoodAnalysisResult containing estimated nutritional information.
        """
        
        if not image_url and not image_base64:
            raise ValueError("Either image_url or image_base64 must be provided")
        
        system_prompt = """You are an expert nutritionist and food analyst AI. 
Your task is to analyze food images and provide accurate nutritional estimates.

When analyzing food images:
1. Identify all food items visible in the image
2. Estimate portion sizes based on visual cues
3. Calculate macronutrients based on typical nutritional data
4. Consider cooking methods that may affect calorie content

Always respond with a JSON object in the following format:
{
    "food_name": "A clear, concise name for the food item(s)",
    "calories": estimated total calories (integer),
    "protein": estimated protein in grams (integer),
    "carbs": estimated carbohydrates in grams (integer),
    "fat": estimated fat in grams (integer),
    "reasoning": "Brief explanation of your analysis and estimation methodology"
}

Be conservative with estimates when uncertain. If multiple items are visible, 
provide aggregate totals for the entire meal."""

        # Prepare image content
        if image_base64:
            # Convert base64 to data URL format
            image_content = f"data:image/jpeg;base64,{image_base64}"
        else:
            image_content = image_url

        user_content = [
            {
                "type": "text",
                "text": "Please analyze this food image and estimate its nutritional content."
            },
            {
                "type": "image_url",
                "image_url": {"url": image_content}
            }
        ]
        
        if additional_context:
            user_content[0]["text"] += f"\n\nAdditional context: {additional_context}"
        
        try:
            response = await self.client.chat.completions.create(
                model=model or self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_content}
                ],
                max_tokens=1000,
                temperature=0.3,
            )
            
            # Parse the response
            content = response.choices[0].message.content
            
            # Extract JSON from response (handle potential markdown formatting)
            json_str = content
            if "```json" in content:
                json_str = content.split("```json")[1].split("```")[0].strip()
            elif "```" in content:
                json_str = content.split("```")[1].split("```")[0].strip()
            
            result_dict = json.loads(json_str)
            
            return FoodAnalysisResult(
                food_name=result_dict.get("food_name", "Unknown food"),
                calories=int(result_dict.get("calories", 0)),
                protein=int(result_dict.get("protein", 0)),
                carbs=int(result_dict.get("carbs", 0)),
                fat=int(result_dict.get("fat", 0)),
                reasoning=result_dict.get("reasoning", ""),
                confidence_score=result_dict.get("confidence_score"),
            )
            
        except json.JSONDecodeError as e:
            # Return a default result if JSON parsing fails
            return FoodAnalysisResult(
                food_name="Analysis failed",
                calories=0,
                protein=0,
                carbs=0,
                fat=0,
                reasoning=f"Failed to parse AI response: {str(e)}",
                confidence_score=0.0,
            )
        except Exception as e:
            raise Exception(f"Error analyzing food image: {str(e)}")


# Convenience function for standalone usage
async def analyze_food_via_openrouter(
    image_url: str,
    model: Optional[str] = None,
) -> FoodAnalysisResult:
    """
    Analyze a food image using OpenRouter API.
    
    Args:
        image_url: URL of the food image to analyze.
        model: Optional model override.
    
    Returns:
        FoodAnalysisResult with nutritional estimates.
    """
    service = VisionService()
    return await service.analyze_food(image_url, model)
