import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'services/api_service.dart';
import 'services/bonds_provider.dart';
import 'services/wishlist_provider.dart';
import 'screens/bonds_screen.dart';
import 'screens/wishlists_screen.dart';
import 'utils/constants.dart';

void main() => runApp(const BondScannerApp());

class BondScannerApp extends StatelessWidget {
  const BondScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiService();
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: api),
        ChangeNotifierProvider(create: (_) => BondsProvider(api)),
        ChangeNotifierProvider(create: (_) => WishlistProvider(api)),
      ],
      child: MaterialApp(
        title: 'BondScanner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.bg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.navy,
            primary: AppColors.navy,
          ),
          // Apply inter globally
          textTheme: GoogleFonts.interTextTheme(), 
        ),
        home: const RootTabs(),
      ),
    );
  }
}

class RootTabs extends StatefulWidget {
  const RootTabs({super.key});
  @override
  State<RootTabs> createState() => _RootTabsState();
}

class _RootTabsState extends State<RootTabs> {
  int _index = 0;
  final _screens = const [BondsScreen(), WishlistsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // extendBody allows the list content to render underneath the floating glass bar
      extendBody: true,
      body: IndexedStack(index: _index, children: _screens),
      
      // Liquid Glass Navigation Bar
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.8),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _navItem(Icons.list_alt, 'Bonds', 0),
                    _navItem(Icons.bookmark_outline, 'Wishlists', 1),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isSelected = _index == index;
    final color = isSelected ? AppColors.navyDeep : AppColors.muted;
    
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _index = index),
      child: SizedBox(
        width: 90,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, isSelected ? -2 : 0, 0),
              child: Icon(
                icon, 
                color: color, 
                size: isSelected ? 26 : 26
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}