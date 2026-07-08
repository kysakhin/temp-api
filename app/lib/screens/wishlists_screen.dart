//screens/wishlists_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bond.dart';
import '../models/wishlist.dart';
import '../services/api_service.dart';
import '../services/wishlist_provider.dart';
import '../utils/constants.dart';
import '../utils/deep_link.dart';
import '../widgets/bond_tile.dart';
import '../widgets/bond_action_sheet.dart';
import '../widgets/color_picker_sheet.dart';

class WishlistsScreen extends StatefulWidget {
  const WishlistsScreen({super.key});
  @override
  State<WishlistsScreen> createState() => _WishlistsScreenState();
}

class _WishlistsScreenState extends State<WishlistsScreen> {
  String? _activeId;
  WishlistDetails? _details;
  bool _loadingDetails = false;
  String _sortBy = 'manual';
  String _sortOrder = 'desc';
  
  bool _isMultiSelect = false;
  final Set<String> _selectedIsins = {};
  int? _lastSeenBondCount;

  final ScrollController _tabsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLoad();
    });
  }

  @override
  void dispose() {
    _tabsScrollController.dispose();
    super.dispose();
  }

  Future<void> _initLoad() async {
    final prov = context.read<WishlistProvider>();
    await prov.load();
    if (prov.wishlists.isNotEmpty) {
      _setActive(prov.wishlists.first.id);
    }
  }

  Future<void> _setActive(String id) async {
    if (!mounted) return;
    final prov = context.read<WishlistProvider>();
    
    setState(() {
      _activeId = id;
      _isMultiSelect = false;
      _selectedIsins.clear();
      _sortBy = prov.getSortPref(id);
      _sortOrder = prov.getSortOrderPref(id);
      _lastSeenBondCount = null;
    });
    
    final index = prov.sorted.indexWhere((w) => w.id == id);
    if (index != -1 && _tabsScrollController.hasClients) {
      final offset = index * 120.0;
      _tabsScrollController.animateTo(
        offset.clamp(0.0, _tabsScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    
    await _loadDetails();
  }

  Future<void> _loadDetails() async {
    if (_activeId == null) return;
    setState(() => _loadingDetails = true);
    try {
      final api = context.read<ApiService>();
      final data = await api.getWishlist(
        _activeId!, 
        sortBy: _sortBy, 
        sortOrder: _sortOrder
      );
      if (mounted) setState(() => _details = data);
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  Future<void> _refresh() async {
    await context.read<WishlistProvider>().load();
    await _loadDetails();
  }

  Future<void> _create() async {
    final prov = context.read<WishlistProvider>();
    if (prov.wishlists.length >= maxWishlists) {
      _snack('Maximum of $maxWishlists wishlists allowed.');
      return;
    }
    final name = await _promptName(context, title: 'New wishlist');
    if (name == null || name.trim().isEmpty) return;
    
    final ok = await prov.create(name.trim());
    if (ok && mounted) {
      _setActive(prov.wishlists.last.id);
    } else if (!ok && mounted) {
      String errorMsg = prov.error ?? 'Could not create wishlist.';
      if (errorMsg.contains('409')) {
        errorMsg = 'Wishlist with that name already exists.';
      }
      _snack(errorMsg);
    }
  }

  Future<void> _rename(Wishlist w) async {
    final name = await _promptName(context, title: 'Rename wishlist', initial: w.name);
    if (name == null || name.trim().isEmpty) return;
    try {
      await context.read<WishlistProvider>().rename(w.id, name.trim());
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('409')) {
        errorMsg = 'Wishlist with that name already exists.';
      }
      _snack(errorMsg);
    }
  }

  Future<void> _delete(Wishlist w) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete wishlist?'),
        content: Text('"${w.name}" and all its bonds will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: AppColors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        final prov = context.read<WishlistProvider>();
        await prov.remove(w.id);
        if (_activeId == w.id) {
          if (prov.wishlists.isNotEmpty) {
            _setActive(prov.wishlists.first.id);
          } else {
            setState(() {
              _activeId = null;
              _details = null;
            });
          }
        }
      } catch (e) {
        _snack(e.toString());
      }
    }
  }

  void _onReorder(int oldIndex, int newIndex) async {
    if (_activeId == null || _details == null) return;
    if (oldIndex < newIndex) newIndex -= 1;

    setState(() {
      final item = _details!.bonds.removeAt(oldIndex);
      _details!.bonds.insert(newIndex, item);
      _sortBy = 'manual';
      context.read<WishlistProvider>().setSortPref(_activeId!, 'manual');
    });

    final isins = _details!.bonds.map((b) => b.isin).toList();
    try {
      await context.read<ApiService>().reorderBonds(_activeId!, isins);
    } catch (e) {
      _snack('Failed to save order: ${e.toString()}');
      _loadDetails(); 
    }
  }

  void _enterMultiSelect(String isin) {
    setState(() {
      _isMultiSelect = true;
      _selectedIsins.add(isin);
    });
  }

  String _getSortLabel(String s) {
    switch (s) {
      case 'manual': return 'Manual Order';
      case 'addedRecently': return 'Added Recently';
      case 'color': return 'Color';
      case 'yield': return 'Yield';
      case 'minInvestment': return 'Min. Investment';
      case 'tenure': return 'Tenure';
      case 'rating': return 'Rating';
      default: return 'Sort';
    }
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sort wishlist by'),
        contentPadding: const EdgeInsets.only(top: 12, bottom: 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sortOption(ctx, 'manual', 'Manual Order'),
            _sortOption(ctx, 'addedRecently', 'Added Recently'),
            _sortOption(ctx, 'color', 'Color'),
            _sortOption(ctx, 'yield', 'Yield'),
            _sortOption(ctx, 'minInvestment', 'Min. Investment'),
            _sortOption(ctx, 'tenure', 'Tenure'),
            _sortOption(ctx, 'rating', 'Rating'),
          ],
        ),
      ),
    );
  }

  Widget _sortOption(BuildContext ctx, String value, String label) {
    final isSelected = _sortBy == value;
    return ListTile(
      title: Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500)),
      trailing: isSelected ? const Icon(Icons.check, color: AppColors.navyDeep) : null,
      onTap: () {
        Navigator.pop(ctx);
        if (_sortBy != value) {
          setState(() => _sortBy = value);
          if (_activeId != null) {
            context.read<WishlistProvider>().setSortPref(_activeId!, value);
          }
          _loadDetails();
        }
      },
    );
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

  Future<void> _deleteSelected() async {
    if (_selectedIsins.isEmpty || _activeId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected bonds?'),
        content: Text('This will remove ${_selectedIsins.length} bonds from the wishlist.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loadingDetails = true);
    try {
      await Future.wait(
        _selectedIsins.map((isin) => context.read<ApiService>().removeBond(_activeId!, isin))
      );
      setState(() {
        _isMultiSelect = false;
        _selectedIsins.clear();
      });
      // refresh wishlist list too, bondCount was stale otherwise -> false "Full" bug
      await context.read<WishlistProvider>().load();
      await _loadDetails();
    } catch (e) {
      _snack(e.toString());
      setState(() => _loadingDetails = false);
    }
  }

  Future<void> _colorSelected() async {
    if (_selectedIsins.isEmpty || _activeId == null) return;
    final hex = await showColorPickerSheet(context);
    setState(() => _loadingDetails = true);
    try {
      await Future.wait(
        _selectedIsins.map((isin) => context.read<ApiService>().updateWishlistBondColor(_activeId!, isin, hex))
      );
      setState(() {
        _isMultiSelect = false;
        _selectedIsins.clear();
      });
      await _loadDetails();
    } catch (e) {
      _snack(e.toString());
      setState(() => _loadingDetails = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.red));
  }

  Future<String?> _promptName(BuildContext context,
      {required String title, String? initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: const InputDecoration(hintText: 'Wishlist name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Save')),
        ],
      ),
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
                icon: const Icon(Icons.palette_outlined),
                onPressed: _selectedIsins.isEmpty ? null : _colorSelected,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _selectedIsins.isEmpty ? null : _deleteSelected,
              ),
            ],
          )
        : AppBar(
            backgroundColor: Colors.transparent,
            foregroundColor: AppColors.navyDeep,
            title: const Text(
              'Wishlists', 
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5)
            ),
            elevation: 0,
            scrolledUnderElevation: 0, 
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 28), 
                  onPressed: _create
                ),
              ),
            ],
          ),
      body: Consumer<WishlistProvider>(
        builder: (context, prov, _) {
          if (prov.loading && prov.wishlists.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: AppColors.navyDeep));
          }

          if (prov.error != null && prov.wishlists.isEmpty) {
            return _buildErrorState(prov);
          }

          if (prov.wishlists.isEmpty) {
            return _buildEmptyState();
          }

          final activeW = prov.wishlists.where((w) => w.id == _activeId).firstOrNull;
          if (activeW == null && _activeId == null) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
               if (mounted && prov.wishlists.isNotEmpty) {
                 _setActive(prov.wishlists.first.id);
               }
             });
          }

          // provider's bondCount changed elsewhere (e.g. bonds added from
          // bonds_screen) but our cached _details is stale -> reload
          if (activeW != null &&
              !_loadingDetails &&
              _details != null &&
              activeW.bondCount != _details!.bonds.length &&
              _lastSeenBondCount != activeW.bondCount) {
            _lastSeenBondCount = activeW.bondCount;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadDetails();
            });
          }

          return Column(
            children: [
              _buildTabs(prov),
              if (activeW != null) _buildSortOptionsRow(activeW),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: _buildBondsList(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabs(WishlistProvider prov) {
    return SizedBox(
      height: 48,
      child: ListView.builder(
        controller: _tabsScrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: prov.sorted.length,
        itemBuilder: (context, i) {
          final w = prov.sorted[i];
          final isActive = w.id == _activeId;
          return GestureDetector(
            onTap: () => _setActive(w.id),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isActive ? AppColors.navyDeep : Colors.transparent,
                border: Border.all(color: isActive ? AppColors.navyDeep : AppColors.divider),
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

  Widget _buildSortOptionsRow(Wishlist activeW) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _showSortDialog,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.sort, size: 18, color: AppColors.navyDeep),
                  const SizedBox(width: 6),
                  Text(
                    _getSortLabel(_sortBy),
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
              _sortOrder == 'asc' ? Icons.arrow_upward : Icons.arrow_downward, 
              size: 20, 
              color: AppColors.navyDeep
            ),
            onPressed: () {
              setState(() => _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc');
              if (_activeId != null) {
                context.read<WishlistProvider>().setSortOrderPref(_activeId!, _sortOrder);
              }
              _loadDetails();
            },
          ),
          const Spacer(),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: AppColors.muted),
            onSelected: (v) {
              if (v == 'rename') _rename(activeW);
              if (v == 'delete') _delete(activeW);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'rename', child: Text('Rename List')),
              PopupMenuItem(value: 'delete', child: Text('Delete List', style: TextStyle(color: AppColors.red))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBondsList() {
    if (_loadingDetails) {
      return const Center(child: CircularProgressIndicator(color: AppColors.navyDeep));
    }
    if (_details == null || _details!.bonds.isEmpty) {
      return const Center(
        child: Text('No bonds in this wishlist', style: TextStyle(color: AppColors.muted))
      );
    }

    if (_sortBy == 'manual' && !_isMultiSelect) {
      return ReorderableListView.builder(
        buildDefaultDragHandles: false,
        onReorder: _onReorder,
        padding: const EdgeInsets.only(bottom: 120),
        itemCount: _details!.bonds.length,
        itemBuilder: (context, i) {
          final bond = _details!.bonds[i];
          return BondTile(
            key: ValueKey(bond.isin),
            bond: bond,
            showDragHandle: true,
            reorderIndex: i, 
            sortBy: _sortBy,
            isMultiSelectMode: false,
            isSelected: false,
            onTap: () => openBondInApp(bond.isin, webFallback: bond.detailUrl),
            onLongPress: () => _enterMultiSelect(bond.isin),
          );
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: 120),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _details!.bonds.length,
        itemBuilder: (context, i) {
          final bond = _details!.bonds[i];
          return BondTile(
            key: ValueKey(bond.isin),
            bond: bond,
            showDragHandle: false,
            sortBy: _sortBy,
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
              if (!_isMultiSelect) _enterMultiSelect(bond.isin);
            },
          );
        },
      );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bookmark_border, size: 48, color: AppColors.muted),
          const SizedBox(height: 12),
          const Text('No wishlists yet', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _create,
            style: FilledButton.styleFrom(backgroundColor: AppColors.navyDeep),
            child: const Text('Create wishlist'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(WishlistProvider prov) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.red),
            const SizedBox(height: 16),
            Text(
              'Failed to load:\n${prov.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.red),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: prov.load,
              style: FilledButton.styleFrom(backgroundColor: AppColors.navyDeep),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}