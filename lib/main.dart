import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

void main() {
  runApp(const LUMINA());
}

class LUMINA extends StatelessWidget {
  const LUMINA({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lumina',
      theme: ThemeData.dark(),
      home: const SplashScreen(),
      navigatorObservers: [routeObserver], // 🔥 VERY IMPORTANT
    );
  }
}
