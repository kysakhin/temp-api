// widgets/bond_tile.dart

import 'package:flutter/material.dart';
import '../models/bond.dart';
import '../utils/constants.dart';

class BondTile extends StatelessWidget {
  final Bond bond;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool showDragHandle;
  final String sortBy;
  final int? reorderIndex;
  final bool isMultiSelectMode;
  final bool isSelected;
  final VoidCallback? onToggleSelection;

  const BondTile({
    super.key,
    required this.bond,
    required this.onTap,
    required this.onLongPress,
    this.showDragHandle = false,
    this.sortBy = 'bondYield',
    this.reorderIndex,
    this.isMultiSelectMode = false,
    this.isSelected = false,
    this.onToggleSelection,
  });

  Color? get _tagColor {
    if (bond.color == null) return null;
    final hex = bond.color!.replaceAll('#', '');
    if (hex.length != 6) return null;
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final tag = _tagColor;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.navyDeep.withOpacity(0.06) : null,
          border: const Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            if (isMultiSelectMode)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? AppColors.navyDeep : AppColors.muted,
                  size: 24,
                ),
              ),
            if (tag != null)
              Container(
                width: 4,
                height: 40,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: tag,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            _Logo(url: bond.logoUrl, fallback: bond.bondName),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (bond.isPinned) ...[
                        const Icon(Icons.push_pin, size: 14, color: AppColors.gold),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          bond.bondName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.navyDeep,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${bond.isin}${bond.rating != null ? ' • ${bond.rating}' : ''}',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildTrailingMetric(),
                const SizedBox(height: 3),
                Text(
                  bond.tenureLabel,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
              ],
            ),
            // The drag handle explicitly binds to ReorderableListView via ReorderableDragStartListener
            if (showDragHandle && reorderIndex != null) ...[
              const SizedBox(width: 6),
              ReorderableDragStartListener(
                index: reorderIndex!,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Icon(Icons.drag_handle, color: AppColors.muted, size: 26),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTrailingMetric() {
    if (sortBy == 'minInvestment') {
      final minInv = bond.minInvestment;
      String display = '—';
      if (minInv != null) {
        // Format with commas, e.g. 10000 -> 10,000
        display = minInv.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},');
      }
      return Text(
        display,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.navyDeep, 
        ),
      );
    } else {
      final yield_ = bond.bondYield;
      String displayYield = '—';
      
      if (yield_ != null) {
        // Use the exact string representation from the double parsed from DB
        displayYield = yield_.toString();
        // Clean up trailing '.0' if it is a whole number like '15.0'
        if (displayYield.endsWith('.0')) {
          displayYield = displayYield.substring(0, displayYield.length - 2);
        }
        displayYield += '%';
      }
      
      return Text(
        displayYield,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.green,
        ),
      );
    }
  }
}

class _Logo extends StatelessWidget {
  final String? url;
  final String fallback;
  const _Logo({required this.url, required this.fallback});

  @override
  Widget build(BuildContext context) {
    const size = 38.0;
    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.network(
          url!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _initials(),
        ),
      );
    }
    return _initials();
  }

  Widget _initials() {
    final initial = fallback.isNotEmpty ? fallback[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy),
      ),
    );
  }

  static const size = 38.0;
}