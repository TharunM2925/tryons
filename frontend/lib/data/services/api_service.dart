import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/constants/app_constants.dart';
import '../models/tattoo_model.dart';
import '../models/tryon_result_model.dart';

/// Centralized API service using Dio HTTP client.
/// All backend communication goes through this class.
class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Accept': 'application/json',
        },
      ),
    );

    // Add logging interceptor in debug mode
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
      ),
    );
  }

  // ── Health ─────────────────────────────────────────────────────────────

  Future<bool> checkHealth() async {
    try {
      final response = await _dio.get('/health');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ── Tattoos ────────────────────────────────────────────────────────────

  /// Upload a tattoo image from the device.
  Future<TattooModel> uploadTattoo({
    required dynamic file, // Accepts File or XFile
    required String name,
  }) async {
    final bytes = await file.readAsBytes();
    final fileName = file.name ?? 'upload.png';
    return uploadTattooBytes(bytes: bytes, fileName: fileName, name: name);
  }

  /// Upload processed tattoo bytes directly
  Future<TattooModel> uploadTattooBytes({
    required List<int> bytes,
    required String fileName,
    required String name,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: fileName,
      ),
      'name': name,
    });

    final response = await _dio.post('/tattoos/upload', data: formData);
    return TattooModel.fromJson(response.data);
  }

  /// Get a list of all uploaded tattoos.
  Future<List<TattooModel>> getTattoos({int skip = 0, int limit = 50}) async {
    final response = await _dio.get(
      '/tattoos',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    final list = response.data['tattoos'] as List;
    return list.map((e) => TattooModel.fromJson(e)).toList();
  }

  /// Get a single tattoo by ID.
  Future<TattooModel> getTattooById(int tattooId) async {
    final response = await _dio.get('/tattoos/$tattooId');
    return TattooModel.fromJson(response.data);
  }

  // ── Try-On ─────────────────────────────────────────────────────────────

  /// Process a camera frame for skin detection.
  /// Returns detection result from the backend.
  Future<Map<String, dynamic>> processFrame({
    required int tattooId,
    required String frameBase64,
  }) async {
    final response = await _dio.post(
      '/tryon/process-frame',
      data: {
        'tattoo_id': tattooId,
        'frame_base64': frameBase64,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Save a completed try-on result.
  Future<TryOnResultModel> saveResult({
    required int tattooId,
    required String resultImageBase64,
    required double positionX,
    required double positionY,
    required double scale,
    required double rotation,
    required double opacity,
    String? notes,
  }) async {
    final response = await _dio.post(
      '/tryon/save-result',
      data: {
        'tattoo_id': tattooId,
        'result_image_base64': resultImageBase64,
        'position_x': positionX,
        'position_y': positionY,
        'scale': scale,
        'rotation': rotation,
        'opacity': opacity,
        'notes': ?notes,
      },
    );
    return TryOnResultModel.fromJson(response.data);
  }

  /// Get try-on history.
  Future<List<TryOnResultModel>> getHistory({int skip = 0, int limit = 50}) async {
    final response = await _dio.get(
      '/tryon/history',
      queryParameters: {'skip': skip, 'limit': limit},
    );
    final list = response.data['results'] as List;
    return list.map((e) => TryOnResultModel.fromJson(e)).toList();
  }

  /// Build a full image URL from a relative path returned by the API.
  String buildImageUrl(String relativePath) {
    if (relativePath.startsWith('http')) return relativePath;
    return '${AppConstants.baseUrl}$relativePath';
  }
}
