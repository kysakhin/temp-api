import 'package:flutter/foundation.dart';
import '../models/bond.dart';
import 'api_service.dart';

class BondsProvider extends ChangeNotifier {
  final ApiService api;
  BondsProvider(this.api);

  List<Bond> bonds = [];
  bool loading = false;
  String? error;

  String sortBy = 'bondYield';
  String sortOrder = 'desc';

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
      bonds = await api.getBonds(
        sortBy: sortBy,
        sortOrder: sortOrder,
      );
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> setSort(String newSortBy) async {
    if (sortBy == newSortBy) return;
    sortBy = newSortBy;
    _displayMetricOverride = '';
    await loadInitial();
  }

  Future<void> toggleSortOrder() async {
    sortOrder = sortOrder == 'asc' ? 'desc' : 'asc';
    await loadInitial();
  }

  void setDisplayMetric(String metric) {
    _displayMetricOverride = metric;
    notifyListeners();
  }
}