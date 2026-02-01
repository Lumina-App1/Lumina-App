import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'about_screen.dart';
import 'help_screen.dart';

enum FromPage { home, about, help }

class SettingsScreen extends StatefulWidget {
  final FromPage fromPage;

  const SettingsScreen({super.key, this.fromPage = FromPage.home});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FlutterTts tts = FlutterTts();

  bool _ttsReady = false;

  String language = "English";
  double volume = 0.5;
  bool highContrast = false;
  bool largeText = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadPrefs();
  }

  Future<void> _initTts() async {
    await tts.setSpeechRate(0.45);
    await tts.setPitch(1.0);
    await tts.setVolume(volume);

    _ttsReady = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceSettings();
    });
  }

  /// 🔊 SAFE SPEAK
  Future<void> _speak(String message) async {
    if (!_ttsReady) return;
    await tts.stop();
    await Future.delayed(const Duration(milliseconds: 100));
    await tts.speak(message);
  }

  /// 🔊 SETTINGS SCREEN ANNOUNCEMENT
  Future<void> _announceSettings() async {
    if (!_ttsReady) return;

    String backMessage;
    switch (widget.fromPage) {
      case FromPage.about:
        backMessage = "Returning from About page.";
        break;
      case FromPage.help:
        backMessage = "Returning from Help page.";
        break;
      default:
        backMessage = "You are on the settings page.";
    }

    await _speak(
      "$backMessage Options available are language, volume, high contrast, large text, about, and help.",
    );
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      language = prefs.getString('language') ?? "English";
      volume = prefs.getDouble('volume') ?? 0.5;
      highContrast = prefs.getBool('contrast') ?? false;
      largeText = prefs.getBool('largeText') ?? false;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    await prefs.setDouble('volume', volume);
    await prefs.setBool('contrast', highContrast);
    await prefs.setBool('largeText', largeText);
  }

  /// 🔁 OPEN PAGE & RE-ANNOUNCE ON RETURN
  Future<void> _openPage(Widget page, String message, FromPage from) async {
    await _speak(message);
    await Future.delayed(const Duration(milliseconds: 1200));

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = highContrast ? Colors.black : const Color(0xFFF8FAFD);
    final textColor = highContrast ? Colors.white : const Color(0xFF1A237E);
    final cardColor = highContrast ? const Color(0xFF1E1E1E) : Colors.white;
    final accentColor = const Color(0xFF00E5FF);

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaleFactor: largeText ? 1.5 : 1.0),
      child: Scaffold(
        backgroundColor: bgColor,
        body: CustomScrollView(
          slivers: [
            // ===== APP BAR =====
            SliverAppBar(
              centerTitle: true,
              backgroundColor: bgColor,
              foregroundColor: textColor,
              elevation: 0,
              pinned: true,
              expandedHeight: 120,
              flexibleSpace: FlexibleSpaceBar(
                centerTitle: true,
                title: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: bgColor.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accentColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    "Settings",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFF1A237E).withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              leading: Container(
                margin: const EdgeInsets.only(left: 10),
                decoration: BoxDecoration(
                  color: cardColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
                  onPressed: () async {
                    String msg = widget.fromPage == FromPage.home
                        ? "Returning to home screen."
                        : widget.fromPage == FromPage.about
                        ? "Returning to About page."
                        : "Returning to Help page.";

                    await _speak(msg);
                    await Future.delayed(const Duration(milliseconds: 1200));
                    Navigator.pop(context);
                  },
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: cardColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(Icons.help_outline_rounded, color: textColor),
                    onPressed: () {
                      _openPage(
                        const HelpScreen(fromSettings: true),
                        "Opening help screen.",
                        FromPage.help,
                      );
                    },
                  ),
                ),
              ],
            ),

            // ===== SETTINGS CONTENT =====
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Language Setting Card
                  _settingCard(
                    title: "Language",
                    icon: Icons.language_rounded,
                    iconColor: const Color(0xFF4CAF50),
                    bgColor: cardColor,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: accentColor.withOpacity(0.2),
                          width: 1.5,
                        ),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: language,
                        dropdownColor: cardColor,
                        icon: Icon(Icons.arrow_drop_down_rounded, color: textColor),
                        style: TextStyle(
                          fontSize: 16,
                          color: textColor,
                          fontWeight: FontWeight.w500,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: "English",
                            child: Row(
                              children: [
                                Icon(Icons.language, color: Color(0xFF4CAF50), size: 20),
                                SizedBox(width: 10),
                                Text("English"),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: "Urdu",
                            child: Row(
                              children: [
                                Icon(Icons.translate_rounded, color: Color(0xFF2196F3), size: 20),
                                SizedBox(width: 10),
                                Text("Urdu"),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) async {
                          if (val == null || val == language) return;
                          setState(() => language = val);
                          await _savePrefs();
                          _speak("Language changed to $language.");
                        },
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          labelText: "Select Language",
                          labelStyle: TextStyle(
                            color: textColor.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Volume Setting Card
                  _settingCard(
                    title: "Volume",
                    icon: Icons.volume_up_rounded,
                    iconColor: const Color(0xFF2196F3),
                    bgColor: cardColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "${(volume * 100).round()}%",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                            Icon(
                              volume == 0
                                  ? Icons.volume_off_rounded
                                  : volume < 0.5
                                  ? Icons.volume_down_rounded
                                  : Icons.volume_up_rounded,
                              color: accentColor,
                              size: 24,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: accentColor,
                            inactiveTrackColor: accentColor.withOpacity(0.2),
                            thumbColor: accentColor,
                            overlayColor: accentColor.withOpacity(0.1),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 10,
                              elevation: 4,
                            ),
                            trackHeight: 6,
                          ),
                          child: Slider(
                            value: volume,
                            onChanged: (v) {
                              setState(() => volume = v);
                              tts.setVolume(v);
                            },
                            onChangeEnd: (v) async {
                              await _savePrefs();
                              _speak("Volume set to ${(v * 100).round()} percent.");
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // High Contrast Switch
                  _switchCard(
                    title: "High Contrast Mode",
                    subtitle: "Enhances visibility for better readability",
                    icon: Icons.contrast_rounded,
                    iconColor: const Color(0xFFFF9800),
                    value: highContrast,
                    bgColor: cardColor,
                    onChanged: (v) {
                      setState(() => highContrast = v);
                      _savePrefs();
                      _speak(v
                          ? "High contrast enabled."
                          : "High contrast disabled.");
                    },
                  ),

                  const SizedBox(height: 16),

                  // Large Text Switch
                  _switchCard(
                    title: "Large Text Size",
                    subtitle: "Increases text size for better readability",
                    icon: Icons.text_increase_rounded,
                    iconColor: const Color(0xFF9C27B0),
                    value: largeText,
                    bgColor: cardColor,
                    onChanged: (v) {
                      setState(() => largeText = v);
                      _savePrefs();
                      _speak(v ? "Large text enabled." : "Large text disabled.");
                    },
                  ),

                  const SizedBox(height: 30),

                  // About Button
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1A237E),
                          Color(0xFF3949AB),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1A237E).withOpacity(0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () {
                          _openPage(
                            const AboutScreen(),
                            "Opening about screen.",
                            FromPage.about,
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 18),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                "About Lumina",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================
  // SETTING CARD WIDGET
  // =========================
  Widget _settingCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE8F4FD),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: highContrast ? Colors.white : const Color(0xFF1A237E),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  // =========================
  // SWITCH CARD WIDGET
  // =========================
  Widget _switchCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required Color bgColor,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFE8F4FD),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: highContrast ? Colors.white : const Color(0xFF1A237E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: highContrast
                          ? Colors.white.withOpacity(0.8)
                          : const Color(0xFF5C6BC0),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF00E5FF),
              activeTrackColor: const Color(0xFF00E5FF).withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}