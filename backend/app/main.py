"""
InkVision AI - FastAPI Backend Entry Point
Main application configuration with CORS, routers, and startup events.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
import os

from app.core.config import settings
from app.database.session import create_db_tables
from app.routers import health_router, tattoo_router, tryon_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Handle startup and shutdown events."""
    # Create upload directories on startup
    os.makedirs(f"{settings.UPLOAD_DIR}/tattoos", exist_ok=True)
    os.makedirs(f"{settings.UPLOAD_DIR}/results", exist_ok=True)
    # Create database tables
    await create_db_tables()
    yield
    # Cleanup on shutdown (if needed)


app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="InkVision AI - Virtual Tattoo Try-On Backend API",
    docs_url="/docs",
    redoc_url="/redoc",
    lifespan=lifespan,
)

# --------------------------------------------------------------------------- #
# CORS Middleware - Allow Flutter frontend to communicate with backend         #
# --------------------------------------------------------------------------- #
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --------------------------------------------------------------------------- #
# Static file serving - serve uploaded images                                  #
# --------------------------------------------------------------------------- #
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

# --------------------------------------------------------------------------- #
# Include Routers                                                              #
# --------------------------------------------------------------------------- #
app.include_router(health_router.router, prefix="/health", tags=["Health"])
app.include_router(tattoo_router.router, prefix="/tattoos", tags=["Tattoos"])
app.include_router(tryon_router.router, prefix="/tryon", tags=["TryOn"])


@app.get("/", tags=["Root"])
async def root():
    """API root endpoint."""
    return {
        "message": "Welcome to InkVision AI API",
        "version": settings.APP_VERSION,
        "docs": "/docs",
    }
