"""
Health Router - Backend health check endpoint.
"""

from fastapi import APIRouter
from datetime import datetime, timezone

router = APIRouter()


@router.get("")
async def health_check():
    """
    Health check endpoint.
    Returns backend status, version, and current timestamp.
    """
    return {
        "status": "healthy",
        "service": "InkVision AI Backend",
        "version": "1.0.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
