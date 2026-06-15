import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'app/screens/discover_screen.dart';
import 'app/screens/embed_showcase_screen.dart';
import 'app/screens/search_screen.dart';
import 'app/screens/messages_screen.dart';
import 'app/screens/account_screen.dart';

void main() {
  runApp(const StepChatApp());
}

ThemeData _buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.indigo,
    brightness: Brightness.light,
    onSurface: Colors.black,
    onSurfaceVariant: const Color(0xFF48484A),
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: Colors.grey[50],
    textTheme: ThemeData.light().textTheme.apply(
          bodyColor: Colors.black,
          displayColor: Colors.black,
        ),
  );
}

class StepChatApp extends StatelessWidget {
  const StepChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'StepChat',
      debugShowCheckedModeBanner: false,
      theme: _buildLightTheme(),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      initialRoute: kIsWeb ? '/embed' : '/',
      routes: {
        '/': (_) => const _MainTabShell(),
        '/embed': (_) => const EmbedShowcaseScreen(),
      },
    );
  }
}

class _MainTabShell extends StatefulWidget {
  const _MainTabShell();

  @override
  State<_MainTabShell> createState() => _MainTabShellState();
}

class _MainTabShellState extends State<_MainTabShell> {
  int _currentIndex = 0;

  static const _tabs = <Widget>[
    DiscoverScreen(),
    SearchScreen(),
    MessagesScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          NavigationBar(
            height: 56,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) => setState(() => _currentIndex = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, size: 22),
                selectedIcon: Icon(Icons.home, size: 22),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.search, size: 22),
                selectedIcon: Icon(Icons.search, size: 22),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline, size: 22),
                selectedIcon: Icon(Icons.chat_bubble, size: 22),
                label: 'Messages',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline, size: 22),
                selectedIcon: Icon(Icons.person, size: 22),
                label: 'Account',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
