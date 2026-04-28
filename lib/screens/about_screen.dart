import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../core/app_settings.dart';
import '../core/app_localizations.dart';

class AboutScreen extends StatefulWidget {
  final bool fromSettings;

  const AboutScreen({super.key, this.fromSettings = false});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};
  final GlobalKey _missionKey = GlobalKey();
  late List<Map<String, String>> aboutItems;
  late List<String> _sectionsText;

  bool _isSpeaking = false;
  bool _autoMode = true;
  bool _dataInitialized = false;
  bool _firstStart = true;

  double ttsVolume = 0.5;
  String ttsLanguage = 'en-US';
  final double defaultTtsRate = 0.5;

  Completer<void>? _ttsCompleter;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataInitialized) {
      _initializeData();
      _dataInitialized = true;
      _initTts();
    }
  }

  void _initializeData() {
    final strings = AppLocalizations.of(context);
    aboutItems = [
      {'title': strings.translate('app_name'), 'content': 'LUMINA'},
      {'title': strings.translate('version'), 'content': '1.0.0'},
      {'title': strings.translate('purpose'), 'content': strings.translate('purpose_content')},
      {'title': strings.translate('developer'), 'content': 'LuminaVision Technologies'},
      {'title': strings.translate('contact'), 'content': 'support@lumina12.com'},
    ];

    for (int i = 0; i < aboutItems.length; i++) {
      _itemKeys.putIfAbsent(i, () => GlobalKey());
    }
  }

  void _buildSectionsText() {
    final strings = AppLocalizations.of(context);
    String welcomeMessage;
    if (ttsLanguage == 'ur-PK') {
      welcomeMessage = 'آپ اباؤٹ اسکرین پر ہیں';
    } else {
      welcomeMessage = 'You are on the about screen';
    }

    final missionText = strings.translate('our_mission') + ': ' + strings.translate('mission_text');

    _sectionsText = [welcomeMessage];
    _sectionsText.addAll(aboutItems.map((e) => '${e['title']}: ${e['content']}').toList());
    _sectionsText.add(missionText);
  }

  Future<void> _initTts() async {
    await _loadTtsSettings();
    final settings = Provider.of<AppSettings>(context, listen: false);
    settings.tts.setCompletionHandler(() {
      _ttsCompleter?.complete();
    });

    _buildSectionsText();

    // Wait for any external TTS to finish (prevents voice cutting)
    if (ttsLanguage == 'ur-PK') {
      await Future.delayed(const Duration(milliseconds: 1500));
    } else {
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (_sectionsText.isNotEmpty && mounted) {
      _startReadingAll(isFirst: true);
    }
  }

  Future<void> _loadTtsSettings() async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    ttsVolume = settings.volume;
    ttsLanguage = settings.language == 'Urdu' ? 'ur-PK' : 'en-US';
    await settings.tts.setVolume(ttsVolume);
    await settings.tts.setSpeechRate(defaultTtsRate);
    await settings.tts.setLanguage(ttsLanguage);
  }

  /// Scrolls to the item at [index] only if it's not already sufficiently visible.
  Future<void> _scrollToItemIfNeeded(int index) async {
    // Determine which key to use
    GlobalKey? key;
    if (index == 0) {
      // Welcome message - scroll to first item
      key = _itemKeys[0];
    } else if (index <= aboutItems.length) {
      // Purpose, version, developer, contact items (1-5)
      final itemIndex = index - 1; // because sectionsText[0] is welcome message
      if (itemIndex >= 0 && itemIndex < aboutItems.length) {
        key = _itemKeys[itemIndex];
      }
    } else if (index == _sectionsText.length - 1) {
      // Mission card is last
      key = _missionKey;
    }

    if (key?.currentContext == null) return;

    final ScrollableState? scrollableState = Scrollable.maybeOf(key!.currentContext!);
    if (scrollableState == null) return;

    final RenderBox? renderBox = key.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final itemTop = position.dy;
    final itemBottom = itemTop + renderBox.size.height;
    final screenHeight = MediaQuery.of(context).size.height;

    // Consider visible if at least 60% of the item is on screen
    final visible = itemTop >= 0 && itemBottom <= screenHeight;
    if (!visible) {
      final scrollDuration = ttsLanguage == 'ur-PK' ? 150 : 300;
      await Scrollable.ensureVisible(
        key.currentContext!,
        duration: Duration(milliseconds: scrollDuration),
        curve: Curves.easeInOut,
        alignment: 0.3, // Changed from 0.5 to show item slightly above center
      );
      // Small delay to let scrolling settle
      await Future.delayed(const Duration(milliseconds: 0));
    }
  }

  int _estimateDurationMs(String text) {
    const int msPerChar = 100;
    int estimated = text.length * msPerChar;
    if (ttsLanguage == 'ur-PK') {
      return estimated.clamp(4000, 20000);
    } else {
      return estimated.clamp(2500, 8000);
    }
  }

  Future<void> _speakAndWait(String text) async {
    final settings = Provider.of<AppSettings>(context, listen: false);

    _ttsCompleter = Completer<void>();
    await settings.tts.speak(text);

    final estimatedDur = _estimateDurationMs(text);
    final fallbackDuration = Duration(milliseconds: estimatedDur + 500);

    try {
      await _ttsCompleter!.future.timeout(fallbackDuration);
    } on TimeoutException {
      debugPrint('Fallback timer used for: "$text" (${text.length} chars)');
    } finally {
      _ttsCompleter = null;
    }

    if (ttsLanguage == 'ur-PK') {
      await Future.delayed(const Duration(milliseconds: 0));
    }
  }

  Future<void> _startReadingAll({int startIndex = 0, bool isFirst = false}) async {
    if (!isFirst) {
      await _stopSpeaking();
    }
    _autoMode = true;
    setState(() => _isSpeaking = true);
    _firstStart = false;

    for (int i = startIndex; i < _sectionsText.length; i++) {
      if (!_autoMode) break;
      // Scroll to the current item if needed, before speaking
      await _scrollToItemIfNeeded(i);
      await _speakAndWait(_sectionsText[i]);
    }

    if (mounted && _autoMode) {
      setState(() => _isSpeaking = false);
    }
  }

  Future<void> _readItem(int index) async {
    await _stopSpeaking();
    _autoMode = false;
    setState(() => _isSpeaking = true);

    // Map the item index to sectionsText index
    int sectionsIndex = index + 1; // +1 because sectionsText[0] is welcome message
    if (sectionsIndex >= 0 && sectionsIndex < _sectionsText.length) {
      // Force scroll when manually tapped
      await _scrollToItemIfNeeded(sectionsIndex);
      await _speakAndWait(_sectionsText[sectionsIndex]);
    }

    if (mounted) {
      setState(() => _isSpeaking = false);
    }
  }

  Future<void> _stopSpeaking() async {
    _autoMode = false;
    if (mounted) setState(() => _isSpeaking = false);
    final settings = Provider.of<AppSettings>(context, listen: false);
    await settings.tts.stop();
    _ttsCompleter = null;
  }

  @override
  void dispose() {
    final settings = Provider.of<AppSettings>(context, listen: false);
    settings.tts.stop();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    final strings = AppLocalizations.of(context);

    final bgColor = settings.highContrast ? Colors.black : const Color(0xFFF8FAFD);
    final textColor = settings.highContrast ? Colors.white : const Color(0xFF1A237E);
    final cardBgColor = settings.highContrast ? const Color(0xFF1E1E1E) : Colors.white;
    final subtitleColor = settings.highContrast ? Colors.white70 : const Color(0xFF5C6BC0);
    final headerBgColor = settings.highContrast ? const Color(0xFF1E1E1E) : Colors.white;

    // Determine if RTL layout is needed based on language
    final isRtl = settings.language == 'Urdu';
    final isUrdu = settings.language == 'Urdu';

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: settings.largeText ? 1.5 : 1.0),
      child: flutter.Directionality(
        textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
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
              child: Column(
                children: [
                  _buildHeader(strings, textColor, subtitleColor, headerBgColor, cardBgColor),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ListView(
                        controller: _scrollController,
                        children: [
                          ...aboutItems.asMap().entries.map((entry) {
                            final index = entry.key;
                            final item = entry.value;
                            return Padding(
                              key: _itemKeys[index],
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildAboutCard(
                                title: item['title']!,
                                content: item['content']!,
                                icon: _getIcon(index),
                                gradient: _getCardGradient(index),
                                onTap: () => _readItem(index),
                                isUrdu: isUrdu, // Pass language flag
                              ),
                            );
                          }).toList(),
                          const SizedBox(height: 30),
                          _buildMissionCard(strings),
                          const SizedBox(height: 40),
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

  // ------------------- HEADER WITH WHITE CIRCLE ICONS -------------------
  Widget _buildHeader(AppLocalizations strings, Color textColor, Color subtitleColor,
      Color headerBgColor, Color cardBgColor) {
    return Container(
      padding: const EdgeInsets.only(top: 20, left: 20, right: 20, bottom: 20),
      decoration: BoxDecoration(
        color: headerBgColor,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, spreadRadius: 5)],
      ),
      child: Column(
        children: [
          // Fixed icons row - same for both languages by forcing LTR
          Row(
            textDirection: TextDirection.ltr, // ensures icons never flip in RTL mode
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back navigation icon - ALWAYS on LEFT side, with white circle
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Directionality(
                    textDirection: TextDirection.ltr,
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF1A237E), size: 24),
                  ),
                  onPressed: () async {
                    await _stopSpeaking();
                    final settingsLocal = Provider.of<AppSettings>(context, listen: false);
                    await settingsLocal.tts.speak(strings.translate('returning_to_settings'));
                    await Future.delayed(const Duration(seconds: 2));
                    if (mounted) Navigator.pop(context);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
              // Speaker/Play icon - ALWAYS on RIGHT side, with white circle
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: Icon(
                    _isSpeaking ? Icons.stop_circle_outlined : Icons.volume_up_rounded,
                    color: const Color(0xFF1A237E),
                    size: 28,
                  ),
                  onPressed: () async {
                    if (_isSpeaking) {
                      await _stopSpeaking();
                    } else {
                      await _startReadingAll(isFirst: false);
                    }
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 25),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: cardBgColor,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.15), blurRadius: 30, spreadRadius: 5)],
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3), width: 3),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/new_logo1.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF1A237E),
                  child: const Center(child: Icon(Icons.visibility_outlined, color: Colors.white, size: 50)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(strings.translate('about_lumina_title'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(strings.translate('about_subtitle'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: subtitleColor, fontWeight: FontWeight.w400, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  // ------------------- MODIFIED: Blurred icon moves to left for Urdu -------------------
  Widget _buildAboutCard({
    required String title,
    required String content,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
    required bool isUrdu,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: gradient.first.withOpacity(0.3), blurRadius: 15, spreadRadius: 2, offset: const Offset(0, 4))
          ],
        ),
        child: Stack(
          children: [
            // Blurred background icon: on right for English, on left for Urdu
            Positioned(
              top: 16,
              right: isUrdu ? null : 16,
              left: isUrdu ? 16 : null,
              child: Opacity(opacity: 0.1, child: Icon(icon, size: 60, color: Colors.white)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                    ),
                    child: Center(child: Icon(icon, color: Colors.white, size: 24)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white,
                                letterSpacing: 0.5)),
                        const SizedBox(height: 8),
                        Text(content,
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400,
                                color: Colors.white.withOpacity(0.9), height: 1.4)),
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

  Widget _buildMissionCard(AppLocalizations strings) {
    return Container(
      key: _missionKey,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.3), blurRadius: 15, spreadRadius: 2,
            offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.remove_red_eye_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(strings.translate('our_mission'),
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            strings.translate('mission_text'),
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(int index) {
    const icons = [Icons.apps_rounded, Icons.upgrade_rounded, Icons.accessibility_new_rounded,
      Icons.person_rounded, Icons.email_rounded];
    return index < icons.length ? icons[index] : Icons.info_outline_rounded;
  }

  List<Color> _getCardGradient(int index) {
    const gradients = [
      [Color(0xFF66BB6A), Color(0xFF43A047)],
      [Color(0xFF42A5F5), Color(0xFF1976D2)],
      [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
      [Color(0xFFFFB74D), Color(0xFFF57C00)],
      [Color(0xFF26C6DA), Color(0xFF0097A7)],
    ];
    return gradients[index % gradients.length];
  }
}