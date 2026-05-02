import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../main.dart';
import '../core/app_settings.dart';
import '../core/app_localizations.dart';
import '../widgets/permission_dialog.dart';
import 'detection_screen.dart';
import 'target_screen.dart';
import 'settings_screen.dart';
import 'help_screen.dart';
import '../services/voice_command_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  static bool _permissionDialogShown = false;
  late VoiceCommandService _voiceService;
  bool _voiceActive = false;
  String _voiceStatus = "Initializing...";
  Timer? _statusTimer;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _voiceService = VoiceCommandService();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkPermissionsAndInitialize();
    });
  }

  Future<void> _checkPermissionsAndInitialize() async {
    print('🔍 Checking permissions...');

    var micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      micStatus = await Permission.microphone.request();
    }

    var camStatus = await Permission.camera.status;
    if (!camStatus.isGranted) {
      camStatus = await Permission.camera.request();
    }

    print('📱 Microphone: ${micStatus.isGranted}, Camera: ${camStatus.isGranted}');

    if (micStatus.isGranted && camStatus.isGranted) {
      await _voiceService.init(context);
      _startStatusUpdater();
      await Future.delayed(const Duration(seconds: 1));
      await speakWelcome();

      setState(() {
        _initialized = true;
        _voiceActive = _voiceService.isActive;
        _voiceStatus = _voiceService.status;
      });
    } else if (!_permissionDialogShown) {
      _permissionDialogShown = true;
      showPermissionDialog();
    }
  }

  void _startStatusUpdater() {
    _statusTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _voiceActive = _voiceService.isActive;
          _voiceStatus = _voiceService.status;
        });
      }
    });
  }



  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
    if (ModalRoute.of(context)?.isCurrent == true) {
      _voiceService.updateContext(context);
    }
  }

  @override
  void didPopNext() {
    // Refresh context FIRST, then resume — order matters
    _voiceService.updateContext(context);
    _voiceService.resume();
    speakWelcome();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    routeObserver.unsubscribe(this);
    // pause() not stop() — other screens may still need voice
    _voiceService.pause();
    final settings = Provider.of<AppSettings>(context, listen: false);
    settings.tts.stop();
    super.dispose();
  }

  Future<void> speakWelcome() async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final strings = AppLocalizations.of(context);
    final bool isUrdu = settings.language == 'Urdu';

    await settings.tts.stop();
    await settings.tts.setLanguage(isUrdu ? 'ur-PK' : 'en-US');
    await settings.tts.setSpeechRate(0.45);
    await settings.tts.setVolume(settings.volume);

    String fullMessage = strings.translate('welcome_home');

    if (isUrdu) {
      fullMessage += " آواز سے کہیں: آبجیکٹ ڈیٹیکشن، ٹارگٹ سرچ، سیٹنگز، یا ہیلپ";
    } else {
      fullMessage += " Say: object detection, target search, settings, or help";
    }

    await settings.tts.speak(fullMessage);
  }

  void showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PermissionDialog(
        onAllowed: () async {
          await Permission.microphone.request();
          await Permission.camera.request();
          await _voiceService.init(context);
          _startStatusUpdater();
          await speakWelcome();
          setState(() {
            _voiceActive = _voiceService.isActive;
          });
        },
      ),
    );
  }

  void _navigateToDetection() {
    Navigator.pushNamed(context, '/detection');
  }
  void _navigateToTarget() {
    Navigator.pushNamed(context, '/target');
  }
  void _navigateToSettings() {
    Navigator.pushNamed(context, '/settings');
  }

  void _navigateToHelp() {
    Navigator.pushNamed(context, '/help');
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    final strings = AppLocalizations.of(context);
    final bool isUrdu = settings.language == 'Urdu';
    final bool voiceActive = _voiceActive;

    final bgColor = settings.highContrast ? Colors.black : const Color(0xFFF8FAFD);
    final textColor = settings.highContrast ? Colors.white : const Color(0xFF1A237E);
    final cardBgColor = settings.highContrast ? const Color(0xFF1E1E1E) : Colors.white;
    final subtitleColor = settings.highContrast ? Colors.white70 : const Color(0xFF5C6BC0);
    final infoBoxColor = settings.highContrast ? const Color(0xFF2C2C2C) : const Color(0xFFE3F2FD);
    final infoBoxBorder = settings.highContrast ? Colors.grey[700] : const Color(0xFFBBDEFB);

    return Directionality(
      textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaleFactor: settings.largeText ? 1.5 : 1.0),
        child: Scaffold(
          backgroundColor: bgColor,
          body: SafeArea(
            child: Container(
              decoration: BoxDecoration(
                gradient: settings.highContrast
                    ? null
                    : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF8FAFD), Color(0xFFE8F4FD)],
                ),
                color: settings.highContrast ? Colors.black : null,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                child: Column(
                  children: [
                    Row(
                      textDirection: TextDirection.ltr,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 48),
                        Text(
                          "LUMINA",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: cardBgColor,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Icon(Icons.help_outline_rounded, color: textColor, size: 24),
                                ),
                                onPressed: () {
                                  settings.tts.stop();
                                  Navigator.pushNamed(context, '/help');
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 60),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.home_rounded, color: textColor, size: 32),
                        const SizedBox(width: 12),
                        Text(
                          strings.translate('home_title'),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                            letterSpacing: 2,
                          ),
                          textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      strings.translate('home_subtitle'),
                      style: TextStyle(
                        fontSize: 16,
                        color: subtitleColor,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                    ),
                    const SizedBox(height: 60),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildFeatureCard(
                              title: strings.translate('object_detection'),
                              subtitle: strings.translate('object_detection_sub'),
                              icon: Icons.remove_red_eye_rounded,
                              iconColor: Colors.white,
                              iconBgColor: const Color(0xFF4CAF50),
                              gradientColors: const [Color(0xFF66BB6A), Color(0xFF43A047)],
                              onTap: _navigateToDetection,
                              isUrdu: isUrdu,
                            ),
                            const SizedBox(height: 24),
                            _buildFeatureCard(
                              title: strings.translate('target_search'),
                              subtitle: strings.translate('target_search_sub'),
                              icon: Icons.search_rounded,
                              iconColor: Colors.white,
                              iconBgColor: const Color(0xFF2196F3),
                              gradientColors: const [Color(0xFF42A5F5), Color(0xFF1976D2)],
                              onTap: _navigateToTarget,
                              isUrdu: isUrdu,
                            ),
                            const SizedBox(height: 24),
                            _buildFeatureCard(
                              title: strings.translate('settings'),
                              subtitle: strings.translate('settings_sub'),
                              icon: Icons.settings_rounded,
                              iconColor: Colors.white,
                              iconBgColor: const Color(0xFF9C27B0),
                              gradientColors: const [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
                              onTap: _navigateToSettings,
                              isUrdu: isUrdu,
                            ),
                            const SizedBox(height: 40),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: infoBoxColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: infoBoxBorder!, width: 1),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        voiceActive ? Icons.mic : Icons.mic_off,
                                        color: voiceActive ? Colors.green : Colors.red,
                                        size: 24,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          voiceActive
                                              ? (isUrdu
                                              ? "🎤 سن رہا ہوں۔ کہیں: آبجیکٹ ڈیٹیکشن، ٹارگٹ سرچ، سیٹنگز، یا ہیلپ"
                                              : "🎤 Listening. Say: object detection, target search, settings, or help")
                                              : (isUrdu
                                              ? "🔴 سن نہیں رہا: $_voiceStatus"
                                              : "🔴 Not listening: $_voiceStatus"),
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: textColor.withOpacity(0.8),
                                            fontWeight: FontWeight.w500,
                                          ),
                                          textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  if (!voiceActive) ...[
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () async {
                                        await _voiceService.init(context);
                                        setState(() {});
                                      },
                                      child: Text(
                                        isUrdu ? "دوبارہ شروع کریں" : "Retry Voice",
                                        style: const TextStyle(color: Colors.blue),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    required bool isUrdu,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: gradientColors,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: isUrdu ? null : 16,
              left: isUrdu ? 16 : null,
              top: 16,
              child: Opacity(
                opacity: 0.1,
                child: Icon(icon, size: 80, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Center(child: Icon(icon, size: 32, color: iconColor)),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    flex: 3,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: isUrdu ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                            textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                            textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.9),
                            ),
                            textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                            textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}