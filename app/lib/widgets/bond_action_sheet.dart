import 'package:flutter/material.dart';
import '../models/bond.dart';
import '../models/wishlist.dart';
import '../utils/constants.dart';

enum BondAction { openApp, setColor, addToWishlist, removeFromWishlist, togglePin }

Future<BondAction?> showBondActionSheet(
  BuildContext context, {
  required Bond bond,
  bool inWishlistContext = false,
}) {
  return showModalBottomSheet<BondAction>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(bond.bondName,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          _tile(ctx, Icons.open_in_new, 'Open in BondScanner app', BondAction.openApp),
          if (inWishlistContext) ...[
            _tile(
              ctx, 
              bond.isPinned ? Icons.push_pin_outlined : Icons.push_pin, 
              bond.isPinned ? 'Unpin from top' : 'Pin to top', 
              BondAction.togglePin
            ),
            _tile(ctx, Icons.label_outline, 'Set tag color', BondAction.setColor),
          ],
          if (!inWishlistContext)
            _tile(ctx, Icons.playlist_add, 'Add to wishlist', BondAction.addToWishlist),
          if (inWishlistContext) ...[
            _tile(ctx, Icons.remove_circle_outline, 'Remove from this wishlist',
                BondAction.removeFromWishlist, danger: true),
          ],
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Widget _tile(BuildContext ctx, IconData icon, String label, BondAction action,
    {bool danger = false}) {
  final color = danger ? AppColors.red : AppColors.navyDeep;
  return ListTile(
    leading: Icon(icon, color: color),
    title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
    onTap: () => Navigator.pop(ctx, action),
  );
}

Future<void> showAddToWishlistSheet(
  BuildContext context, {
  required List<Wishlist> wishlists,
  required Set<String> alreadyIn,
  required Future<void> Function(String wishlistId) onAdd,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4, bottom: 8),
              child: Text('Add to wishlist',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            if (wishlists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('No wishlists yet. Create one first.',
                    style: TextStyle(color: AppColors.muted)),
              ),
            ...wishlists.map((w) {
              final full = w.bondCount >= maxBondsPerWishlist;
              final already = alreadyIn.contains(w.id);
              return ListTile(
                title: Text(w.name),
                subtitle: Text('${w.bondCount}/$maxBondsPerWishlist bonds'),
                trailing: already
                    ? const Icon(Icons.check_circle, color: AppColors.green)
                    : full
                        ? const Text('Full', style: TextStyle(color: AppColors.muted))
                        : null,
                enabled: !already && !full,
                onTap: (already || full)
                    ? null
                    : () async {
                        await onAdd(w.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
              );
            }),
          ],
        ),
      ),
    ),
  );
}