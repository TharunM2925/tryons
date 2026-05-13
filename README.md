# 🖋️ InkVision AI — Virtual Tattoo Try-On

> **Wear Your Ink Before You Ink**
>
> A full-stack mobile app for real-time virtual tattoo try-on using computer vision.

---

## 📐 Architecture Overview

```
tryonstatattoo/
├── backend/                   # FastAPI Python backend
│   ├── app/
│   │   ├── main.py            # App entry point, CORS, routing
│   │   ├── core/
│   │   │   ├── config.py      # Pydantic settings (env vars)
│   │   │   └── security.py    # JWT utils (future auth)
│   │   ├── database/
│   │   │   ├── session.py     # Async SQLAlchemy engine + get_db
│   │   │   └── models.py      # ORM: Tattoo, TryOnResult, User
│   │   ├── schemas/
│   │   │   ├── tattoo_schema.py
│   │   │   └── tryon_schema.py
│   │   ├── routers/
│   │   │   ├── health_router.py
│   │   │   ├── tattoo_router.py
│   │   │   └── tryon_router.py
│   │   ├── services/
│   │   │   ├── tattoo_service.py
│   │   │   ├── tryon_service.py
│   │   │   └── vision_service.py  # OpenCV skin detection
│   │   └── utils/
│   │       └── file_utils.py
│   ├── requirements.txt
│   └── .env.example
│
└── frontend/                  # Flutter mobile/web app
    └── lib/
        ├── main.dart           # App entry, MultiProvider setup
        ├── app.dart            # MaterialApp, theme, routes
        ├── core/
        │   ├── theme/          # Dark neon theme
        │   ├── config/         # Route definitions
        │   └── constants/      # API URL, defaults
        ├── data/
        │   ├── models/         # TattooModel, TryOnResultModel
        │   └── services/       # ApiService (Dio)
        ├── features/
        │   ├── splash/         # Animated splash
        │   ├── home/           # Dashboard cards
        │   ├── tattoo_upload/  # Gallery + upload
        │   ├── camera_tryon/   # Live camera + overlay
        │   ├── history/        # Saved results
        │   └── settings/       # Config placeholder
        └── widgets/            # Shared widgets
```

---

## 🚀 Setup Instructions

### Prerequisites
- Python 3.11+
- Flutter SDK 3.x
- PostgreSQL 14+
- Android Studio / VS Code

---

### 1. PostgreSQL Setup

```sql
-- Create database
CREATE DATABASE inkvision_db;

-- (Optional) Create dedicated user
CREATE USER inkvision_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE inkvision_db TO inkvision_user;
```

Tables are **auto-created** on backend startup via SQLAlchemy.

---

### 2. Backend Setup

```bash
cd backend

# Create and activate virtual environment
python -m venv venv
venv\Scripts\activate        # Windows
# source venv/bin/activate   # macOS/Linux

# Install dependencies
pip install -r requirements.txt

# Copy and configure environment
copy .env.example .env       # Windows
# cp .env.example .env       # macOS/Linux

# Edit .env with your DB credentials
notepad .env
```

**`.env` configuration:**
```env
DATABASE_URL=postgresql+asyncpg://postgres:YOUR_PASSWORD@localhost:5432/inkvision_db
SYNC_DATABASE_URL=postgresql://postgres:YOUR_PASSWORD@localhost:5432/inkvision_db
SECRET_KEY=your-random-32-char-secret
```

**Run the backend:**
```bash
cd backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Backend will be available at: http://localhost:8000
API docs: http://localhost:8000/docs

---

### 3. Flutter Frontend Setup

```bash
cd frontend

# Install Flutter dependencies
flutter pub get

# Run on Android emulator
flutter run -d android

# Run on Chrome (web)
flutter run -d chrome

# Run on Windows desktop
flutter run -d windows
```

> **Android Emulator**: The backend URL is set to `http://10.0.2.2:8000` in `lib/core/constants/app_constants.dart`.
> For a physical device, change this to your computer's local IP (e.g., `http://192.168.1.x:8000`).
>
> **Web**: Change `baseUrl` to `http://localhost:8000`.

---

## 🔌 API Endpoint Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Backend health check |
| `POST` | `/tattoos/upload` | Upload tattoo image (form-data) |
| `GET` | `/tattoos` | List all tattoos (paginated) |
| `GET` | `/tattoos/{id}` | Get tattoo by ID |
| `DELETE` | `/tattoos/{id}` | Delete a tattoo |
| `POST` | `/tryon/process-frame` | Detect skin in camera frame |
| `POST` | `/tryon/save-result` | Save try-on result + metadata |
| `GET` | `/tryon/history` | Get try-on history (paginated) |
| `GET` | `/tryon/history/{id}` | Get single result |

