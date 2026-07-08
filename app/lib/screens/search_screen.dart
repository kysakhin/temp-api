import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bond.dart';
import '../services/bonds_provider.dart';
import '../services/search_provider.dart';
import '../utils/add_to_wishlist.dart';
import '../utils/constants.dart';
import '../utils/deep_link.dart';
import '../widgets/bond_tile.dart';
import '../widgets/bond_action_sheet.dart';

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
        if (!mounted) return;
        await showAddToWishlistFlow(context, isins: [bond.isin]);
        break;
      default:
        break;
    }
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
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Consumer2<BondsProvider, SearchProvider>(
        builder: (context, bondsProv, searchProv, _) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: (val) => searchProv.search(val),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    final nextMetric = bondsProv.displayMetric == 'bondYield'
                        ? 'minInvestment'
                        : 'bondYield';
                    bondsProv.setDisplayMetric(nextMetric);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.sync_alt, size: 16, color: AppColors.navyDeep),
                      const SizedBox(width: 6),
                      Text(
                        bondsProv.displayMetric == 'bondYield' ? 'Interest' : 'Min. Investment',
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
              Expanded(
                child: _buildList(searchProv, bondsProv.displayMetric),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(SearchProvider prov, String displayMetric) {
    if (prov.searchLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.navyDeep));
    }
    if (prov.searchQuery.trim().isEmpty) {
      return const Center(
        child: Text('Type an ISIN or bond name to search', style: TextStyle(color: AppColors.muted)),
      );
    }
    if (prov.searchResults.isEmpty) {
      return const Center(
        child: Text('No bonds found matching your search.', style: TextStyle(color: AppColors.muted)),
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
          sortBy: displayMetric,
          onTap: () => openBondInApp(bond.isin, webFallback: bond.detailUrl),
          onLongPress: () => _handleLongPress(bond),
        );
      },
    );
  }
}
