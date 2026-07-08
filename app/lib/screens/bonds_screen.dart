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

class BondsScreen extends StatefulWidget {
  const BondsScreen({super.key});
  @override
  State<BondsScreen> createState() => _BondsScreenState();
}

class _BondsScreenState extends State<BondsScreen> {
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
              // Display Toggle Header
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
    if (prov.bonds.isEmpty && prov.loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.navyDeep));
    }
    if (prov.error != null && prov.bonds.isEmpty) {
      return Center(child: Text(prov.error!, style: const TextStyle(color: AppColors.red)));
    }
    return RefreshIndicator(
      onRefresh: prov.loadInitial,
      child: ListView.builder(
        // Added bottom padding so the glass nav bar doesn't block the last item
        padding: const EdgeInsets.only(bottom: 120),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: prov.bonds.length,
        itemBuilder: (context, i) {
          final bond = prov.bonds[i];
          return BondTile(
            bond: bond,
            sortBy: prov.displayMetric, 
            onTap: () => openBondInApp(bond.isin, webFallback: bond.detailUrl),
            onLongPress: () => _handleLongPress(bond),
          );
        },
      ),
    );
  }
}