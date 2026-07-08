import 'package:flutter/material.dart';
import '../../models/bond.dart';
import '../../models/wishlist.dart';
import '../../utils/constants.dart';
import '../../widgets/bond_tile.dart';

class WishlistBondList extends StatelessWidget {
  final bool loadingDetails;
  final WishlistDetails? details;
  final String sortBy;
  final bool isMultiSelect;
  final Set<String> selectedIsins;
  final void Function(String isin) onBondTap;
  final void Function(Bond bond) onBondLongPress;
  final void Function(String isin) onToggleSelection;
  final void Function(int oldIndex, int newIndex) onReorder;

  const WishlistBondList({
    super.key,
    required this.loadingDetails,
    required this.details,
    required this.sortBy,
    required this.isMultiSelect,
    required this.selectedIsins,
    required this.onBondTap,
    required this.onBondLongPress,
    required this.onToggleSelection,
    required this.onReorder,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingDetails) {
      return const Center(child: CircularProgressIndicator(color: AppColors.navyDeep));
    }
    if (details == null || details!.bonds.isEmpty) {
      return const Center(
        child: Text('No bonds in this wishlist', style: TextStyle(color: AppColors.muted)),
      );
    }

    if (sortBy == 'manual' && !isMultiSelect) {
      return ReorderableListView.builder(
        buildDefaultDragHandles: false,
        onReorder: onReorder,
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: details!.bonds.length,
        itemBuilder: (context, i) {
          final bond = details!.bonds[i];
          return BondTile(
            key: ValueKey(bond.isin),
            bond: bond,
            showDragHandle: true,
            reorderIndex: i,
            sortBy: sortBy,
            isMultiSelectMode: false,
            isSelected: false,
            onTap: () => onBondTap(bond.isin),
            onLongPress: () => onBondLongPress(bond),
          );
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: details!.bonds.length,
      itemBuilder: (context, i) {
        final bond = details!.bonds[i];
        return BondTile(
          key: ValueKey(bond.isin),
          bond: bond,
          showDragHandle: false,
          sortBy: sortBy,
          isMultiSelectMode: isMultiSelect,
          isSelected: selectedIsins.contains(bond.isin),
          onToggleSelection: () => onToggleSelection(bond.isin),
          onTap: () {
            if (isMultiSelect) {
              onToggleSelection(bond.isin);
            } else {
              onBondTap(bond.isin);
            }
          },
          onLongPress: () {
            if (!isMultiSelect) onBondLongPress(bond);
          },
        );
      },
    );
  }
}
