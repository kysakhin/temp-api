import 'package:flutter/foundation.dart';
import '../models/bond.dart';
import 'api_service.dart';

class BondsProvider extends ChangeNotifier {
  final ApiService api;
  BondsProvider(this.api);

  List<Bond> bonds = [];
  bool loading = false;
  String? error;
  
  // Used purely for toggling what is displayed in the UI
  String displayMetric = 'bondYield';

  Future<void> loadInitial() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      // The API now just fetches the default list (e.g. highest yield)
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

  void applyColor(String isin, String? color) {
    final i = bonds.indexWhere((b) => b.isin == isin);
    if (i != -1) {
      bonds[i] = bonds[i].copyWith(color: color);
      notifyListeners();
    }
  }

  // Simply swaps the UI metric without calling the API
  void setDisplayMetric(String metric) {
    if (displayMetric == metric) return;
    displayMetric = metric;
    notifyListeners();
  }
}