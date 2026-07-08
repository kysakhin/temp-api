import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/bond.dart';
import '../models/wishlist.dart';
import '../services/api_service.dart';
import '../services/wishlist_provider.dart';
import '../utils/constants.dart';
import '../utils/deep_link.dart';
import '../widgets/bond_action_sheet.dart';
import '../widgets/color_picker_sheet.dart';
import 'widgets/wishlist_tabs.dart';
import 'widgets/wishlist_sort_row.dart';
import 'widgets/wishlist_bond_list.dart';
import 'widgets/wishlist_dialogs.dart';

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
        sortOrder: _sortOrder,
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
    final name = await promptWishlistName(context, title: 'New wishlist');
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
    final name = await promptWishlistName(context, title: 'Rename wishlist', initial: w.name);
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
    final confirmed = await confirmDeleteWishlist(context, w.name);
    if (!confirmed) return;

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

  Future<void> _handleLongPress(Bond bond) async {
    final action = await showBondActionSheet(context, bond: bond, inWishlistContext: true);
    if (!mounted || action == null) return;

    switch (action) {
      case BondAction.openApp:
        await openBondInApp(bond.isin, webFallback: bond.detailUrl);
        break;
      case BondAction.togglePin:
        try {
          await context.read<ApiService>().setBondPinned(_activeId!, bond.isin, !bond.isPinned);
          await _loadDetails();
        } catch (e) {
          _snack(e.toString());
        }
        break;
      case BondAction.setColor:
        final hex = await showColorPickerSheet(context, current: bond.color);
        if (!mounted) return;
        if (hex != null) {
          try {
            await context.read<ApiService>().updateWishlistBondColor(_activeId!, bond.isin, hex);
            await _loadDetails();
          } catch (e) {
            _snack(e.toString());
          }
        }
        break;
      case BondAction.selectMultiple:
        _enterMultiSelect(bond.isin);
        break;
      case BondAction.removeFromWishlist:
        try {
          await context.read<ApiService>().removeBond(_activeId!, bond.isin);
          await context.read<WishlistProvider>().load();
          await _loadDetails();
        } catch (e) {
          _snack(e.toString());
        }
        break;
      default:
        break;
    }
  }

  Future<void> _pinSelected() async {
    if (_selectedIsins.isEmpty || _activeId == null) return;
    setState(() => _loadingDetails = true);
    try {
      await Future.wait(
        _selectedIsins.map((isin) => context.read<ApiService>().setBondPinned(_activeId!, isin, true)),
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
        _selectedIsins.map((isin) => context.read<ApiService>().removeBond(_activeId!, isin)),
      );
      setState(() {
        _isMultiSelect = false;
        _selectedIsins.clear();
      });
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
        _selectedIsins.map((isin) => context.read<ApiService>().updateWishlistBondColor(_activeId!, isin, hex)),
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
                icon: const Icon(Icons.push_pin_outlined),
                onPressed: _selectedIsins.isEmpty ? null : _pinSelected,
              ),
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
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5),
            ),
            elevation: 0,
            scrolledUnderElevation: 0,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 28),
                  onPressed: _create,
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
              WishlistTabs(
                wishlists: prov.sorted,
                activeId: _activeId,
                onTabSelected: _setActive,
                scrollController: _tabsScrollController,
              ),
              if (activeW != null)
                WishlistSortRow(
                  sortBy: _sortBy,
                  sortOrder: _sortOrder,
                  onSortTap: _showSortDialog,
                  onSortOrderToggle: () {
                    setState(() => _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc');
                    if (_activeId != null) {
                      context.read<WishlistProvider>().setSortOrderPref(_activeId!, _sortOrder);
                    }
                    _loadDetails();
                  },
                  onRename: () => _rename(activeW),
                  onDelete: () => _delete(activeW),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: WishlistBondList(
                    loadingDetails: _loadingDetails,
                    details: _details,
                    sortBy: _sortBy,
                    isMultiSelect: _isMultiSelect,
                    selectedIsins: _selectedIsins,
                    onBondTap: (isin) => openBondInApp(isin, webFallback: _details?.bonds.firstWhere((b) => b.isin == isin).detailUrl),
                    onBondLongPress: _handleLongPress,
                    onToggleSelection: _toggleSelection,
                    onReorder: _onReorder,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
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
