import 'package:flutter/foundation.dart';
import '../models/wishlist.dart';
import 'api_service.dart';

class WishlistProvider extends ChangeNotifier {
  final ApiService api;
  WishlistProvider(this.api);

  List<Wishlist> wishlists = [];
  bool loading = false;
  String? error;

  // In-memory storage for sort preferences per wishlist
  final Map<String, String> _sortPrefs = {};
  final Map<String, String> _sortOrderPrefs = {};

  List<Wishlist> get sorted {
    final list = [...wishlists];
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      wishlists = await api.getWishlists();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<bool> create(String name) async {
    try {
      final wl = await api.createWishlist(name);
      wishlists.add(wl);
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> rename(String id, String name) async {
    final wl = await api.renameWishlist(id, name);
    final i = wishlists.indexWhere((w) => w.id == id);
    if (i != -1) {
      wishlists[i] = wl;
      notifyListeners();
    }
  }

  Future<void> remove(String id) async {
    await api.deleteWishlist(id);
    wishlists.removeWhere((w) => w.id == id);
    notifyListeners();
  }

  String getSortPref(String wishlistId) {
    return _sortPrefs[wishlistId] ?? 'manual';
  }

  void setSortPref(String wishlistId, String sort) {
    _sortPrefs[wishlistId] = sort;
  }
  
  String getSortOrderPref(String wishlistId) {
    return _sortOrderPrefs[wishlistId] ?? 'desc';
  }

  void setSortOrderPref(String wishlistId, String order) {
    _sortOrderPrefs[wishlistId] = order;
  }
}