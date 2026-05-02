import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../core/app_settings.dart';
import '../core/app_localizations.dart';
import '../services/voice_command_service.dart';

class HelpScreen extends StatefulWidget {
  final bool fromSettings;

  const HelpScreen({super.key, this.fromSettings = false});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with RouteAware {
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _itemKeys = {};
  late List<Map<String, String>> helpItems;
  late List<String> _sectionsText;
  final GlobalKey _voiceGuidanceKey = GlobalKey();

  bool _isSpeaking = false;
  bool _autoMode = true;
  bool _dataInitialized = false;

  double ttsVolume = 0.5;
  String ttsLanguage = 'en-US';
  final double defaultTtsRate = 0.5;

  Completer<void>? _ttsCompleter;
  late VoiceCommandService _voiceService;

  @override
  void initState() {
    super.initState();
    _voiceService = VoiceCommandService();
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
      _voiceService.setScreenCommands(_handleVoiceCommand);
    }
    if (!_dataInitialized) {
      _initializeData();
      _dataInitialized = true;
      _initTts();
    }
  }

  @override
  void didPopNext() {
    _voiceService.updateContext(context);
    _voiceService.setScreenCommands(_handleVoiceCommand);
    _voiceService.resume();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    // DELETE THIS LINE: _voiceService.clearScreenCommands();
    final settings = Provider.of<AppSettings>(context, listen: false);
    settings.tts.stop();
    _scrollController.dispose();
    super.dispose();
  }

  // Voice commands — back to settings or back to home depending on fromSettings
  void _handleVoiceCommand(String command) {
    print('🆘 Help screen command: "$command"');
    final bool isUrdu = ttsLanguage == 'ur-PK';

    if (widget.fromSettings) {
      // Opened from settings — listen for "return to settings" and urdu equivalent
      if (command.contains('settings') ||
          command.contains('return to settings') ||
          command.contains('back to settings') ||
          command.contains('go to settings') ||
          command.contains('setting') ||
          command.contains('wapis settings') ||
          command.contains('settings par wapis') ||
          command.contains('settings pe wapis') ||
          command.contains('back') ||
          command.contains('return') ||
          command.contains('wapis') ||
          command.contains('واپس') ||
          command.contains('سیٹنگز')) {
        _goBack();
      }
    } else {
      // Opened from home — listen for "back to home" and urdu equivalent
      if (command.contains('home') ||
          command.contains('return to home') ||
          command.contains('back to home') ||
          command.contains('go to home') ||
          command.contains('go home') ||
          command.contains('home screen') ||
          command.contains('return to home screen') ||
          command.contains('back to home screen') ||
          command.contains('back') ||
          command.contains('return') ||
          command.contains('wapis') ||
          command.contains('ghar') ||
          command.contains('واپس') ||
          command.contains('گھر') ||
          command.contains('home par wapis') ||
          command.contains('wapis jao')) {
        _goBack();
      }
    }
  }

  Future<void> _goBack() async {
    await _stopSpeaking();
    final settings = Provider.of<AppSettings>(context, listen: false);
    final strings = AppLocalizations.of(context);
    final bool isUrdu = settings.language == 'Urdu';

    String message;
    if (widget.fromSettings) {
      message = isUrdu
          ? 'سیٹنگز اسکرین پر واپس جا رہے ہیں'
          : 'Returning to Settings Screen';
    } else {
      message = isUrdu
          ? 'ہوم اسکرین پر واپس جا رہے ہیں'
          : 'Returning to Home Screen';
    }

    await Future.delayed(const Duration(milliseconds: 200));
    await settings.tts.speak(message);
    await Future.delayed(Duration(milliseconds: isUrdu ? 2000 : 1800));
    if (mounted) Navigator.pop(context);
    // Voice continues automatically
  }

