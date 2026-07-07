import 'bond.dart';

class Wishlist {
  final String id;
  final String name;
  final int bondCount;
  final String createdAt;
  final String updatedAt;

  Wishlist({
    required this.id,
    required this.name,
    required this.bondCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Wishlist.fromJson(Map<String, dynamic> j) => Wishlist(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? 'Untitled Wishlist',
        bondCount: j['bondCount'] as int? ?? 0,
        createdAt: j['createdAt'] as String? ?? '',
        updatedAt: j['updatedAt'] as String? ?? '',
      );

  Wishlist copyWith({String? name, int? bondCount}) => Wishlist(
        id: id,
        name: name ?? this.name,
        bondCount: bondCount ?? this.bondCount,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

class WishlistDetails extends Wishlist {
  final List<Bond> bonds;

  WishlistDetails({
    required super.id,
    required super.name,
    required super.bondCount,
    required super.createdAt,
    required super.updatedAt,
    required this.bonds,
  });

  factory WishlistDetails.fromJson(Map<String, dynamic> j) => WishlistDetails(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? 'Untitled Wishlist',
        bondCount: j['bondCount'] as int? ?? 0,
        createdAt: j['createdAt'] as String? ?? '',
        updatedAt: j['updatedAt'] as String? ?? '',
        bonds: (j['bonds'] as List<dynamic>? ?? [])
            .map((e) => Bond.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}