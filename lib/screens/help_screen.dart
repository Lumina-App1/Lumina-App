import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HelpScreen extends StatefulWidget {
  final bool fromSettings;

  const HelpScreen({super.key, this.fromSettings = false});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final FlutterTts flutterTts = FlutterTts();
  final ScrollController _scrollController = ScrollController();

  double ttsVolume = 0.5;
  String ttsLanguage = 'en-US';
  final double defaultTtsRate = 0.5;

  final List<Map<String, String>> helpItems = [
    {
      'title': 'Navigation',
      'content':
      'Use the back button to go to previous screens and swipe gestures for quick navigation.',
      'icon': 'navigation',
    },
    {
      'title': 'Settings',
      'content': 'Adjust language and volume from the settings screen.',
      'icon': 'settings',
    },
    {
      'title': 'About Page',
      'content':
      'Learn about the app, version, developer, and contact information.',
      'icon': 'info',
    },
    {
      'title': 'Object Detection',
      'content':
      'Detect objects in your surroundings using the camera. The app will describe what it sees.',
      'icon': 'detection',
    },
    {
      'title': 'Target Search',
      'content':
      'Search for a specific object by name, and the app will help you locate it.',
      'icon': 'search',
    },
    {
      'title': 'Voice Control',
      'content':
      'This app is voice-operated. You can give commands or tap buttons for guidance.',
      'icon': 'voice',
    },
    {
      'title': 'Help',
      'content': 'You are currently on the Help screen for guidance.',
      'icon': 'help',
    },
  ];

  bool _isSpeaking = false;
  bool _autoMode = true;
  late List<String> _sectionsText;
  final Map<int, GlobalKey> _itemKeys = {};
  int _currentSectionIndex = 0;

  @override
  void initState() {
    super.initState();
    _sectionsText =
        helpItems.map((e) => '${e['title']}: ${e['content']}').toList();

    for (int i = 0; i < helpItems.length; i++) {
      _itemKeys[i] = GlobalKey();
    }

    _initTts();
  }

  Future<void> _initTts() async {
    await _loadTtsSettings();

    flutterTts.setCompletionHandler(() {
      if (!_isSpeaking || !_autoMode) return;
      _currentSectionIndex++;
      if (_currentSectionIndex < _sectionsText.length) {
        _scrollToItem(_currentSectionIndex);
        flutterTts.speak(_sectionsText[_currentSectionIndex]);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _announceHelpPage();
      _startReadingAll();
    });
  }

  Future<void> _loadTtsSettings() async {
    final prefs = await SharedPreferences.getInstance();
    ttsVolume = (prefs.getDouble('volume') ?? 100) / 100;
    ttsLanguage = prefs.getString('language') ?? 'en-US';

    await flutterTts.setLanguage(ttsLanguage);
    await flutterTts.setSpeechRate(defaultTtsRate);
    await flutterTts.setVolume(ttsVolume);
  }

  Future<void> _announceHelpPage() async {
    _isSpeaking = true;
    await flutterTts.stop();
    await flutterTts.speak(
        "You are on the Help screen. This app is voice operated. "
            "Here is guidance for all its features.");
    await Future.delayed(const Duration(milliseconds: 1500));
  }

  void _scrollToItem(int index) {
    final key = _itemKeys[index];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    }
  }

  Future<void> _startReadingAll({int startIndex = 0}) async {
    _autoMode = true;
    _isSpeaking = true;
    _currentSectionIndex = startIndex;

    _scrollToItem(startIndex);
    await flutterTts.stop();
    await flutterTts.speak(_sectionsText[startIndex]);
  }

  Future<void> _readItem(int index) async {
    _autoMode = true;
    _isSpeaking = true;
    _currentSectionIndex = index;

    _scrollToItem(index);
    await flutterTts.stop();
    await flutterTts.speak(_sectionsText[index]);
  }

  Future<void> _stopSpeaking() async {
    _isSpeaking = false;
    _autoMode = false;
    await flutterTts.stop();
  }

  @override
  void dispose() {
    flutterTts.stop();
    _scrollController.dispose();
    super.dispose();
  }

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
          child: Column(
            children: [
              // ===== HEADER =====
              Container(
                padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(30),
                    bottomRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Top Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A237E),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () async {
                              _autoMode = false;
                              _isSpeaking = true;

                              await flutterTts.stop();

                              flutterTts.setCompletionHandler(() {
                                if (mounted) {
                                  Navigator.pop(context);
                                }
                              });

                              if (widget.fromSettings) {
                                await flutterTts.speak(
                                    "Returning to Settings screen.");
                              } else {
                                await flutterTts.speak("Returning to Home screen.");
                              }
                            },
                          ),
                        ),

                        // Control Buttons
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1A237E),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _isSpeaking
                                      ? Icons.stop_circle_rounded
                                      : Icons.play_circle_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                onPressed: () {
                                  if (_isSpeaking) {
                                    _stopSpeaking();
                                  } else {
                                    _startReadingAll();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),

                    // Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A237E).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.help_outline_rounded,
                            color: Color(0xFF1A237E),
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          "HELP GUIDE",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A237E),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Subtitle
                    Text(
                      "Tap any section to hear guidance",
                      style: TextStyle(
                        fontSize: 16,
                        color: const Color(0xFF5C6BC0),
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ===== HELP ITEMS =====
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListView(
                    controller: _scrollController,
                    children: [
                      ...helpItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;

                        return Padding(
                          key: _itemKeys[index],
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildHelpCard(
                            title: item['title']!,
                            content: item['content']!,
                            icon: _getIcon(item['icon']!),
                            iconColor: _getIconColor(index),
                            gradient: _getCardGradient(index),
                            onTap: () => _readItem(index),
                          ),
                        );
                      }).toList(),

                      const SizedBox(height: 30),

                      // Voice Guidance Note
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF1A237E),
                              Color(0xFF3949AB),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1A237E).withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 2,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.volume_up_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Voice Guidance",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "This app will automatically read each section. Tap any section to hear it again.",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================
  // HELP CARD WIDGET
  // =========================
  Widget _buildHelpCard({
    required String title,
    required String content,
    required IconData icon,
    required Color iconColor,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.3),
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
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon Container
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),

                  const SizedBox(width: 16),

                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          content,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withOpacity(0.9),
                            height: 1.4,
                          ),
                        ),
                      ],
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

  // =========================
  // ICON HELPER FUNCTIONS
  // =========================
  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'navigation':
        return Icons.navigation_rounded;
      case 'settings':
        return Icons.settings_rounded;
      case 'info':
        return Icons.info_outline_rounded;
      case 'detection':
        return Icons.remove_red_eye_rounded;
      case 'search':
        return Icons.search_rounded;
      case 'voice':
        return Icons.mic_rounded;
      case 'help':
        return Icons.help_outline_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Color _getIconColor(int index) {
    final colors = [
      const Color(0xFF4CAF50), // Green
      const Color(0xFF2196F3), // Blue
      const Color(0xFF9C27B0), // Purple
      const Color(0xFFFF9800), // Orange
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFFE91E63), // Pink
      const Color(0xFF3F51B5), // Indigo
    ];
    return colors[index % colors.length];
  }

  List<Color> _getCardGradient(int index) {
    final gradients = [
      [const Color(0xFF66BB6A), const Color(0xFF43A047)], // Green
      [const Color(0xFF42A5F5), const Color(0xFF1976D2)], // Blue
      [const Color(0xFFAB47BC), const Color(0xFF7B1FA2)], // Purple
      [const Color(0xFFFFB74D), const Color(0xFFF57C00)], // Orange
      [const Color(0xFF26C6DA), const Color(0xFF0097A7)], // Cyan
      [const Color(0xFFF06292), const Color(0xFFC2185B)], // Pink
      [const Color(0xFF5C6BC0), const Color(0xFF3949AB)], // Indigo
    ];
    return gradients[index % gradients.length];
  }
}