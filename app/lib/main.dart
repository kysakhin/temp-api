import 'package:flutter/material.dart';
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
          fontFamily: 'Roboto',
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
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.list_alt), label: 'Bonds'),
          NavigationDestination(icon: Icon(Icons.bookmark), label: 'Wishlists'),
        ],
      ),
    );
  }
}
