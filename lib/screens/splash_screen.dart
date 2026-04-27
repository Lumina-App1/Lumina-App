import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'home_screen.dart';
import '../core/app_settings.dart';
import '../core/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final FlutterTts _flutterTts = FlutterTts();
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _speakWelcomeAndNavigate();
  }

  Future<void> _speakWelcomeAndNavigate() async {
    // Get saved language and localized welcome message
    final settings = Provider.of<AppSettings>(context, listen: false);
    final strings = AppLocalizations.of(context);
    final String welcomeMessage = strings.translate('welcome_splash');
    final String ttsLang = settings.language == 'Urdu' ? 'ur-PK' : 'en-US';

    // Set up completion handler
    _flutterTts.setCompletionHandler(() {
      if (!_navigated) {
        _navigated = true;
        _goToHome();
      }
    });

    // Fallback timer (in case completion handler never fires)
    Timer(const Duration(seconds: 8), () {
      if (!_navigated) {
        _navigated = true;
        _goToHome();
      }
    });

    // Speak the message in the correct language
    await _flutterTts.setLanguage(ttsLang);
    await _flutterTts.setPitch(1.2);
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(settings.volume);
    await _flutterTts.speak(welcomeMessage);
  }

  void _goToHome() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Your existing build method remains exactly the same
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
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
                      'assets/new_logo1.jpg',
                      width: 140,
                      height: 140,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
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
              const AnimatedOpacity(
                opacity: 1.0,
                duration: Duration(milliseconds: 500),
                child: Text(
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