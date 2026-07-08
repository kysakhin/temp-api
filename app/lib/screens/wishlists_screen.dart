import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/wishlist.dart';
import '../services/wishlist_provider.dart';
import '../utils/constants.dart';
import 'wishlist_detail_screen.dart';

class WishlistsScreen extends StatefulWidget {
  const WishlistsScreen({super.key});
  @override
  State<WishlistsScreen> createState() => _WishlistsScreenState();
}

class _WishlistsScreenState extends State<WishlistsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WishlistProvider>().load();
    });
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
    if (!ok && mounted) _snack(prov.error ?? 'Could not create wishlist.');
  }

  Future<void> _rename(Wishlist w) async {
    final name = await _promptName(context, title: 'Rename wishlist', initial: w.name);
    if (name == null || name.trim().isEmpty) return;
    try {
      await context.read<WishlistProvider>().rename(w.id, name.trim());
    } catch (e) {
      _snack(e.toString());
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
        await context.read<WishlistProvider>().remove(w.id);
      } catch (e) {
        _snack(e.toString());
      }
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
      appBar: AppBar(
        
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

          final list = prov.sorted;
          if (list.isEmpty) {
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

          return RefreshIndicator(
            onRefresh: prov.load,
            child: ListView.separated(
              // added bottom padding so the glass nav bar doesnt block the last item
              padding: const EdgeInsets.only(top: 8, bottom: 120),
              itemCount: list.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, i) {
                final w = list[i];
                return ListTile(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => WishlistDetailScreen(wishlistId: w.id)),
                  ),
                  leading: const Icon(Icons.folder_outlined, color: AppColors.muted),
                  title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  subtitle: Text('${w.bondCount}/$maxBondsPerWishlist bonds'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'rename') _rename(w);
                      if (v == 'delete') _delete(w);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}