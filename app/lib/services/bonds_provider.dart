import 'package:flutter/foundation.dart';
import '../models/bond.dart';
import 'api_service.dart';

class BondsProvider extends ChangeNotifier {
  final ApiService api;
  BondsProvider(this.api);

  List<Bond> bonds = [];
  bool loading = false;
  String? error;
  
  // Defaulting to highest yield first
  String currentSortBy = 'bondYield';
  String currentSortOrder = 'desc'; 

  Future<void> loadInitial() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      // The API now returns the full list in one go
      bonds = await api.getBonds(
        sortBy: currentSortBy, 
        sortOrder: currentSortOrder
      );
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void applyColor(String isin, String? color) {
    final i = bonds.indexWhere((b) => b.isin == isin);
    if (i != -1) {
      bonds[i] = bonds[i].copyWith(color: color);
      notifyListeners();
    }
  }

  Future<void> setSort(String sortBy) async {
    if (currentSortBy == sortBy) {
      // Toggle sort order if they tap the same sort option
      currentSortOrder = currentSortOrder == 'desc' ? 'asc' : 'desc';
    } else {
      // Default to descending when switching to a new metric (e.g. highest yield)
      currentSortBy = sortBy;
      currentSortOrder = 'desc';
    }
    await loadInitial();
  }
}