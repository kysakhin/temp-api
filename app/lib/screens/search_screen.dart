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
//import '../widgets/color_picker_sheet.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the search bar when the screen is navigated to
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLongPress(Bond bond) async {
    final action = await showBondActionSheet(context, bond: bond);
    if (!mounted || action == null) return;

    switch (action) {
      case BondAction.openApp:
        await openBondInApp(bond.isin, webFallback: bond.detailUrl);
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
              _showError(e.toString());
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.navyDeep,
        title: const Text(
          'Search', 
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5)
        ),
        elevation: 0,
        scrolledUnderElevation: 0, 
      ),
      body: Consumer<BondsProvider>(
        builder: (context, prov, _) {
          return Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: (val) => prov.search(val),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Search ISIN or bond name...',
                    hintStyle: const TextStyle(color: AppColors.muted, fontWeight: FontWeight.normal),
                    prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.divider, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.divider, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: AppColors.navyDeep, width: 1.5),
                    ),
                  ),
                ),
              ),
              
              // Display Toggle Header (Shares the same state as Bonds Screen)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    final nextMetric = prov.displayMetric == 'bondYield' 
                        ? 'minInvestment' 
                        : 'bondYield';
                    prov.setDisplayMetric(nextMetric);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync_alt, size: 16, color: AppColors.navyDeep),
                      const SizedBox(width: 6),
                      Text(
                        prov.displayMetric == 'bondYield' ? 'Interest' : 'Min. Investment',
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
              const SizedBox(height: 8),
              
              // Search Results List
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
    if (prov.searchLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.navyDeep));
    }
    if (prov.searchQuery.trim().isEmpty) {
      return const Center(
        child: Text('Type an ISIN or bond name to search', style: TextStyle(color: AppColors.muted))
      );
    }
    if (prov.searchResults.isEmpty) {
      return const Center(
        child: Text('No bonds found matching your search.', style: TextStyle(color: AppColors.muted))
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: prov.searchResults.length,
      itemBuilder: (context, i) {
        final bond = prov.searchResults[i];
        return BondTile(
          bond: bond,
          sortBy: prov.displayMetric, 
          onTap: () => openBondInApp(bond.isin, webFallback: bond.detailUrl),
          onLongPress: () => _handleLongPress(bond),
        );
      },
    );
  }
}