import 'package:flutter/material.dart';
import '../../utils/constants.dart';

class WishlistSortRow extends StatelessWidget {
  final String sortBy;
  final String sortOrder;
  final VoidCallback onSortTap;
  final VoidCallback onSortOrderToggle;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const WishlistSortRow({
    super.key,
    required this.sortBy,
    required this.sortOrder,
    required this.onSortTap,
    required this.onSortOrderToggle,
    required this.onRename,
    required this.onDelete,
  });

  String _getSortLabel(String s) {
    switch (s) {
      case 'manual':
        return 'Manual Order';
      case 'addedRecently':
        return 'Added Recently';
      case 'color':
        return 'Color';
      case 'yield':
        return 'Yield';
      case 'minInvestment':
        return 'Min. Investment';
      case 'tenure':
        return 'Tenure';
      case 'rating':
        return 'Rating';
      default:
        return 'Sort';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onSortTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.sort, size: 18, color: AppColors.navyDeep),
                  const SizedBox(width: 6),
                  Text(
                    _getSortLabel(sortBy),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navyDeep,
                      decoration: TextDecoration.underline,
                      decorationStyle: TextDecorationStyle.dotted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              sortOrder == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
              size: 20,
              color: AppColors.navyDeep,
            ),
            onPressed: onSortOrderToggle,
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: AppColors.muted),
            onSelected: (v) {
              if (v == 'rename') onRename();
              if (v == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename List')),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete List', style: TextStyle(color: AppColors.red)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
