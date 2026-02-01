import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../main.dart';
import '../widgets/permission_dialog.dart';
import '../widgets/home_button.dart';

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
  final FlutterTts flutterTts = FlutterTts();
  static bool _permissionDialogShown = false;

  // =========================
  // INIT
  // =========================
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

  // =========================
  // ROUTE AWARE
  // =========================
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }


  @override
  void didPopNext() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {

      await Future.delayed(const Duration(milliseconds: 500));

      speakWelcome();
    });
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    flutterTts.stop();
    super.dispose();
  }

  // =========================
  // PERMISSIONS
  // =========================
  Future<bool> _permissionsGranted() async {
    final cam = await Permission.camera.status;
    final mic = await Permission.microphone.status;
    return cam.isGranted && mic.isGranted;
  }

  // =========================
  // TTS
  // =========================
  Future<void> speakWelcome() async {
    await flutterTts.stop();
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.45);
    await flutterTts.setVolume(1.0);

    await flutterTts.speak(
      "Welcome to home. How can I help you? "
          "For object detection, select object detection. "
          "To search something specific, select target search. "
          "To change settings, select settings.",
    );
  }

  // =========================
  // PERMISSION DIALOG
  // =========================
  void showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return PermissionDialog(
          onAllowed: () {
            speakWelcome();
          },
        );
      },
    );
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF8FAFD),
                Color(0xFFE8F4FD),
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            child: Column(
              children: [
                // TOP BAR WITH APP NAME
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back button with visual enhancement
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Color(0xFF1A237E),
                          size: 22,
                        ),
                        onPressed: () {
                          flutterTts.stop();
                          Navigator.pop(context);
                        },
                      ),
                    ),

                    // App Name in middle
                    const Text(
                      "LUMINA",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A237E),
                        letterSpacing: 1.5,
                      ),
                    ),

                    // Help button with visual enhancement
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.help_outline_rounded,
                          color: Color(0xFF1A237E),
                          size: 24,
                        ),
                        onPressed: () {
                          flutterTts.stop();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HelpScreen(fromSettings: false),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                // WELCOME TITLE WITH ICON
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.home_rounded,
                      color: Color(0xFF1A237E),
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      "HOME",
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A237E),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),


                const Text(
                  "How can I help you today?",
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF5C6BC0),
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 60),


                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [

                        _buildFeatureCard(
                          title: "Object Detection",
                          subtitle: "Identify objects around you",
                          icon: Icons.remove_red_eye_rounded,
                          iconColor: Colors.white,
                          iconBgColor: const Color(0xFF4CAF50),
                          gradientColors: const [
                            Color(0xFF66BB6A),
                            Color(0xFF43A047),
                          ],
                          onTap: () {
                            flutterTts.stop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DetectionScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),


                        _buildFeatureCard(
                          title: "Target Search",
                          subtitle: "Find specific items",
                          icon: Icons.search_rounded,
                          iconColor: Colors.white,
                          iconBgColor: const Color(0xFF2196F3),
                          gradientColors: const [
                            Color(0xFF42A5F5),
                            Color(0xFF1976D2),
                          ],
                          onTap: () {
                            flutterTts.stop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const TargetScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),


                        _buildFeatureCard(
                          title: "Settings",
                          subtitle: "Customize your experience",
                          icon: Icons.settings_rounded,
                          iconColor: Colors.white,
                          iconBgColor: const Color(0xFF9C27B0),
                          gradientColors: const [
                            Color(0xFFAB47BC),
                            Color(0xFF7B1FA2),
                          ],
                          onTap: () {
                            flutterTts.stop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 40),


                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFBBDEFB),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.volume_up_rounded,
                                color: const Color(0xFF1A237E),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Voice guidance is active. Tap any option for audio feedback.",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: const Color(0xFF1A237E).withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================
  // REUSABLE FEATURE CARD WIDGET
  // =========================
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
        height: 120,
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
            // Background pattern
            Positioned(
              right: 16,
              top: 16,
              child: Opacity(
                opacity: 0.1,
                child: Icon(
                  icon,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),

            Row(
              children: [
                // Icon Container
                Container(
                  width: 70,
                  height: 70,
                  margin: const EdgeInsets.only(left: 20),
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
                    child: Icon(
                      icon,
                      size: 32,
                      color: iconColor,
                    ),
                  ),
                ),

                const SizedBox(width: 20),

                // Text Content
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

                // Arrow indicator
                Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}