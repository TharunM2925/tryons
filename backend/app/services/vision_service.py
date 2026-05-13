"""
Vision Service - OpenCV-based skin detection and image processing.

This service implements HSV-based skin color segmentation as a prototype.
The class is designed to be easily replaced with a more sophisticated
ML model (MediaPipe, DeepLab, etc.) in the future.
"""

import cv2
import numpy as np
from typing import Optional, Tuple, Dict, Any
import logging

logger = logging.getLogger(__name__)


class VisionService:
    """
    Computer vision service for skin detection using OpenCV.

    Prototype implementation uses HSV color space thresholding.
    Future versions can swap this with MediaPipe Selfie Segmentation
    or a custom deep learning model without changing the interface.
    """

    # HSV skin color range (tuned for broad skin tone coverage)
    # Lower bound: hue ~0-25, saturation ~30-170, value ~60-255
    SKIN_LOWER_1 = np.array([0, 30, 60], dtype=np.uint8)
    SKIN_UPPER_1 = np.array([25, 170, 255], dtype=np.uint8)

    # Second range to catch reddish skin tones (hue wraps around 180)
    SKIN_LOWER_2 = np.array([160, 30, 60], dtype=np.uint8)
    SKIN_UPPER_2 = np.array([180, 170, 255], dtype=np.uint8)

    # Minimum skin area threshold (percentage of frame)
    MIN_SKIN_PERCENTAGE = 2.0

    # Minimum contour area to consider as valid skin region
    MIN_CONTOUR_AREA = 2000

    def __init__(self):
        """Initialize the vision service."""
        logger.info("VisionService initialized with HSV skin detection")

    def decode_image(self, image_bytes: bytes) -> Optional[np.ndarray]:
        """Decode image bytes to OpenCV BGR array."""
        try:
            np_arr = np.frombuffer(image_bytes, np.uint8)
            img = cv2.imdecode(np_arr, cv2.IMREAD_COLOR)
            return img
        except Exception as e:
            logger.error(f"Failed to decode image: {e}")
            return None

    def create_skin_mask(self, hsv_image: np.ndarray) -> np.ndarray:
        """
        Create a binary mask of skin regions using HSV thresholding.

        Args:
            hsv_image: Image in HSV color space

        Returns:
            Binary mask where white pixels represent skin
        """
        # Create masks for both HSV ranges
        mask1 = cv2.inRange(hsv_image, self.SKIN_LOWER_1, self.SKIN_UPPER_1)
        mask2 = cv2.inRange(hsv_image, self.SKIN_LOWER_2, self.SKIN_UPPER_2)
        mask = cv2.bitwise_or(mask1, mask2)

        # Morphological operations to clean the mask
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (7, 7))
        # Remove small noise
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel, iterations=2)
        # Fill small holes
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel, iterations=2)
        # Slight dilation to smooth edges
        mask = cv2.dilate(mask, kernel, iterations=1)

        return mask

    def find_largest_skin_contour(
        self, mask: np.ndarray
    ) -> Optional[Tuple[np.ndarray, float]]:
        """
        Find the largest contour in the skin mask.

        Returns:
            Tuple of (contour, area) or None if no valid contour found
        """
        contours, _ = cv2.findContours(
            mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
        )
        if not contours:
            return None

        # Find largest contour
        largest_contour = max(contours, key=cv2.contourArea)
        area = cv2.contourArea(largest_contour)

        if area < self.MIN_CONTOUR_AREA:
            return None

        return largest_contour, area

    def get_bounding_box(
        self, contour: np.ndarray
    ) -> Dict[str, int]:
        """Extract bounding box from contour."""
        x, y, w, h = cv2.boundingRect(contour)
        return {"x": int(x), "y": int(y), "width": int(w), "height": int(h)}

    def detect_skin(self, image_bytes: bytes) -> Dict[str, Any]:
        """
        Main skin detection pipeline.

        Args:
            image_bytes: Raw image bytes (JPEG or PNG)

        Returns:
            Dictionary with detection results:
            - skin_detected: bool
            - confidence: float (0-1)
            - bounding_box: dict or None
            - skin_area_percentage: float
            - message: str
        """
        result = {
            "skin_detected": False,
            "confidence": 0.0,
            "bounding_box": None,
            "skin_area_percentage": 0.0,
            "message": "No skin detected. Point camera toward visible skin area.",
        }

        # Decode the image
        img = self.decode_image(image_bytes)
        if img is None:
            result["message"] = "Failed to decode image"
            return result

        # Resize for faster processing (720p -> 360p)
        height, width = img.shape[:2]
        scale = min(640 / width, 360 / height)
        if scale < 1.0:
            img = cv2.resize(img, (int(width * scale), int(height * scale)))
            height, width = img.shape[:2]

        total_pixels = height * width

        # Convert to HSV for skin detection
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

        # Create skin mask
        skin_mask = self.create_skin_mask(hsv)

        # Calculate skin area percentage
        skin_pixels = np.sum(skin_mask > 0)
        skin_percentage = (skin_pixels / total_pixels) * 100

        result["skin_area_percentage"] = round(float(skin_percentage), 2)

        if skin_percentage < self.MIN_SKIN_PERCENTAGE:
            result["message"] = "No skin detected. Point camera toward visible skin area."
            return result

        # Find largest skin region
        contour_result = self.find_largest_skin_contour(skin_mask)
        if contour_result is None:
            result["message"] = "Skin region too small. Please show more skin."
            return result

        contour, area = contour_result

        # Confidence score based on skin area percentage (capped at 95%)
        confidence = min(skin_percentage / 30.0, 0.95)

        # Scale bounding box back to original image size
        if scale < 1.0:
            inverse_scale = 1.0 / scale
            bbox = self.get_bounding_box(contour)
            bbox = {
                "x": int(bbox["x"] * inverse_scale),
                "y": int(bbox["y"] * inverse_scale),
                "width": int(bbox["width"] * inverse_scale),
                "height": int(bbox["height"] * inverse_scale),
            }
        else:
            bbox = self.get_bounding_box(contour)

        result.update({
            "skin_detected": True,
            "confidence": round(float(confidence), 3),
            "bounding_box": bbox,
            "message": "Skin detected! Tattoo overlay active.",
        })

        return result

    def apply_tattoo_overlay(
        self,
        frame_bytes: bytes,
        tattoo_bytes: bytes,
        x: int,
        y: int,
        scale: float = 1.0,
        rotation: float = 0.0,
        opacity: float = 0.8,
    ) -> Optional[bytes]:
        """
        Apply tattoo overlay to a camera frame (server-side blending).
        This is an optional server-side implementation;
        the Flutter client handles real-time overlay for performance.

        Args:
            frame_bytes: Camera frame image bytes
            tattoo_bytes: Tattoo PNG image bytes (with transparency)
            x, y: Position of tattoo center
            scale: Scale factor
            rotation: Rotation in degrees
            opacity: Opacity 0.0 - 1.0

        Returns:
            Blended image bytes or None on failure
        """
        try:
            frame = self.decode_image(frame_bytes)
            if frame is None:
                return None

            # Decode tattoo with alpha channel
            tattoo_arr = np.frombuffer(tattoo_bytes, np.uint8)
            tattoo = cv2.imdecode(tattoo_arr, cv2.IMREAD_UNCHANGED)
            if tattoo is None:
                return None

            # Ensure tattoo has alpha channel
            if tattoo.shape[2] == 3:
                tattoo = cv2.cvtColor(tattoo, cv2.COLOR_BGR2BGRA)

            fh, fw = frame.shape[:2]
            th, tw = tattoo.shape[:2]

            # Scale tattoo
            new_w = int(tw * scale)
            new_h = int(th * scale)
            if new_w < 1 or new_h < 1:
                return None
            tattoo = cv2.resize(tattoo, (new_w, new_h))

            # Rotate tattoo
            if rotation != 0:
                center = (new_w // 2, new_h // 2)
                rot_mat = cv2.getRotationMatrix2D(center, -rotation, 1.0)
                cos, sin = abs(rot_mat[0, 0]), abs(rot_mat[0, 1])
                nw = int(new_h * sin + new_w * cos)
                nh = int(new_h * cos + new_w * sin)
                rot_mat[0, 2] += (nw / 2) - center[0]
                rot_mat[1, 2] += (nh / 2) - center[1]
                tattoo = cv2.warpAffine(
                    tattoo, rot_mat, (nw, nh),
                    flags=cv2.INTER_LINEAR,
                    borderMode=cv2.BORDER_CONSTANT,
                    borderValue=(0, 0, 0, 0),
                )
                new_w, new_h = nw, nh

            # Calculate overlay position (centered at x, y)
            x1 = x - new_w // 2
            y1 = y - new_h // 2
            x2 = x1 + new_w
            y2 = y1 + new_h

            # Clip to frame boundaries
            fx1 = max(0, x1)
            fy1 = max(0, y1)
            fx2 = min(fw, x2)
            fy2 = min(fh, y2)

            if fx1 >= fx2 or fy1 >= fy2:
                return None

            # Crop tattoo to visible region
            tx1 = fx1 - x1
            ty1 = fy1 - y1
            tx2 = tx1 + (fx2 - fx1)
            ty2 = ty1 + (fy2 - fy1)

            tattoo_crop = tattoo[ty1:ty2, tx1:tx2]
            frame_region = frame[fy1:fy2, fx1:fx2]

            # Alpha blending with opacity control
            alpha = tattoo_crop[:, :, 3:4].astype(np.float32) / 255.0 * opacity
            tattoo_bgr = tattoo_crop[:, :, :3].astype(np.float32)
            frame_float = frame_region.astype(np.float32)

            blended = (tattoo_bgr * alpha + frame_float * (1 - alpha)).astype(np.uint8)
            frame[fy1:fy2, fx1:fx2] = blended

            # Encode back to JPEG
            success, encoded = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 85])
            if not success:
                return None

            return encoded.tobytes()

        except Exception as e:
            logger.error(f"Tattoo overlay failed: {e}")
            return None


# Singleton instance
vision_service = VisionService()
