import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:file_saver/file_saver.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/tattoo_model.dart';
import '../../data/services/api_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_widget.dart';
import '../tattoo_upload/tattoo_provider.dart';
import 'tryon_provider.dart';

/// Camera Try-On screen — the core feature of InkVision AI.
/// Displays live camera preview with interactive tattoo overlay.
class CameraTryOnScreen extends StatefulWidget {
  final Uint8List? selectedTattooBytes;

  const CameraTryOnScreen({
    super.key,
    this.selectedTattooBytes,
  });

  @override
  State<CameraTryOnScreen> createState() => _CameraTryOnScreenState();
}

class _CameraTryOnScreenState extends State<CameraTryOnScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isCameraInitialized = false;
  bool _isFrontCamera = true;
  String? _cameraError;

  // Frame processing
  Timer? _frameTimer;
  bool _isCapturing = false;

  // Gesture state for pinch-to-zoom + rotate
  double _baseScale = 1.0;
  double _baseRotation = 0.0;

  // Repaint key for capturing the overlay composite
  final GlobalKey _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _startFrameTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _frameTimer?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _cameraError = 'No cameras available on this device.');
        return;
      }

      // Pick front or back camera
      final description = _isFrontCamera
          ? _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => _cameras.first,
            )
          : _cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.back,
              orElse: () => _cameras.first,
            );

      final controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      if (mounted) {
        setState(() {
          _cameraController = controller;
          _isCameraInitialized = true;
          _cameraError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cameraError = 'Camera error: ${e.toString()}');
      }
    }
  }

  void _startFrameTimer() {
    _frameTimer = Timer.periodic(
      Duration(milliseconds: AppConstants.frameProcessIntervalMs),
      (_) => _processCurrentFrame(),
    );
  }

  Future<void> _processCurrentFrame() async {
    if (!_isCameraInitialized || _cameraController == null) return;
    final tryOnProvider = context.read<TryOnProvider>();
    final tattooProvider = context.read<TattooProvider>();
    if (tattooProvider.selectedTattoo == null) return;
    if (tryOnProvider.isProcessingFrame) return;

    try {
      final image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();
      final base64Str = base64Encode(bytes);

      await tryOnProvider.processFrame(
        tattooId: tattooProvider.selectedTattoo!.id,
        frameBase64: base64Str,
      );
    } catch (_) {
      // Camera may not be ready — silently skip
    }
  }

  void _flipCamera() {
    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _isCameraInitialized = false;
    });
    _cameraController?.dispose();
    _cameraController = null;
    _initCamera();
  }

  Future<void> _captureResult() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    try {
      _showSnack('Processing capture...', isSuccess: true);
      
      // 1. Capture the camera image
      final cameraFile = await _cameraController!.takePicture();
      final cameraBytes = await cameraFile.readAsBytes();
      
      final codec = await ui.instantiateImageCodec(cameraBytes);
      final frameInfo = await codec.getNextFrame();
      final cameraUiImage = frameInfo.image;

      // 2. Capture the tattoo overlay
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        _showSnack('Capture failed — please try again');
        return;
      }

      final pixelRatio = MediaQuery.of(context).devicePixelRatio;
      final tattooUiImage = await boundary.toImage(pixelRatio: pixelRatio);

      // 3. Composite them
      final screenSize = MediaQuery.of(context).size;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      final targetRect = Rect.fromLTWH(0, 0, screenSize.width * pixelRatio, screenSize.height * pixelRatio);

      // Draw camera image
      canvas.save();
      if (_isFrontCamera) {
        // Mirror front camera
        canvas.translate(targetRect.width, 0);
        canvas.scale(-1, 1);
      }
      paintImage(
        canvas: canvas,
        rect: targetRect,
        image: cameraUiImage,
        fit: BoxFit.cover,
      );
      canvas.restore();

      // Draw tattoo overlay
      canvas.drawImage(tattooUiImage, Offset.zero, Paint());

      final picture = recorder.endRecording();
      final finalImage = await picture.toImage(
        targetRect.width.toInt(), 
        targetRect.height.toInt(),
      );

      final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final pngBytes = byteData.buffer.asUint8List();
      final base64Str = base64Encode(pngBytes);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Save using FileSaver (works on Web, Android, iOS, Windows, etc.)
      await FileSaver.instance.saveFile(
        name: 'inkvision_$timestamp.png',
        bytes: pngBytes,
      );

      // Save to backend
      final tryOnProvider = context.read<TryOnProvider>();
      final tattooProvider = context.read<TattooProvider>();

      if (tattooProvider.selectedTattoo != null) {
        await tryOnProvider.saveResult(
          tattooId: tattooProvider.selectedTattoo!.id,
          resultImageBase64: base64Str,
        );
      }

      if (mounted) {
        _showSnack('Saved to gallery! ✓', isSuccess: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Error: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? AppTheme.accent : AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<TryOnProvider, TattooProvider>(
      builder: (context, tryOn, tattoos, _) {
        final args = ModalRoute.of(context)?.settings.arguments as Uint8List?;
        final tattooBytes = widget.selectedTattooBytes ?? args;

        if (tattooBytes != null && _isCameraInitialized) {
          debugPrint("Original cropped tattoo bytes: ${args?.length ?? widget.selectedTattooBytes?.length ?? 0}");
          debugPrint("Processed transparent tattoo bytes: ${tattooBytes.length}");
          debugPrint("Camera received tattoo bytes: ${tattooBytes.length}");
          debugPrint("Rendering transparent tattoo overlay");
        }

        return Scaffold(
          backgroundColor: Colors.black,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.flip_camera_ios_rounded,
                      color: Colors.white, size: 20),
                ),
                onPressed: _flipCamera,
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Stack(
            children: [
              // ── Camera Layer ──────────────────────────────────────────
              Stack(
                children: [
                  _buildCameraLayer(),
                  // Tattoo overlay
                  if (_isCameraInitialized &&
                      (tattoos.selectedTattoo != null ||
                          tattooBytes != null))
                    _TattooOverlay(
                      repaintKey: _repaintKey,
                      tattoo: tattoos.selectedTattoo,
                      tattooBytes: tattooBytes,
                      apiService: context.read<ApiService>(),
                      tryOnProvider: tryOn,
                        onScaleStart: (_) {
                          _baseScale = tryOn.tattooScale;
                          _baseRotation = tryOn.tattooRotation;
                        },
                        onScaleUpdate: (details) {
                          // Handle scale
                          tryOn.setScale(_baseScale * details.scale);
                          
                          // Handle rotation
                          tryOn.updateRotation(
                            (details.rotation - _baseRotation) *
                                180 /
                                math.pi,
                          );
                          _baseRotation = details.rotation;
                          
                          // Handle panning
                          tryOn.updatePosition(details.focalPointDelta);
                        },
                      ),
                  ],
                ),

              // ── Skin Detection Status Banner ──────────────────────────
              if (_isCameraInitialized)
                Positioned(
                  top: 100,
                  left: 20,
                  right: 20,
                  child: _SkinStatusBanner(
                    skinDetected: tryOn.skinDetected,
                    message: tryOn.skinStatusMessage,
                  ),
                ),

              // ── No Tattoo Selected Warning ────────────────────────────
              if (tattoos.selectedTattoo == null &&
                  tattooBytes == null &&
                  _isCameraInitialized)
                Positioned(
                  top: 140,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'No tattoo selected. Go to Gallery to pick one.',
                            style: TextStyle(
                                color: Colors.white, fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Gallery',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── Bottom Controls ───────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _BottomControls(
                  tryOnProvider: tryOn,
                  selectedTattoo: tattoos.selectedTattoo,
                  isCapturing: _isCapturing,
                  onCapture: _captureResult,
                  onReset: tryOn.resetTransform,
                  onSelectTattoo: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCameraLayer() {
    if (_cameraError != null) {
      return _CameraErrorWidget(message: _cameraError!);
    }
    if (!_isCameraInitialized || _cameraController == null) {
      return const _CameraLoadingWidget();
    }
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize!.height,
          height: _cameraController!.value.previewSize!.width,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }
}

// ─────────────────────────── Overlay Widget ──────────────────────────────────

class _TattooOverlay extends StatelessWidget {
  final GlobalKey repaintKey;
  final TattooModel? tattoo;
  final Uint8List? tattooBytes;
  final ApiService apiService;
  final TryOnProvider tryOnProvider;
  final void Function(ScaleStartDetails) onScaleStart;
  final void Function(ScaleUpdateDetails) onScaleUpdate;

  const _TattooOverlay({
    required this.repaintKey,
    this.tattoo,
    this.tattooBytes,
    required this.apiService,
    required this.tryOnProvider,
    required this.onScaleStart,
    required this.onScaleUpdate,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        key: repaintKey,
        child: GestureDetector(
          onScaleStart: onScaleStart,
          onScaleUpdate: onScaleUpdate,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final center = Offset(
                constraints.maxWidth / 2 + tryOnProvider.tattooPosition.dx,
                constraints.maxHeight / 2 + tryOnProvider.tattooPosition.dy,
              );

              return Stack(
                children: [
                  Positioned(
                    left: center.dx - 120 * tryOnProvider.tattooScale,
                    top: center.dy - 120 * tryOnProvider.tattooScale,
                    child: Transform.rotate(
                      angle: tryOnProvider.tattooRotation * math.pi / 180,
                      child: Opacity(
                        opacity: tryOnProvider.tattooOpacity,
                        child: tattooBytes != null
                            ? Image.memory(
                                tattooBytes!,
                                width: 240 * tryOnProvider.tattooScale,
                                height: 240 * tryOnProvider.tattooScale,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                isAntiAlias: true,
                              )
                            : Image.network(
                                apiService.buildImageUrl(tattoo!.imageUrl),
                                width: 240 * tryOnProvider.tattooScale,
                                height: 240 * tryOnProvider.tattooScale,
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.high,
                                isAntiAlias: true,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────── Bottom Controls ─────────────────────────────────

class _BottomControls extends StatelessWidget {
  final TryOnProvider tryOnProvider;
  final TattooModel? selectedTattoo;
  final bool isCapturing;
  final VoidCallback onCapture;
  final VoidCallback onReset;
  final VoidCallback onSelectTattoo;

  const _BottomControls({
    required this.tryOnProvider,
    required this.selectedTattoo,
    required this.isCapturing,
    required this.onCapture,
    required this.onReset,
    required this.onSelectTattoo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.95), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Selected tattoo chip
          if (selectedTattoo != null || ModalRoute.of(context)?.settings.arguments != null || (context.findAncestorWidgetOfExactType<CameraTryOnScreen>()?.selectedTattooBytes != null))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primary.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      color: AppTheme.primary, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    selectedTattoo?.name ?? 'Sheet Tattoo',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Opacity slider
          Row(
            children: [
              const Icon(Icons.opacity, color: Colors.white54, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                  ),
                  child: Slider(
                    value: tryOnProvider.tattooOpacity,
                    min: 0.4,
                    max: 1.0,
                    onChanged: tryOnProvider.setOpacity,
                  ),
                ),
              ),
              Text(
                '${(tryOnProvider.tattooOpacity * 100).round()}%',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Action buttons row
          Row(
            children: [
              // Gallery select
              _ControlButton(
                icon: Icons.photo_library_outlined,
                label: 'Gallery',
                onTap: onSelectTattoo,
              ),
              const SizedBox(width: 10),

              // Capture button (center, large)
              Expanded(
                child: GestureDetector(
                  onTap: isCapturing ? null : onCapture,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primary, AppTheme.primaryDark],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isCapturing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: AppTheme.bgDark,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.camera_alt_rounded,
                                    color: AppTheme.bgDark, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  'Capture',
                                  style: TextStyle(
                                    color: AppTheme.bgDark,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Reset button
              _ControlButton(
                icon: Icons.refresh_rounded,
                label: 'Reset',
                onTap: onReset,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        height: 60,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────── Status Banner ────────────────────────────────────

class _SkinStatusBanner extends StatelessWidget {
  final bool skinDetected;
  final String message;

  const _SkinStatusBanner({required this.skinDetected, required this.message});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: skinDetected
            ? AppTheme.accent.withOpacity(0.85)
            : Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: skinDetected ? AppTheme.accent : Colors.white24,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            skinDetected
                ? Icons.fiber_manual_record
                : Icons.fiber_manual_record_outlined,
            color: skinDetected ? Colors.white : Colors.white54,
            size: 10,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                color: skinDetected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight:
                    skinDetected ? FontWeight.w600 : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────── Camera States ────────────────────────────────────

class _CameraLoadingWidget extends StatelessWidget {
  const _CameraLoadingWidget();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppLoadingWidget(),
            SizedBox(height: 16),
            Text('Initializing camera…',
                style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
}

class _CameraErrorWidget extends StatelessWidget {
  final String message;
  const _CameraErrorWidget({required this.message});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off_rounded,
                  color: AppTheme.error, size: 60),
              const SizedBox(height: 16),
              Text(
                message,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}
