import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/wishlist_provider.dart';
import '../utils/constants.dart';
import '../widgets/bond_action_sheet.dart';

Future<void> showAddToWishlistFlow(
  BuildContext context, {
  required List<String> isins,
  VoidCallback? onSuccess,
}) async {
  final wp = context.read<WishlistProvider>();
  final api = context.read<ApiService>();
  if (wp.wishlists.isEmpty) await wp.load();
  if (!context.mounted) return;

  await showAddToWishlistSheet(
    context,
    wishlists: wp.wishlists,
    alreadyIn: {},
    requiredCapacity: isins.length,
    onAdd: (wishlistId) async {
      try {
        if (isins.length > 1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Adding bonds...'), duration: Duration(seconds: 1)),
          );
        }
        await Future.wait(
          isins.map((isin) => api.addBond(wishlistId, isin)),
        );
        await wp.load();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Bonds successfully added to wishlist!'),
              backgroundColor: AppColors.green,
            ),
          );
          onSuccess?.call();
        }
      } catch (e) {
        if (context.mounted) {
          String errorMsg = e.toString();
          if (errorMsg.contains('409')) {
            errorMsg = isins.length > 1
                ? 'One or more bonds are already in this wishlist.'
                : 'Bond is already in this wishlist.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMsg), backgroundColor: AppColors.red),
          );
        }
      }
    },
  );
}