### Example: Upload Tattoo (cURL)
```bash
curl -X POST http://localhost:8000/tattoos/upload \
  -F "file=@/path/to/tattoo.png" \
  -F "name=Dragon Sleeve"
```

### Example: Process Frame (JSON)
```json
POST /tryon/process-frame
{
  "tattoo_id": 1,
  "frame_base64": "data:image/jpeg;base64,/9j/4AAQ..."
}
```

**Response:**
```json
{
  "skin_detected": true,
  "confidence": 0.72,
  "bounding_box": { "x": 120, "y": 80, "width": 240, "height": 300 },
  "skin_area_percentage": 21.5,
  "message": "Skin detected! Tattoo overlay active."
}
```

---

## 🧬 Computer Vision: Skin Detection Algorithm

The `VisionService` in `backend/app/services/vision_service.py` uses:

1. **Image decoding** — NumPy + OpenCV from bytes
2. **Resize** — Down-scale to ≤640px for speed
3. **HSV conversion** — `cv2.cvtColor(img, cv2.COLOR_BGR2HSV)`
4. **Dual-range HSV threshold** — Covers light to dark skin tones:
   - Range 1: Hue 0-25° (warm tones)
   - Range 2: Hue 160-180° (reddish tones that wrap around)
5. **Morphological cleanup** — Open → Close → Dilate to reduce noise
6. **Contour detection** — Finds largest skin region
7. **Bounding box** — Returned in original image coordinates
8. **Confidence** — Proportional to skin coverage %

To swap in a better model (e.g., MediaPipe Selfie Segmentation):
```python
# Replace detect_skin() in VisionService with your model's output
# The interface contract: returns dict with skin_detected, confidence, bounding_box
```

---

## 📱 Flutter Feature Details

### Camera Try-On Screen
- **Live preview** via `camera` package (`CameraController`)
- **Skin detection** — Sends JPEG frames to backend every 1.5s
- **Tattoo overlay** — `Image.network` rendered as `Positioned` widget
- **Drag** — `GestureDetector.onPanUpdate` moves tattoo
- **Pinch scale** — `GestureDetector.onScaleUpdate` scales tattoo
- **Rotation** — Scale gesture also handles rotation angle
- **Opacity** — `Slider` bound to `TryOnProvider.setOpacity()`
- **Capture** — `RenderRepaintBoundary.toImage()` captures the composite

### State Management
- **Provider** pattern with `ChangeNotifier`
- `TattooProvider` — uploads, gallery list, selection
- `TryOnProvider` — transform state (position/scale/rotation/opacity) + detection
- `HistoryProvider` — loads saved results from backend

---

## ⚠️ Known Limitations (Prototype)

| Issue | Detail |
|-------|--------|
| **Skin detection accuracy** | HSV thresholding may false-positive on wood/skin-toned surfaces |
| **Lighting sensitivity** | Works best in even, well-lit environments |
| **Web camera** | Web camera access requires HTTPS in production |
| **Performance** | Frame processing is periodic (1.5s), not every frame |
| **No auth** | Any user can access all data (single-user prototype) |
| **No file cleanup** | Old uploaded files persist indefinitely |
| **Perspective warp** | Tattoo overlay is flat, no 3D surface mapping |

---

## 🔮 Future Improvements

| Feature | Technology |
|---------|------------|
| Better skin segmentation | MediaPipe Selfie Segmentation / DeepLab v3 |
| Real AR tracking | ARCore (Android) / ARKit (iOS) |
| 3D body surface mapping | OpenCV stereo vision / depth sensors |
| Perspective tattoo warping | OpenCV `getPerspectiveTransform` + homography |
| AI tattoo generator | Stable Diffusion / DALL-E API |
| User authentication | JWT + bcrypt (structure already in `security.py`) |
| Cloud storage | AWS S3 / Google Cloud Storage |
| Subscription / payments | Stripe integration |
| Push notifications | Firebase Cloud Messaging |

---

## 🛠️ Tech Stack Summary

| Layer | Technology |
|-------|-----------|
| Mobile Frontend | Flutter 3.x + Provider |
| Backend API | FastAPI + Uvicorn |
| Database | PostgreSQL 14 + SQLAlchemy async |
| Computer Vision | OpenCV 4.9 (HSV skin detection) |
| HTTP Client | Dio (Flutter) |
| File Storage | Local filesystem (uploads/ folder) |
| Authentication | Prepared (JWT/bcrypt in security.py) |

---

## 📄 License

MIT License — Free for academic and personal use.

---

*Built with ❤️ for academic prototype demonstration — InkVision AI v1.0.0*
