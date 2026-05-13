"""
File utility functions for safe file handling, name sanitization,
and validation of uploaded images.
"""

import os
import re
import uuid
import aiofiles
from pathlib import Path
from typing import Tuple
from fastapi import UploadFile, HTTPException, status
from app.core.config import settings


def sanitize_filename(filename: str) -> str:
    """
    Sanitize a filename to prevent path traversal and injection attacks.
    Replaces unsafe characters with underscores.
    """
    # Remove path components
    filename = os.path.basename(filename)
    # Replace unsafe characters
    filename = re.sub(r"[^\w\-_\.]", "_", filename)
    # Remove leading dots (hidden files)
    filename = filename.lstrip(".")
    # Limit length
    name, ext = os.path.splitext(filename)
    return f"{name[:100]}{ext}"


def generate_unique_filename(original_filename: str) -> str:
    """Generate a unique filename using UUID to prevent collisions."""
    _, ext = os.path.splitext(sanitize_filename(original_filename))
    return f"{uuid.uuid4().hex}{ext.lower()}"


def validate_file_extension(filename: str) -> str:
    """
    Validate that the file has an allowed extension.
    Returns the extension if valid, raises HTTPException if not.
    """
    _, ext = os.path.splitext(filename)
    ext = ext.lstrip(".").lower()
    if ext not in settings.ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"File type '.{ext}' is not allowed. "
                   f"Allowed types: {', '.join(settings.ALLOWED_EXTENSIONS)}",
        )
    return ext


async def validate_and_save_upload(
    file: UploadFile, sub_directory: str
) -> Tuple[str, str, int]:
    """
    Validate an uploaded file and save it to the specified subdirectory.

    Args:
        file: The uploaded file from FastAPI
        sub_directory: Subdirectory under UPLOAD_DIR (e.g., 'tattoos', 'results')

    Returns:
        Tuple of (file_path, image_url, file_size)
    """
    if not file.filename:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No filename provided",
        )

    # Validate extension
    validate_file_extension(file.filename)

    # Read content to check size
    content = await file.read()
    file_size = len(content)

    max_size = settings.MAX_FILE_SIZE_MB * 1024 * 1024
    if file_size > max_size:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File size exceeds maximum allowed size of {settings.MAX_FILE_SIZE_MB}MB",
        )

    # Generate safe unique filename
    unique_filename = generate_unique_filename(file.filename)
    save_dir = Path(settings.UPLOAD_DIR) / sub_directory
    save_dir.mkdir(parents=True, exist_ok=True)
    file_path = save_dir / unique_filename

    # Write file asynchronously
    async with aiofiles.open(file_path, "wb") as f:
        await f.write(content)

    # Build the URL path for serving (relative to static mount)
    image_url = f"/uploads/{sub_directory}/{unique_filename}"

    return str(file_path), image_url, file_size


def decode_base64_image(base64_str: str) -> bytes:
    """Decode a base64 encoded image string to bytes."""
    import base64
    # Strip data URL prefix if present (e.g., "data:image/png;base64,...")
    if "," in base64_str:
        base64_str = base64_str.split(",", 1)[1]
    return base64.b64decode(base64_str)


async def save_base64_image(base64_str: str, sub_directory: str) -> Tuple[str, str]:
    """
    Decode a base64 image and save it to disk.

    Returns:
        Tuple of (file_path, image_url)
    """
    content = decode_base64_image(base64_str)
    unique_filename = f"{uuid.uuid4().hex}.png"
    save_dir = Path(settings.UPLOAD_DIR) / sub_directory
    save_dir.mkdir(parents=True, exist_ok=True)
    file_path = save_dir / unique_filename

    async with aiofiles.open(file_path, "wb") as f:
        await f.write(content)

    image_url = f"/uploads/{sub_directory}/{unique_filename}"
    return str(file_path), image_url
