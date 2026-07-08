import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bond.dart';
import '../models/wishlist.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/deep_link.dart';
import '../widgets/bond_tile.dart';
import '../widgets/bond_action_sheet.dart';
import '../widgets/color_picker_sheet.dart';

class WishlistDetailScreen extends StatefulWidget {
  final String wishlistId;
  
  const WishlistDetailScreen({
    super.key, 
    required this.wishlistId
  });

  @override
  State<WishlistDetailScreen> createState() => _WishlistDetailScreenState();
}

class _WishlistDetailScreenState extends State<WishlistDetailScreen> {
  WishlistDetails? _wishlist;
  bool _loading = true;
  String? _error;
  String _sortBy = 'addedRecently';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<ApiService>();
      final data = await api.getWishlist(widget.wishlistId, sortBy: _sortBy);
      setState(() { _wishlist = data; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _loading = false; });
    }
  }

  Future<void> _setSort(String sort) async {
    if (_sortBy == sort) return;
    setState(() { _sortBy = sort; });
    await _load();
  }

  void _onReorder(int oldIndex, int newIndex) async {
    
    if (oldIndex < newIndex) newIndex -= 1;
    
    // Optimistically update the UI
    setState(() {
      final item = _wishlist!.bonds.removeAt(oldIndex);
      _wishlist!.bonds.insert(newIndex, item);
      _sortBy = 'manual'; // Auto switch to manual mode on drag
    });

    final isins = _wishlist!.bonds.map((b) => b.isin).toList();
    try {
      await context.read<ApiService>().reorderBonds(widget.wishlistId, isins);
    } catch (e) {
      _showError('Failed to save order: ${e.toString()}');
      _load(); // roll back changes if backend fail
    }
  }

  Future<void> _handleLongPress(Bond bond) async {
    final action = await showBondActionSheet(
      context, 
      bond: bond, 
      inWishlistContext: true
    );
    
    if (!mounted || action == null) return;

    final api = context.read<ApiService>();

    switch (action) {
      case BondAction.openApp:
        await openBondInApp(bond.isin, webFallback: bond.detailUrl);
        break;
      case BondAction.togglePin:
        try {
          await api.setBondPinned(widget.wishlistId, bond.isin, !bond.isPinned);
          await _load();
        } catch (e) {
          _showError(e.toString());
        }
        break;
      case BondAction.setColor:
        final hex = await showColorPickerSheet(context, current: bond.color);
        try {
          await api.updateWishlistBondColor(widget.wishlistId, bond.isin, hex);
          await _load(); 
        } catch (e) {
          _showError(e.toString());
        }
        break;
      case BondAction.removeFromWishlist:
        try {
          await api.removeBond(widget.wishlistId, bond.isin);
          await _load();
        } catch (e) {
          _showError(e.toString());
        }
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
        title: Text(
          _wishlist?.name ?? 'Wishlist', 
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5)
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _wishlist == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.navyDeep));
    }
    
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: AppColors.red)));
    }
    
    if (_wishlist!.bonds.isEmpty) {
      return const Center(
        child: Text('No bonds in this wishlist', style: TextStyle(color: AppColors.muted))
      );
    }
    
    return Column(
      children: [
        // Sorting Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          alignment: Alignment.centerRight,
          child: PopupMenuButton<String>(
            initialValue: _sortBy,
            onSelected: _setSort,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'addedRecently', child: Text('Sort by Added Recently')),
              PopupMenuItem(value: 'color', child: Text('Sort by Color')),
              PopupMenuItem(value: 'manual', child: Text('Manual Order')),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort, size: 16, color: AppColors.navyDeep),
                const SizedBox(width: 6),
                Text(
                  _sortBy == 'color' ? 'Color' : (_sortBy == 'manual' ? 'Manual Order' : 'Added Recently'),
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
        // bonds list with drag drop
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              onReorder: _onReorder,
              
              padding: const EdgeInsets.only(bottom: 60), 
              itemCount: _wishlist!.bonds.length,
              itemBuilder: (context, i) {
                final bond = _wishlist!.bonds[i];
                return BondTile(
                  key: ValueKey(bond.isin),
                  bond: bond,
                  showDragHandle: true,
                  reorderIndex: i, // this index can be dragged
                  onTap: () => openBondInApp(bond.isin, webFallback: bond.detailUrl),
                  onLongPress: () => _handleLongPress(bond),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}