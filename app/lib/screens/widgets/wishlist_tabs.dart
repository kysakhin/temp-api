import 'package:flutter/material.dart';
import '../../models/wishlist.dart';
import '../../utils/constants.dart';

class WishlistTabs extends StatelessWidget {
  final List<Wishlist> wishlists;
  final String? activeId;
  final ValueChanged<String> onTabSelected;
  final ScrollController scrollController;

  const WishlistTabs({
    super.key,
    required this.wishlists,
    required this.activeId,
    required this.onTabSelected,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        controller: scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: wishlists.length,
        itemBuilder: (context, i) {
          final w = wishlists[i];
          final isActive = w.id == activeId;
          return GestureDetector(
            onTap: () => onTabSelected(w.id),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? AppColors.navyDeep : Colors.transparent,
                border: Border.all(
                  color: isActive ? AppColors.navyDeep : AppColors.divider,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(
                  w.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? Colors.white : AppColors.navyDeep,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
