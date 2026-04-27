import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart';
import '../core/app_settings.dart';
import '../core/app_localizations.dart';
import '../widgets/permission_dialog.dart';
import 'detection_screen.dart';
import 'target_screen.dart';
import 'settings_screen.dart';
import 'help_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware {
  static bool _permissionDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!await _permissionsGranted()) {
        if (!_permissionDialogShown) {
          _permissionDialogShown = true;
          showPermissionDialog();
        }
      } else {
        speakWelcome();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void didPopNext() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = Provider.of<AppSettings>(context, listen: false);
      final bool isUrdu = settings.language == 'Urdu';

      // Urdu return message is longer – wait 2 seconds
      // English return message is short – wait 0.8 seconds
      final int delayMs = isUrdu ? 2000 : 800;
      await Future.delayed(Duration(milliseconds: delayMs));

      // Ensure any lingering speech is stopped before starting home welcome
      await settings.tts.stop();
      await Future.delayed(const Duration(milliseconds: 200));

      speakWelcome();
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    final settings = Provider.of<AppSettings>(context, listen: false);
    settings.tts.stop();
    super.dispose();
  }

  Future<bool> _permissionsGranted() async {
    final cam = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    return cam.isGranted && mic.isGranted;
  }

  Future<void> speakWelcome() async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final strings = AppLocalizations.of(context);
    await settings.tts.stop();
    await settings.tts.setLanguage(settings.language == 'Urdu' ? 'ur-PK' : 'en-US');
    await settings.tts.setSpeechRate(0.45);
    await settings.tts.setVolume(settings.volume);
    await settings.tts.speak(strings.translate('welcome_home'));
  }

  void showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PermissionDialog(onAllowed: speakWelcome),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    final strings = AppLocalizations.of(context);

    final bgColor = settings.highContrast ? Colors.black : const Color(0xFFF8FAFD);
    final textColor = settings.highContrast ? Colors.white : const Color(0xFF1A237E);
    final cardBgColor = settings.highContrast ? const Color(0xFF1E1E1E) : Colors.white;
    final subtitleColor = settings.highContrast ? Colors.white70 : const Color(0xFF5C6BC0);
    final infoBoxColor = settings.highContrast ? const Color(0xFF2C2C2C) : const Color(0xFFE3F2FD);
    final infoBoxBorder = settings.highContrast ? Colors.grey[700] : const Color(0xFFBBDEFB);

    return MediaQuery(
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
                  // Top bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, spreadRadius: 1)],
                        ),
                        child: IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 22),
                          onPressed: () {
                            settings.tts.stop();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      Text(
                        "LUMINA",
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 1.5),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, spreadRadius: 1)],
                        ),
                        child: IconButton(
                          icon: Icon(Icons.help_outline_rounded, color: textColor, size: 24),
                          onPressed: () {
                            settings.tts.stop();
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen(fromSettings: false)));
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                  // Welcome title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home_rounded, color: textColor, size: 32),
                      const SizedBox(width: 12),
                      Text(strings.translate('home_title'), style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 2)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(strings.translate('home_subtitle'), style: TextStyle(fontSize: 16, color: subtitleColor, fontWeight: FontWeight.w400)),
                  const SizedBox(height: 60),
                  // Scrollable content
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
                            onTap: () {
                              settings.tts.stop();
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const DetectionScreen()));
                            },
                          ),
                          const SizedBox(height: 24),
                          _buildFeatureCard(
                            title: strings.translate('target_search'),
                            subtitle: strings.translate('target_search_sub'),
                            icon: Icons.search_rounded,
                            iconColor: Colors.white,
                            iconBgColor: const Color(0xFF2196F3),
                            gradientColors: const [Color(0xFF42A5F5), Color(0xFF1976D2)],
                            onTap: () {
                              settings.tts.stop();
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const TargetScreen()));
                            },
                          ),
                          const SizedBox(height: 24),
                          _buildFeatureCard(
                            title: strings.translate('settings'),
                            subtitle: strings.translate('settings_sub'),
                            icon: Icons.settings_rounded,
                            iconColor: Colors.white,
                            iconBgColor: const Color(0xFF9C27B0),
                            gradientColors: const [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
                            onTap: () {
                              settings.tts.stop();
                              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                            },
                          ),
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: infoBoxColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: infoBoxBorder!, width: 1),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.volume_up_rounded, color: textColor, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    strings.translate('voice_guidance_active'),
                                    style: TextStyle(fontSize: 14, color: textColor.withOpacity(0.8), fontWeight: FontWeight.w500),
                                  ),
                                ),
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              right: 16,
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
                    child: Center(
                      child: Icon(icon, size: 32, color: iconColor),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(right: 0),
                    child: Container(
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