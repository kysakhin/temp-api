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
  
  // Sorting state
  String sortBy = 'bondYield';
  String sortOrder = 'desc';

  // UI Display Metric toggle
  String _displayMetricOverride = '';
  
  String get displayMetric {
    if (_displayMetricOverride.isNotEmpty) {
      return _displayMetricOverride;
    }
    return sortBy == 'minInvestment' ? 'minInvestment' : 'bondYield';
  }

  Future<void> loadInitial() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (searchQuery.trim().isNotEmpty) {
        searchResults = await api.searchBonds(searchQuery.trim());
      } else {
        bonds = await api.getBonds(
          sortBy: sortBy, 
          sortOrder: sortOrder
        );
      }
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void search(String query) {
    searchQuery = query;
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    
    if (query.trim().isEmpty) {
      searchResults = [];
      searchLoading = false;
      loadInitial(); 
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
    final i = bonds.indexWhere((b) => b.isin == isin);
    if (i != -1) {
      bonds[i] = bonds[i].copyWith(color: color);
    }
    final j = searchResults.indexWhere((b) => b.isin == isin);
    if (j != -1) {
      searchResults[j] = searchResults[j].copyWith(color: color);
    }
    notifyListeners();
  }

  Future<void> setSort(String newSortBy) async {
    if (sortBy == newSortBy) return;
    sortBy = newSortBy;
    _displayMetricOverride = ''; // Clear override when true backend sort changes
    await loadInitial();
  }

  Future<void> toggleSortOrder() async {
    sortOrder = sortOrder == 'asc' ? 'desc' : 'asc';
    await loadInitial();
  }

  // Purely visual toggle for screens like Search that don't hit the sort API
  void setDisplayMetric(String metric) {
    _displayMetricOverride = metric;
    notifyListeners();
  }
}