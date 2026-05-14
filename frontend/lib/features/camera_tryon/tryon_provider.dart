import 'package:flutter/material.dart';
import '../../data/models/tryon_result_model.dart';
import '../../data/services/api_service.dart';
import '../../core/constants/app_constants.dart';

/// State for the Camera Try-On session.
class TryOnProvider extends ChangeNotifier {
  final ApiService _apiService;

  TryOnProvider(this._apiService);

  // ── Tattoo Transform State ─────────────────────────────────────────────
  Offset _tattooPosition = Offset.zero;
  double _tattooScale = AppConstants.defaultTattooScale;
  double _tattooRotation = 0.0;
  double _tattooOpacity = AppConstants.defaultTattooOpacity;

  // ── Realism Controls ───────────────────────────────────────────────────
  double _edgeSoftness = 0.0;     // 0.0 to 10.0
  double _inkDarkness = 1.0;      // 0.0 to 1.0
  double _realismIntensity = 0.5; // 0.0 to 1.0

  // ── Skin Detection State ───────────────────────────────────────────────
  bool _skinDetected = false;
  Map<String, dynamic>? _boundingBox;
  bool _isProcessingFrame = false;
  String _skinStatusMessage = 'Point camera toward visible skin area.';

  // ── Saving State ──────────────────────────────────────────────────────
  bool _isSaving = false;
  String? _saveError;
  TryOnResultModel? _lastSavedResult;

  // Getters
  Offset get tattooPosition => _tattooPosition;
  double get tattooScale => _tattooScale;
  double get tattooRotation => _tattooRotation;
  double get tattooOpacity => _tattooOpacity;
  
  double get edgeSoftness => _edgeSoftness;
  double get inkDarkness => _inkDarkness;
  double get realismIntensity => _realismIntensity;

  bool get skinDetected => _skinDetected;
  Map<String, dynamic>? get boundingBox => _boundingBox;
  bool get isProcessingFrame => _isProcessingFrame;
  String get skinStatusMessage => _skinStatusMessage;
  bool get isSaving => _isSaving;
  String? get saveError => _saveError;
  TryOnResultModel? get lastSavedResult => _lastSavedResult;

  // ── Transform Controls ────────────────────────────────────────────────

  void updatePosition(Offset delta) {
    _tattooPosition += delta;
    notifyListeners();
  }

  void setPosition(Offset position) {
    _tattooPosition = position;
    notifyListeners();
  }

  void updateScale(double scaleDelta) {
    _tattooScale = (_tattooScale * scaleDelta).clamp(
      AppConstants.minTattooScale,
      AppConstants.maxTattooScale,
    );
    notifyListeners();
  }

  void setScale(double scale) {
    _tattooScale = scale.clamp(
      AppConstants.minTattooScale,
      AppConstants.maxTattooScale,
    );
    notifyListeners();
  }

  void setOpacity(double opacity) {
    _tattooOpacity = opacity.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setEdgeSoftness(double softness) {
    _edgeSoftness = softness.clamp(0.0, 10.0);
    notifyListeners();
  }

  void setInkDarkness(double darkness) {
    _inkDarkness = darkness.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setRealismIntensity(double intensity) {
    _realismIntensity = intensity.clamp(0.0, 1.0);
    // Realism automatically ties opacity and edge softness
    _tattooOpacity = 0.85 - (intensity * 0.2); // 0.85 -> 0.65
    _edgeSoftness = intensity * 4.0;           // 0.0 -> 4.0
    notifyListeners();
  }



  void updateRotation(double angleDelta) {
    _tattooRotation += angleDelta;
    notifyListeners();
  }



  void resetTransform() {
    _tattooPosition = Offset.zero;
    _tattooScale = AppConstants.defaultTattooScale;
    _tattooRotation = 0.0;
    _tattooOpacity = AppConstants.defaultTattooOpacity;
    notifyListeners();
  }

  // ── Skin Detection ────────────────────────────────────────────────────

  Future<void> processFrame({
    required int tattooId,
    required String frameBase64,
  }) async {
    if (_isProcessingFrame) return; // Skip if already processing
    _isProcessingFrame = true;

    try {
      final result = await _apiService.processFrame(
        tattooId: tattooId,
        frameBase64: frameBase64,
      );

      _skinDetected = result['skin_detected'] ?? false;
      _boundingBox = result['bounding_box'];
      _skinStatusMessage = result['message'] ?? '';

      // If skin detected and tattoo not yet positioned, center on skin bbox
      // if (_skinDetected &&
      //     _boundingBox != null &&
      //     _tattooPosition == Offset.zero) {
      //   final bb = _boundingBox!;
      //   _tattooPosition = Offset(
      //     (bb['x'] as int) + (bb['width'] as int) / 2.0,
      //     (bb['y'] as int) + (bb['height'] as int) / 2.0,
      //   );
      // }
    } catch (_) {
      // Silently fail — keep showing last known state
    } finally {
      _isProcessingFrame = false;
      notifyListeners();
    }
  }

  void setSkinDetectedLocally(bool detected, {String? message}) {
    _skinDetected = detected;
    if (message != null) _skinStatusMessage = message;
    notifyListeners();
  }

  // ── Save Result ────────────────────────────────────────────────────────

  Future<TryOnResultModel?> saveResult({
    required int tattooId,
    required String resultImageBase64,
  }) async {
    _isSaving = true;
    _saveError = null;
    notifyListeners();

    try {
      final result = await _apiService.saveResult(
        tattooId: tattooId,
        resultImageBase64: resultImageBase64,
        positionX: _tattooPosition.dx,
        positionY: _tattooPosition.dy,
        scale: _tattooScale,
        rotation: _tattooRotation,
        opacity: _tattooOpacity,
      );
      _lastSavedResult = result;
      return result;
    } catch (e) {
      _saveError = e.toString();
      return null;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
