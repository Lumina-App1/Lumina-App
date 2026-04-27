import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_settings.dart';
import 'screens/splash_screen.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

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
        theme: settings.highContrast
            ? ThemeData.dark().copyWith(
          scaffoldBackgroundColor: Colors.black,
          primaryColor: Colors.grey[900],
        )
            : ThemeData.light().copyWith(
          scaffoldBackgroundColor: const Color(0xFFF8FAFD),
          primaryColor: const Color(0xFF1A237E),
        ),
        home: const SplashScreen(),
        navigatorObservers: [routeObserver],
      ),
    );
  }
}