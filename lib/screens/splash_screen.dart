import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FlutterTts _flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();

    // Speak welcome message as soon as splash screen shows
    _speakWelcome();

    // Navigate after 3 seconds
    Timer(const Duration(seconds:5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    });
  }

  Future<void> _speakWelcome() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.2);
    await _flutterTts.setSpeechRate(0.5);

    await _flutterTts.speak(
        "Welcome to Lumina App. Seeing Beyond Vision");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21), // Deep blue background
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0A0E21),
              Color(0xFF1A237E),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🔵 ENHANCED LOGO CONTAINER WITH GLOW EFFECT
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1A237E).withOpacity(0.3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: const Color(0xFF2979FF).withOpacity(0.3),
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(80),
                    child: Image.asset(
                      'assets/lumina.png', // make sure this exists
                      width: 140,
                      height: 140,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 🔵 APP NAME WITH GRADIENT TEXT
              ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    colors: [
                      Color(0xFF00E5FF),
                      Color(0xFF2979FF),
                      Color(0xFF7C4DFF),
                    ],
                    stops: [0.0, 0.5, 1.0],
                  ).createShader(bounds);
                },
                child: const Text(
                  "LUMINA",
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 🔵 TAGLINE WITH BETTER TYPOGRAPHY
              const Text(
                "Seeing Beyond Vision",
                style: TextStyle(
                  fontSize: 18,
                  color: Color(0xFFB3E5FC),
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1.5,
                ),
              ),

              const SizedBox(height: 60),

              // 🔵 LOADING INDICATOR
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  backgroundColor: const Color(0xFF1A237E),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    const Color(0xFF00E5FF).withOpacity(0.7),
                  ),
                  borderRadius: BorderRadius.circular(10),
                  minHeight: 4,
                ),
              ),

              const SizedBox(height: 20),

              // 🔵 SUBTLE LOADING TEXT
              AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 500),
                child: const Text(
                  "Initializing accessibility features...",
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF90CAF9),
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}