"""
SmartDiet AI - RAG Service
Handles knowledge base queries via FastGPT API.
"""

from typing import Optional

import httpx
from pydantic import BaseModel

from ..core.config import settings


class FastGPTResponse(BaseModel):
    """Schema for FastGPT API response."""
    answer: str
    conversation_id: Optional[str] = None
    sources: Optional[list] = None


class RAGService:
    """Service for interacting with FastGPT knowledge base chatbot."""
    
    def __init__(self):
        self.api_url = settings.fastgpt_api_url
        self.api_key = settings.fastgpt_api_key
    
    async def query(
        self,
        user_query: str,
        conversation_id: Optional[str] = None,
        user_context: Optional[dict] = None,
    ) -> FastGPTResponse:
        """
        Send a query to FastGPT knowledge base.
        
        Args:
            user_query: The user's question or message.
            conversation_id: Optional conversation ID for context continuity.
            user_context: Optional user context (e.g., dietary goals, restrictions).
        
        Returns:
            FastGPTResponse containing the AI's answer.
        """
        
        # Build system context with user information if provided
        system_message = "You are a helpful AI nutritionist assistant."
        if user_context:
            context_parts = []
            if user_context.get("goal_type"):
                context_parts.append(f"User's goal: {user_context['goal_type']}")
            if user_context.get("target_calories"):
                context_parts.append(f"Daily calorie target: {user_context['target_calories']} kcal")
            if user_context.get("target_protein"):
                context_parts.append(f"Daily protein target: {user_context['target_protein']}g")
            if user_context.get("dietary_restrictions"):
                context_parts.append(f"Dietary restrictions: {', '.join(user_context['dietary_restrictions'])}")
            
            if context_parts:
                system_message += f"\n\nUser context:\n" + "\n".join(context_parts)
        
        # Prepare request payload (FastGPT OpenAI-compatible format)
        payload = {
            "model": "fastgpt",  # FastGPT model identifier
            "messages": [
                {"role": "system", "content": system_message},
                {"role": "user", "content": user_query}
            ],
            "stream": False,
        }
        
        # Add conversation ID if continuing a conversation
        if conversation_id:
            payload["chatId"] = conversation_id
        
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
        }
        
        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    self.api_url,
                    json=payload,
                    headers=headers,
                )
                response.raise_for_status()
                
                data = response.json()
                
                # Parse FastGPT response format
                answer = ""
                if "choices" in data and len(data["choices"]) > 0:
                    answer = data["choices"][0].get("message", {}).get("content", "")
                
                return FastGPTResponse(
                    answer=answer,
                    conversation_id=data.get("chatId"),
                    sources=data.get("sources"),
                )
                
        except httpx.HTTPStatusError as e:
            raise Exception(f"FastGPT API error: {e.response.status_code} - {e.response.text}")
        except httpx.RequestError as e:
            raise Exception(f"FastGPT request failed: {str(e)}")


# Convenience function for standalone usage
async def query_fastgpt(
    user_query: str,
    conversation_id: Optional[str] = None,
    user_context: Optional[dict] = None,
) -> FastGPTResponse:
    """
    Query the FastGPT knowledge base.
    
    Args:
        user_query: The user's question.
        conversation_id: Optional conversation ID for context.
        user_context: Optional user context dictionary.
    
    Returns:
        FastGPTResponse with the AI's answer.
    """
    service = RAGService()
    return await service.query(user_query, conversation_id, user_context)
