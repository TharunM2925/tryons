import 'package:flutter/material.dart';
import '../../data/models/tattoo_model.dart';
import '../../data/services/api_service.dart';

/// State management for the tattoo upload & gallery feature.
class TattooProvider extends ChangeNotifier {
  final ApiService _apiService;

  TattooProvider(this._apiService);

  List<TattooModel> _tattoos = [];
  bool _isLoading = false;
  bool _isUploading = false;
  String? _error;
  TattooModel? _selectedTattoo;

  List<TattooModel> get tattoos => _tattoos;
  bool get isLoading => _isLoading;
  bool get isUploading => _isUploading;
  String? get error => _error;
  TattooModel? get selectedTattoo => _selectedTattoo;

  void selectTattoo(TattooModel tattoo) {
    _selectedTattoo = tattoo;
    notifyListeners();
  }

  void clearSelection() {
    _selectedTattoo = null;
    notifyListeners();
  }

  Future<void> loadTattoos() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _tattoos = await _apiService.getTattoos();
    } catch (e) {
      _error = _formatError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<TattooModel?> uploadTattoo({
    required dynamic file,
    required String name,
  }) async {
    _isUploading = true;
    _error = null;
    notifyListeners();

    try {
      final tattoo = await _apiService.uploadTattoo(file: file, name: name);
      _tattoos.insert(0, tattoo);
      _selectedTattoo = tattoo;
      notifyListeners();
      return tattoo;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return null;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<TattooModel?> uploadTattooBytes({
    required List<int> bytes,
    required String fileName,
    required String name,
  }) async {
    _isUploading = true;
    _error = null;
    notifyListeners();

    try {
      final tattoo = await _apiService.uploadTattooBytes(bytes: bytes, fileName: fileName, name: name);
      _tattoos.insert(0, tattoo);
      _selectedTattoo = tattoo;
      notifyListeners();
      return tattoo;
    } catch (e) {
      _error = _formatError(e);
      notifyListeners();
      return null;
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  String _formatError(Object e) {
    if (e is Exception) {
      return e.toString().replaceFirst('Exception: ', '');
    }
    return 'An unexpected error occurred';
  }
}
