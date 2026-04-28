import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_settings.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/detection_screen.dart';
import 'screens/target_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/help_screen.dart';
import 'screens/about_screen.dart';
import 'services/voice_command_service.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.loadPrefs();
  runApp(MyApp(settings: settings));
}

class MyApp extends StatelessWidget {
  final AppSettings settings;
  const MyApp({required this.settings});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: settings,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Lumina',
        navigatorKey: navigatorKey,
        // Define all named routes, including the initial '/'
        routes: {
          '/': (context) => const SplashScreen(),
          '/home': (context) => const HomeScreen(),
          '/detection': (context) => const DetectionScreen(),
          '/target': (context) => const TargetScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/help': (context) => const HelpScreen(),
          '/about': (context) => const AboutScreen(),
        },
        // Remove the 'home' property – it's redundant with route '/'
        initialRoute: '/', // Optional but explicit
        theme: settings.highContrast
            ? ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Colors.black,
          primaryColor: Colors.grey[900],
        )
            : ThemeData.light().copyWith(
          scaffoldBackgroundColor: const Color(0xFFF8FAFD),
          primaryColor: const Color(0xFF1A237E),
        ),
        navigatorObservers: [routeObserver],
      ),
    );
  }
}