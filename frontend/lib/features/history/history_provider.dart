import 'package:flutter/material.dart';
import '../../data/models/tryon_result_model.dart';
import '../../data/services/api_service.dart';

/// State management for the history screen.
class HistoryProvider extends ChangeNotifier {
  final ApiService _apiService;

  HistoryProvider(this._apiService);

  List<TryOnResultModel> _results = [];
  bool _isLoading = false;
  String? _error;

  List<TryOnResultModel> get results => _results;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadHistory() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _results = await _apiService.getHistory();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