  Widget _buildRtlText(String text,
      {required TextStyle style, TextAlign? align}) {
    final isUrdu = ttsLanguage == 'ur-PK';
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        style: style,
        textAlign: align ?? (isUrdu ? TextAlign.right : TextAlign.left),
        textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
        softWrap: true,
      ),
    );
  }

  void _initializeData() {
    final strings = AppLocalizations.of(context);
    helpItems = [
      {
        'title': strings.translate('navigation'),
        'content': strings.translate('navigation_content'),
        'icon': 'navigation'
      },
      {
        'title': strings.translate('settings_help'),
        'content': strings.translate('settings_help_content'),
        'icon': 'settings'
      },
      {
        'title': strings.translate('about_page'),
        'content': strings.translate('about_page_content'),
        'icon': 'info'
      },
      {
        'title': strings.translate('object_detection_help'),
        'content': strings.translate('object_detection_help_content'),
        'icon': 'detection'
      },
      {
        'title': strings.translate('target_search_help'),
        'content': strings.translate('target_search_help_content'),
        'icon': 'search'
      },
      {
        'title': strings.translate('voice_control'),
        'content': strings.translate('voice_control_content'),
        'icon': 'voice'
      },
      {
        'title': strings.translate('help_help'),
        'content': strings.translate('help_help_content'),
        'icon': 'help'
      },
    ];

    for (int i = 0; i < helpItems.length; i++) {
      _itemKeys.putIfAbsent(i, () => GlobalKey());
    }
  }

  void _buildSectionsText() {
    final strings = AppLocalizations.of(context);
    String welcomeMessage = ttsLanguage == 'ur-PK'
        ? 'آپ ہیلپ اسکرین پر ہیں'
        : 'You are on the help screen';

    String voiceGuidanceText = ttsLanguage == 'ur-PK'
        ? 'وائس گائیڈنس: یہ ایپ خود بخود ہر سیکشن پڑھے گی۔'
        : 'Voice guidance: This app will automatically read each section. Tap any section to hear it again.';

    _sectionsText = [welcomeMessage];
    _sectionsText
        .addAll(helpItems.map((e) => '${e['title']}: ${e['content']}').toList());
    _sectionsText.add(voiceGuidanceText);
  }

  Future<void> _initTts() async {
    await _loadTtsSettings();
    _buildSectionsText();

    final settings = Provider.of<AppSettings>(context, listen: false);
    settings.tts.setCompletionHandler(() {
      _ttsCompleter?.complete();
    });

    await Future.delayed(
        Duration(milliseconds: ttsLanguage == 'ur-PK' ? 1000 : 800));

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

  Future<void> _scrollToItemIfNeeded(int index) async {
    GlobalKey? key;
    if (index == 0) {
      key = _itemKeys[0];
    } else if (index <= helpItems.length) {
      final itemIndex = index - 1;
      if (itemIndex >= 0 && itemIndex < helpItems.length) {
        key = _itemKeys[itemIndex];
      }
    } else if (index == _sectionsText.length - 1) {
      key = _voiceGuidanceKey;
    }

    if (key?.currentContext == null) return;

    final RenderBox? renderBox =
    key!.currentContext!.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final itemTop = position.dy;
    final itemBottom = itemTop + renderBox.size.height;
    final screenHeight = MediaQuery.of(context).size.height;

    final visible = itemTop >= 0 && itemBottom <= screenHeight;
    if (!visible) {
      await Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 20),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  int _estimateDurationMs(String text) {
    const int msPerChar = 100;
    int estimated = text.length * msPerChar;
    return ttsLanguage == 'ur-PK'
        ? estimated.clamp(4000, 8000)
        : estimated.clamp(450, 6500);
  }

  Future<void> _speakAndWait(String text) async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    _ttsCompleter = Completer<void>();
    await settings.tts.speak(text);
    final estimatedDur = _estimateDurationMs(text);
    try {
      await _ttsCompleter!.future
          .timeout(Duration(milliseconds: estimatedDur));
    } on TimeoutException {
      debugPrint('Fallback timer used for: "$text"');
    } finally {
      _ttsCompleter = null;
    }
  }

  Future<void> _startReadingAll(
      {int startIndex = 0, bool isFirst = false}) async {
    if (!isFirst) await _stopSpeaking();
    _autoMode = true;
    setState(() => _isSpeaking = true);

    for (int i = startIndex; i < _sectionsText.length; i++) {
      if (!_autoMode) break;
      await _scrollToItemIfNeeded(i);
      await _speakAndWait(_sectionsText[i]);
    }

    if (mounted && _autoMode) {
      setState(() => _isSpeaking = false);
    }
  }

  Future<void> _readItem(int index) async {
    await _stopSpeaking();
    _autoMode = true;
    setState(() => _isSpeaking = true);

    int sectionsIndex = index + 1;
    if (sectionsIndex < _sectionsText.length) {
      await _scrollToItemIfNeeded(sectionsIndex);
      await _speakAndWait(_sectionsText[sectionsIndex]);
    }

    if (mounted) setState(() => _isSpeaking = false);
  }

  Future<void> _stopSpeaking() async {
    _autoMode = false;
    if (mounted) setState(() => _isSpeaking = false);
    final settings = Provider.of<AppSettings>(context, listen: false);
    await settings.tts.stop();
    _ttsCompleter?.complete();
    _ttsCompleter = null;
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    final strings = AppLocalizations.of(context);
    final isUrdu = ttsLanguage == 'ur-PK';

    final bgColor =
    settings.highContrast ? Colors.black : const Color(0xFFF8FAFD);
    final textColor =
    settings.highContrast ? Colors.white : const Color(0xFF1A237E);
    final subtitleColor =
    settings.highContrast ? Colors.white70 : const Color(0xFF5C6BC0);
    final headerBgColor =
    settings.highContrast ? const Color(0xFF1E1E1E) : Colors.white;

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaleFactor: settings.largeText ? 1.5 : 1.0),
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
                Container(
                  padding: const EdgeInsets.only(
                      top: 20, left: 20, right: 20, bottom: 20),
                  decoration: BoxDecoration(
                    color: headerBgColor,
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
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
                              icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  color: Color(0xFF1A237E),
                                  size: 20),
                              onPressed: _goBack,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
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
                                _isSpeaking
                                    ? Icons.stop_circle_rounded
                                    : Icons.play_circle_rounded,
                                color: const Color(0xFF1A237E),
                                size: 22,
                              ),
                              onPressed: () {
                                if (_isSpeaking)
                                  _stopSpeaking();
                                else
                                  _startReadingAll(isFirst: false);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      _buildRtlText(
                        strings.translate('help_title'),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                          letterSpacing: 1.5,
                        ),
                        align: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding:
                        const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildRtlText(
                          strings.translate('help_subtitle'),
                          style: TextStyle(
                            fontSize: 16,
                            color: subtitleColor,
                            fontWeight: FontWeight.w400,
                            fontStyle: FontStyle.italic,
                          ),
                          align: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Voice hint — changes based on fromSettings and language
                      Text(
                        widget.fromSettings
                            ? (isUrdu
                            ? 'کہیں: "واپس" یا "سیٹنگز پر واپس"'
                            : 'Say: "back" or "return to settings"')
                            : (isUrdu
                            ? 'کہیں: "واپس" یا "ہوم پر واپس"'
                            : 'Say: "back" or "return to home"'),
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF00E5FF).withOpacity(0.8),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
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
                        GestureDetector(
                          key: _voiceGuidanceKey,
                          onTap: () => _readItem(helpItems.length),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF1A237E),
                                  Color(0xFF3949AB)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1A237E)
                                      .withOpacity(0.3),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                if (!isUrdu)
                                  const Icon(Icons.volume_up_rounded,
                                      color: Colors.white, size: 28),
                                if (!isUrdu) const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                    children: [
                                      _buildRtlText(
                                        strings.translate(
                                            'voice_guidance_card'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _buildRtlText(
                                        strings.translate(
                                            'voice_guidance_card_text'),
                                        style: TextStyle(
                                          color:
                                          Colors.white.withOpacity(0.9),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isUrdu) const SizedBox(width: 16),
                                if (isUrdu)
                                  const Icon(Icons.volume_up_rounded,
                                      color: Colors.white, size: 28),
                              ],
                            ),
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
      ),
    );
  }

  Widget _buildHelpCard({
    required String title,
    required String content,
    required IconData icon,
    required Color iconColor,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    final isUrdu = ttsLanguage == 'ur-PK';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
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
            Positioned(
              right: isUrdu ? null : 16,
              left: isUrdu ? 16 : null,
              top: 16,
              child: Opacity(
                  opacity: 0.1,
                  child: Icon(icon, size: 60, color: Colors.white)),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUrdu) ...[
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5),
                      ),
                      child: Center(
                          child:
                          Icon(icon, color: Colors.white, size: 24)),
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildRtlText(
                          title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildRtlText(
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
                  if (isUrdu) ...[
                    const SizedBox(width: 16),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 1.5),
                      ),
                      child: Center(
                          child:
                          Icon(icon, color: Colors.white, size: 24)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
      const Color(0xFF4CAF50),
      const Color(0xFF2196F3),
      const Color(0xFF9C27B0),
      const Color(0xFFFF9800),
      const Color(0xFF00BCD4),
      const Color(0xFFE91E63),
      const Color(0xFF3F51B5),
    ];
    return colors[index % colors.length];
  }

  List<Color> _getCardGradient(int index) {
    final gradients = [
      [const Color(0xFF66BB6A), const Color(0xFF43A047)],
      [const Color(0xFF42A5F5), const Color(0xFF1976D2)],
      [const Color(0xFFAB47BC), const Color(0xFF7B1FA2)],
      [const Color(0xFFFFB74D), const Color(0xFFF57C00)],
      [const Color(0xFF26C6DA), const Color(0xFF0097A7)],
      [const Color(0xFFF06292), const Color(0xFFC2185B)],
      [const Color(0xFF5C6BC0), const Color(0xFF3949AB)],
    ];
    return gradients[index % gradients.length];
  }
}