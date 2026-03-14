"""
SmartDiet AI - Configuration Module
Handles environment variables and application settings.
"""

from functools import lru_cache
from typing import Optional

from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Application
    app_name: str = "SmartDiet AI"
    app_version: str = "0.1.0"
    debug: bool = False
    
    # API Keys (Optional for now)
    openrouter_api_key: str = ""
    fastgpt_api_key: str = ""
    fastgpt_api_url: str = "https://api.fastgpt.in/api/v1/chat/completions"
    
    # Vision AI Settings
    openrouter_base_url: str = "https://api.apiplus.org/v1"
    openrouter_default_model: str = "gemini-3.1-flash-lite-preview"
    
    # Supabase
    supabase_url: str
    supabase_key: str  # anon/public key for client-side
    supabase_service_role_key: Optional[str] = None  # For server-side operations
    
    # Storage
    supabase_storage_bucket: str = "food-images"
    
    # CORS
    cors_origins: list[str] = ["*"]
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


@lru_cache()
def get_settings() -> Settings:
    """
    Get cached settings instance.
    Uses lru_cache to ensure settings are loaded only once.
    """
    return Settings()


# Export settings instance for convenience
settings = get_settings()
