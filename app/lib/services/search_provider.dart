import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/bond.dart';
import 'api_service.dart';

class SearchProvider extends ChangeNotifier {
  final ApiService api;
  SearchProvider(this.api);

  List<Bond> searchResults = [];
  bool searchLoading = false;
  String searchQuery = '';
  String? error;
  Timer? _debounce;

  void search(String query) {
    searchQuery = query;
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }

    if (query.trim().isEmpty) {
      searchResults = [];
      searchLoading = false;
      notifyListeners();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      searchLoading = true;
      notifyListeners();
      try {
        searchResults = await api.searchBonds(query.trim());
      } catch (e) {
        error = e.toString();
      } finally {
        searchLoading = false;
        notifyListeners();
      }
    });
  }

  void clear() {
    searchQuery = '';
    searchResults = [];
    searchLoading = false;
    error = null;
    _debounce?.cancel();
    notifyListeners();
  }
}
