import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/bond.dart';
import 'api_service.dart';

class BondsProvider extends ChangeNotifier {
  final ApiService api;
  BondsProvider(this.api);

  // Default bonds catalog state
  List<Bond> bonds = [];
  bool loading = false;
  String? error;
  
  // Independent search state
  List<Bond> searchResults = [];
  bool searchLoading = false;
  String searchQuery = '';
  Timer? _debounce;
  
  // UI Display Metric toggle
  String displayMetric = 'bondYield';

  Future<void> loadInitial() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      // Always fetches the default catalog view
      bonds = await api.getBonds(
        sortBy: 'bondYield', 
        sortOrder: 'desc'
      );
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  // Searches bonds independently so we don't overwrite the main catalog list
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

  void applyColor(String isin, String? color) {
    // Update main list
    final i = bonds.indexWhere((b) => b.isin == isin);
    if (i != -1) {
      bonds[i] = bonds[i].copyWith(color: color);
    }
    // Update search list so they stay in sync
    final j = searchResults.indexWhere((b) => b.isin == isin);
    if (j != -1) {
      searchResults[j] = searchResults[j].copyWith(color: color);
    }
    notifyListeners();
  }

  void setDisplayMetric(String metric) {
    if (displayMetric == metric) return;
    displayMetric = metric;
    notifyListeners();
  }
}