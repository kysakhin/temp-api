//screens/bonds_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bond.dart';
import '../services/api_service.dart';
import '../services/bonds_provider.dart';
import '../services/wishlist_provider.dart';
import '../utils/constants.dart';
import '../utils/deep_link.dart';
import '../widgets/bond_tile.dart';
import '../widgets/bond_action_sheet.dart';
import '../widgets/color_picker_sheet.dart';

class BondsScreen extends StatefulWidget {
  const BondsScreen({super.key});
  @override
  State<BondsScreen> createState() => _BondsScreenState();
}

class _BondsScreenState extends State<BondsScreen> {
  bool _isMultiSelect = false;
  final Set<String> _selectedIsins = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BondsProvider>().loadInitial();
    });
  }

  Future<void> _handleLongPress(Bond bond) async {
    final action = await showBondActionSheet(context, bond: bond);
    if (!mounted || action == null) return;

    switch (action) {
      case BondAction.openApp:
        await openBondInApp(bond.isin, webFallback: bond.detailUrl);
        break;
      case BondAction.selectMultiple:
        setState(() {
          _isMultiSelect = true;
          _selectedIsins.add(bond.isin);
        });
        break;
      case BondAction.addToWishlist:
        final wp = context.read<WishlistProvider>();
        if (wp.wishlists.isEmpty) await wp.load();
        if (!mounted) return;
        await showAddToWishlistSheet(
          context,
          wishlists: wp.wishlists,
          alreadyIn: {},
          onAdd: (wishlistId) async {
            try {
              await context.read<ApiService>().addBond(wishlistId, bond.isin);
              await wp.load();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bond successfully added to wishlist!'),
                    backgroundColor: AppColors.green,
                  ),
                );
              }
            } catch (e) {
              String errorMsg = e.toString();
              if (errorMsg.contains('409')) {
                errorMsg = 'Bond is already in this wishlist.';
              }
              _showError(errorMsg);
            }
          },
        );
        break;
      default:
        break;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.red));
  }

  void _toggleSelection(String isin) {
    setState(() {
      if (_selectedIsins.contains(isin)) {
        _selectedIsins.remove(isin);
      } else {
        _selectedIsins.add(isin);
      }
    });
  }

  Future<void> _addMultipleToWishlist() async {
    final wp = context.read<WishlistProvider>();
    if (wp.wishlists.isEmpty) await wp.load();
    if (!mounted) return;
    
    await showAddToWishlistSheet(
      context,
      wishlists: wp.wishlists,
      alreadyIn: {}, 
      requiredCapacity: _selectedIsins.length,
      onAdd: (wishlistId) async {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Adding bonds...'), duration: Duration(seconds: 1)),
          );
          // Fires off concurrent requests to add all selected bonds rapidly
          await Future.wait(
            _selectedIsins.map((isin) => context.read<ApiService>().addBond(wishlistId, isin))
          );
          await wp.load();
          if (mounted) {
            setState(() {
              _isMultiSelect = false;
              _selectedIsins.clear();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bonds successfully added to wishlist!'),
                backgroundColor: AppColors.green,
              ),
            );
          }
        } catch (e) {
          String errorMsg = e.toString();
          if (errorMsg.contains('409')) {
            errorMsg = 'One or more bonds are already in this wishlist.';
          }
          _showError(errorMsg);
        }
      },
    );
  }

  String _getSortLabel(String s) {
    switch (s) {
      case 'bondYield': return 'Yield';
      case 'minInvestment': return 'Min. Investment';
      case 'tenure': return 'Tenure';
      case 'rating': return 'Rating';
      case 'isin': return 'ISIN';
      default: return 'Sort';
    }
  }

  void _showSortDialog(BondsProvider prov) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sort bonds by'),
        contentPadding: const EdgeInsets.only(top: 12, bottom: 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sortOption(ctx, prov, 'bondYield', 'Yield'),
            _sortOption(ctx, prov, 'minInvestment', 'Min. Investment'),
            _sortOption(ctx, prov, 'tenure', 'Tenure'),
            _sortOption(ctx, prov, 'rating', 'Rating'),
            _sortOption(ctx, prov, 'isin', 'ISIN'),
          ],
        ),
      ),
    );
  }

  Widget _sortOption(BuildContext ctx, BondsProvider prov, String value, String label) {
    final isSelected = prov.sortBy == value;
    return ListTile(
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      trailing: isSelected ? const Icon(Icons.check, color: AppColors.navyDeep) : null,
      onTap: () {
        Navigator.pop(ctx);
        prov.setSort(value);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: _isMultiSelect
        ? AppBar(
            backgroundColor: AppColors.navyDeep,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _isMultiSelect = false;
                _selectedIsins.clear();
              }),
            ),
            title: Text('${_selectedIsins.length} Selected', style: const TextStyle(fontWeight: FontWeight.w700)),
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.playlist_add),
                onPressed: _selectedIsins.isEmpty ? null : _addMultipleToWishlist,
              ),
            ],
          )
        : AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.navyDeep,
            title: const Text(
              'Available bonds', 
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5)
            ),
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
      body: Consumer<BondsProvider>(
        builder: (context, prov, _) {
          return Column(
            children: [
              // Sort Options Row
              Container(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => _showSortDialog(prov),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        child: Row(
                          children: [
                            const Icon(Icons.sort, size: 18, color: AppColors.navyDeep),
                            const SizedBox(width: 6),
                            Text(
                              _getSortLabel(prov.sortBy),
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
                    // Ascending/Descending Toggle Arrow
                    IconButton(
                      icon: Icon(
                        prov.sortOrder == 'asc' ? Icons.arrow_upward : Icons.arrow_downward, 
                        size: 20, 
                        color: AppColors.navyDeep
                      ),
                      onPressed: prov.toggleSortOrder,
                    ),
                  ],
                ),
              ),
              
              // Bonds List
              Expanded(
                child: _buildList(prov),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(BondsProvider prov) {
    // Default Catalog List
    if (prov.loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.navyDeep));
    }
    if (prov.error != null && prov.bonds.isEmpty) {
      return Center(child: Text(prov.error!, style: const TextStyle(color: AppColors.red)));
    }
    return RefreshIndicator(
      onRefresh: prov.loadInitial,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 120),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: prov.bonds.length,
        itemBuilder: (context, i) {
          final bond = prov.bonds[i];
          return BondTile(
            bond: bond,
            sortBy: prov.displayMetric, 
            isMultiSelectMode: _isMultiSelect,
            isSelected: _selectedIsins.contains(bond.isin),
            onToggleSelection: () => _toggleSelection(bond.isin),
            onTap: () {
              if (_isMultiSelect) {
                _toggleSelection(bond.isin);
              } else {
                openBondInApp(bond.isin, webFallback: bond.detailUrl);
              }
            },
            onLongPress: () {
              if (!_isMultiSelect) _handleLongPress(bond);
            },
          );
        },
      ),
    );
  }
}