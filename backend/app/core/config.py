"""
Application configuration using Pydantic Settings.
All values are loaded from environment variables or .env file.
"""

from pydantic_settings import BaseSettings
from pydantic import field_validator
from typing import List
import os


class Settings(BaseSettings):
    # App Info
    APP_NAME: str = "InkVision AI Backend"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False

    # CORS
    ALLOWED_ORIGINS: List[str] = [
        "http://localhost:3000",
        "http://localhost:8080",
        "http://10.0.2.2:8000",  # Android emulator -> host
        "*",  # Allow all for prototype; restrict in production
    ]

    @field_validator("ALLOWED_ORIGINS", mode="before")
    @classmethod
    def parse_origins(cls, v):
        if isinstance(v, str):
            # Try JSON first, then fallback to comma-separated
            import json
            try:
                return json.loads(v)
            except Exception:
                return [origin.strip() for origin in v.split(",")]
        return v

    # Database — supports both PostgreSQL (Render) and SQLite (local)
    DATABASE_URL: str = (
        "sqlite+aiosqlite:///./inkvision.db"
    )
    SYNC_DATABASE_URL: str = (
        "sqlite:///./inkvision.db"
    )

    @field_validator("DATABASE_URL", mode="before")
    @classmethod
    def fix_postgres_url(cls, v):
        """Render gives postgres:// but asyncpg needs postgresql+asyncpg://"""
        if isinstance(v, str):
            if v.startswith("postgres://"):
                v = v.replace("postgres://", "postgresql+asyncpg://", 1)
            elif v.startswith("postgresql://") and "+asyncpg" not in v:
                v = v.replace("postgresql://", "postgresql+asyncpg://", 1)
        return v

    # File Storage
    UPLOAD_DIR: str = "uploads"
    MAX_FILE_SIZE_MB: int = 10
    ALLOWED_EXTENSIONS: List[str] = ["png", "jpg", "jpeg", "webp"]

    @field_validator("ALLOWED_EXTENSIONS", mode="before")
    @classmethod
    def parse_extensions(cls, v):
        if isinstance(v, str):
            import json
            try:
                return json.loads(v)
            except Exception:
                return [ext.strip() for ext in v.split(",")]
        return v

    # Security
    SECRET_KEY: str = "change-me-in-production-use-a-long-random-string"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    class Config:
        env_file = ".env"
        case_sensitive = True


settings = Settings()
