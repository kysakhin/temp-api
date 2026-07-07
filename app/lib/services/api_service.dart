import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bond.dart';
import '../models/wishlist.dart';
import '../utils/constants.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  final http.Client _client;
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  Uri _u(String path, [Map<String, String>? qp]) =>
      Uri.parse('$apiBaseUrl$path').replace(queryParameters: qp);

  void _check(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    try {
      final body = jsonDecode(r.body);
      throw ApiException(body['message'] ?? 'Something went wrong.');
    } catch (_) {
      throw ApiException('Request failed (${r.statusCode}).');
    }
  }

  // ── Bonds ──────────────────────────────────────────────────────────────
  
  Future<List<Bond>> getBonds({
    String sortBy = 'bondYield',
    String sortOrder = 'desc',
  }) async {
    final r = await _client.get(_u('/bond', {
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    }));
    _check(r);
    final j = jsonDecode(r.body);
    return (j['data'] as List).map((e) => Bond.fromJson(e)).toList();
  }

  Future<void> updateWishlistBondColor(String wishlistId, String isin, String? colorHex) async {
    final r = await _client.patch(
      _u('/wishlist/$wishlistId/bond/$isin/color'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'color': colorHex}),
    );
    _check(r);
  }

  // ── Wishlists ──────────────────────────────────────────────────────────
  
  Future<List<Wishlist>> getWishlists() async {
    final r = await _client.get(_u('/wishlist'));
    _check(r);
    final Map<String, dynamic> j = jsonDecode(r.body);
    return (j['data'] as List).map((e) => Wishlist.fromJson(e)).toList();
  }

  Future<WishlistDetails> getWishlist(String id, {String sortBy = 'addedRecently'}) async {
    final r = await _client.get(_u('/wishlist/$id', {'sortBy': sortBy}));
    _check(r);
    final Map<String, dynamic> j = jsonDecode(r.body);
    return WishlistDetails.fromJson(j['data'] ?? j);
  }

  Future<Wishlist> createWishlist(String name) async {
    final r = await _client.post(
      _u('/wishlist'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    _check(r);
    final Map<String, dynamic> j = jsonDecode(r.body);
    return Wishlist.fromJson(j['data'] ?? j);
  }

  Future<Wishlist> renameWishlist(String id, String name) async {
    final r = await _client.patch(
      _u('/wishlist/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    _check(r);
    final Map<String, dynamic> j = jsonDecode(r.body);
    return Wishlist.fromJson(j['data'] ?? j);
  }

  Future<void> deleteWishlist(String id) async {
    final r = await _client.delete(_u('/wishlist/$id'));
    _check(r);
  }

  Future<void> addBond(String wishlistId, String isin) async {
    final r = await _client.post(
      _u('/wishlist/$wishlistId/bond'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'bondIsin': isin}),
    );
    _check(r);
  }

  Future<void> removeBond(String wishlistId, String isin) async {
    final r = await _client.delete(_u('/wishlist/$wishlistId/bond/$isin'));
    _check(r);
  }

  Future<void> setBondPinned(String wishlistId, String isin, bool isPinned) async {
    final r = await _client.patch(
      _u('/wishlist/$wishlistId/bond/$isin/pin'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'isPinned': isPinned}),
    );
    _check(r);
  }

  Future<void> reorderBonds(String wishlistId, List<String> isinOrder) async {
    final r = await _client.patch(
      _u('/wishlist/$wishlistId/reorder'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'bondIsins': isinOrder}),
    );
    _check(r);
  }
}