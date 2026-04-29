import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../core/app_settings.dart';
import '../core/app_localizations.dart';
import '../services/voice_command_service.dart';
import 'about_screen.dart';
import 'help_screen.dart';

enum FromPage { home, about, help }

class SettingsScreen extends StatefulWidget {
  final FromPage fromPage;
  const SettingsScreen({super.key, this.fromPage = FromPage.home});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with RouteAware {
  bool _ttsReady = false;
  late VoiceCommandService _voiceService;

  @override
  void initState() {
    super.initState();
    _voiceService = VoiceCommandService();
    _initTts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
    _voiceService.updateContext(context);
    _voiceService.setScreenCommands(_handleVoiceCommand);
  }

  @override
  void didPopNext() {
    _voiceService.updateContext(context);
    _voiceService.setScreenCommands(_handleVoiceCommand);
    _voiceService.resume();
    _announceSettings();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _voiceService.clearScreenCommands();
    final settings = Provider.of<AppSettings>(context, listen: false);
    settings.tts.stop();
    super.dispose();
  }

  void _handleVoiceCommand(String command) {
    print('⚙️ Settings command: "$command"');
    final settings = Provider.of<AppSettings>(context, listen: false);
    final strings = AppLocalizations.of(context);

    // --- Language ---
    if (command.contains('english') || command.contains('set language english')) {
      if (settings.language != 'English') {
        settings.setLanguage('English');
        _speak('Language set to English');
      } else {
        _speak('Language is already English');
      }

    } else if (command.contains('urdu') || command.contains('اردو')) {
      if (settings.language != 'Urdu') {
        settings.setLanguage('Urdu');
        _speak('زبان اردو پر سیٹ کر دی گئی');
      } else {
        _speak('زبان پہلے سے اردو ہے');
      }

      // --- Volume ---
    } else if (command.contains('volume up') ||
        command.contains('increase volume') ||
        command.contains('louder')) {
      double newVol = (settings.volume + 0.2).clamp(0.0, 1.0);
      settings.setVolume(newVol);
      _speak('Volume increased to ${(newVol * 100).round()} percent');

    } else if (command.contains('volume down') ||
        command.contains('decrease volume') ||
        command.contains('lower volume') ||
        command.contains('quieter')) {
      double newVol = (settings.volume - 0.2).clamp(0.0, 1.0);
      settings.setVolume(newVol);
      _speak('Volume decreased to ${(newVol * 100).round()} percent');

    } else if (command.contains('maximum volume') ||
        command.contains('full volume') ||
        command.contains('max volume')) {
      settings.setVolume(1.0);
      _speak('Volume set to maximum');

    } else if (command.contains('minimum volume') ||
        command.contains('mute') ||
        command.contains('silent')) {
      settings.setVolume(0.0);
      _speak('Volume muted');

      // --- High Contrast ---
    } else if (command.contains('high contrast on') ||
        command.contains('enable high contrast') ||
        command.contains('turn on high contrast') ||
        command.contains('contrast on')) {
      if (!settings.highContrast) {
        settings.setHighContrast(true);
        _speak('High contrast enabled');
      } else {
        _speak('High contrast is already on');
      }

    } else if (command.contains('high contrast off') ||
        command.contains('disable high contrast') ||
        command.contains('turn off high contrast') ||
        command.contains('contrast off')) {
      if (settings.highContrast) {
        settings.setHighContrast(false);
        _speak('High contrast disabled');
      } else {
        _speak('High contrast is already off');
      }

    } else if (command.contains('high contrast') || command.contains('contrast')) {
      // Toggle if user just says "high contrast"
      settings.setHighContrast(!settings.highContrast);
      _speak(settings.highContrast ? 'High contrast enabled' : 'High contrast disabled');

      // --- Large Text ---
    } else if (command.contains('large text on') ||
        command.contains('enable large text') ||
        command.contains('turn on large text') ||
        command.contains('bigger text') ||
        command.contains('increase text')) {
      if (!settings.largeText) {
        settings.setLargeText(true);
        _speak('Large text enabled');
      } else {
        _speak('Large text is already on');
      }

    } else if (command.contains('large text off') ||
        command.contains('disable large text') ||
        command.contains('turn off large text') ||
        command.contains('smaller text') ||
        command.contains('decrease text')) {
      if (settings.largeText) {
        settings.setLargeText(false);
        _speak('Large text disabled');
      } else {
        _speak('Large text is already off');
      }

    } else if (command.contains('large text') || command.contains('text size')) {
      // Toggle if user just says "large text"
      settings.setLargeText(!settings.largeText);
      _speak(settings.largeText ? 'Large text enabled' : 'Large text disabled');

      // --- Navigation ---
    } else if (command.contains('about')) {
      _openPage(
        const AboutScreen(),
        'Opening about page',
        FromPage.about,
      );

    } else if (command.contains('help')) {
      _openPage(
        const HelpScreen(fromSettings: true),
        'Opening help page',
        FromPage.help,
      );

    } else if (command.contains('home') || command.contains('back')) {
      _goBack();

      // --- Status announcements ---
    } else if (command.contains('current settings') ||
        command.contains('what are the settings') ||
        command.contains('read settings')) {
      _announceCurrentSettings();

    } else {
      print('❌ No settings match for: "$command"');
    }
  }

  void _announceCurrentSettings() {
    final settings = Provider.of<AppSettings>(context, listen: false);
    String status =
        'Current settings. Language: ${settings.language}. '
        'Volume: ${(settings.volume * 100).round()} percent. '
        'High contrast: ${settings.highContrast ? "on" : "off"}. '
        'Large text: ${settings.largeText ? "on" : "off"}.';
    _speak(status);
  }

  Future<void> _initTts() async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    await settings.tts.setSpeechRate(0.45);
    await settings.tts.setPitch(1.0);
    await settings.tts.setVolume(settings.volume);
    _ttsReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceSettings();
    });
  }

  Future<void> _speak(String message) async {
    if (!_ttsReady) return;
    final settings = Provider.of<AppSettings>(context, listen: false);
    await settings.tts.stop();
    await Future.delayed(const Duration(milliseconds: 100));
    await settings.tts.speak(message);
  }

  Future<void> _announceSettings() async {
    if (!_ttsReady) return;
    final strings = AppLocalizations.of(context);
    String backMessage;
    switch (widget.fromPage) {
      case FromPage.about:
        backMessage = strings.translate('about_announce');
        break;
      case FromPage.help:
        backMessage = strings.translate('help_announce');
        break;
      default:
        backMessage = strings.translate('settings_announce');
    }
    await _speak(backMessage);
  }

  Future<void> _openPage(Widget page, String message, FromPage from) async {
    await _speak(message);
    await Future.delayed(const Duration(milliseconds: 1200));
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));

    final settings = Provider.of<AppSettings>(context, listen: false);
    final bool isUrdu = settings.language == 'Urdu';
    final int delayMs = isUrdu ? 1300 : 800;
    await Future.delayed(Duration(milliseconds: delayMs));
    await settings.tts.stop();
    await Future.delayed(const Duration(milliseconds: 200));
    _announceSettings();
  }

  Future<void> _goBack() async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final strings = AppLocalizations.of(context);
    String msg;
    if (widget.fromPage == FromPage.home) {
      msg = strings.translate('returning_home');
    } else if (widget.fromPage == FromPage.about) {
      msg = strings.translate('returning_about');
    } else {
      msg = strings.translate('returning_help');
    }
    await _speak(msg);
    final bool isUrdu = settings.language == 'Urdu';
    final int delayMs = isUrdu ? 1300 : 1200;
    await Future.delayed(Duration(milliseconds: delayMs));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    final strings = AppLocalizations.of(context);
    final bool isUrdu = settings.language == 'Urdu';
    return _buildContent(settings, strings, isUrdu);
  }

  Widget _buildContent(AppSettings settings, AppLocalizations strings, bool isUrdu) {
    final bgColor = settings.highContrast ? Colors.black : const Color(0xFFF8FAFD);
    final textColor = settings.highContrast ? Colors.white : const Color(0xFF1A237E);
    final cardColor = settings.highContrast ? const Color(0xFF1E1E1E) : Colors.white;
    final accentColor = const Color(0xFF00E5FF);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
          textScaleFactor: settings.largeText ? 1.5 : 1.0),
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          elevation: 0,
          centerTitle: true,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: bgColor.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
            ),
            child: Text(
              strings.translate('settings_title'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: settings.highContrast ? Colors.white : Colors.black,
              ),
            ),
          ),
          leading: Container(
            margin: const EdgeInsets.only(left: 10),
            decoration: BoxDecoration(
              color: cardColor,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, spreadRadius: 1)],
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
              onPressed: _goBack,
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: cardColor,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, spreadRadius: 1)],
              ),
              child: IconButton(
                icon: Icon(Icons.help_outline_rounded, color: textColor),
                onPressed: () => _openPage(
                  const HelpScreen(fromSettings: true),
                  strings.translate('opening_help'),
                  FromPage.help,
                ),
              ),
            ),
          ],
        ),
        body: Directionality(
          textDirection: isUrdu ? TextDirection.rtl : TextDirection.ltr,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Voice commands hint box
                    Container(
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.mic, color: accentColor, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Voice Commands',
                                style: TextStyle(
                                  color: accentColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _voiceHint('"volume up" / "volume down"'),
                          _voiceHint('"high contrast on" / "high contrast off"'),
                          _voiceHint('"large text on" / "large text off"'),
                          _voiceHint('"set language English" / "Urdu"'),
                          _voiceHint('"about", "help", "home"'),
                          _voiceHint('"read settings" for current status'),
                        ],
                      ),
                    ),
                    _languageCard(
                      title: strings.translate('language'),
                      icon: Icons.language_rounded,
                      iconColor: const Color(0xFF4CAF50),
                      bgColor: cardColor,
                      isUrdu: isUrdu,
                      settings: settings,
                      strings: strings,
                      textColor: textColor,
                      accentColor: accentColor,
                    ),
                    const SizedBox(height: 16),
                    _settingCard(
                      title: strings.translate('volume'),
                      icon: Icons.volume_up_rounded,
                      iconColor: const Color(0xFF2196F3),
                      bgColor: cardColor,
                      isUrdu: isUrdu,
                      settings: settings,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "${(settings.volume * 100).round()}%",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: textColor),
                              ),
                              Icon(
                                settings.volume == 0
                                    ? Icons.volume_off_rounded
                                    : (settings.volume < 0.5
                                    ? Icons.volume_down_rounded
                                    : Icons.volume_up_rounded),
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
                                  enabledThumbRadius: 10, elevation: 4),
                              trackHeight: 6,
                            ),
                            child: Slider(
                              value: settings.volume,
                              onChanged: (v) => settings.setVolume(v),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _switchCard(
                      title: strings.translate('high_contrast'),
                      subtitle: strings.translate('high_contrast_sub'),
                      icon: Icons.contrast_rounded,
                      iconColor: const Color(0xFFFF9800),
                      value: settings.highContrast,
                      bgColor: cardColor,
                      isUrdu: isUrdu,
                      settings: settings,
                      onChanged: (v) => settings.setHighContrast(v),
                    ),
                    const SizedBox(height: 16),
                    _switchCard(
                      title: strings.translate('large_text'),
                      subtitle: strings.translate('large_text_sub'),
                      icon: Icons.text_increase_rounded,
                      iconColor: const Color(0xFF9C27B0),
                      value: settings.largeText,
                      bgColor: cardColor,
                      isUrdu: isUrdu,
                      settings: settings,
                      onChanged: (v) => settings.setLargeText(v),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1A237E).withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => _openPage(
                            const AboutScreen(),
                            strings.translate('opening_about'),
                            FromPage.about,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 18),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    color: Colors.white, size: 24),
                                const SizedBox(width: 12),
                                Text(
                                  strings.translate('about_lumina'),
                                  style: const TextStyle(
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
      ),
    );
  }

  Widget _voiceHint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.chevron_right, color: Colors.white54, size: 14),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
                color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _languageCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool isUrdu,
    required AppSettings settings,
    required AppLocalizations strings,
    required Color textColor,
    required Color accentColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 1, offset: const Offset(0, 2))],
        border: Border.all(color: const Color(0xFFE8F4FD), width: 1),
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
                  decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: settings.highContrast ? Colors.white : const Color(0xFF1A237E),
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accentColor.withOpacity(0.2), width: 1.5),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: settings.language,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: textColor),
                  dropdownColor: bgColor,
                  style: TextStyle(
                      fontSize: 16, color: textColor, fontWeight: FontWeight.w500),
                  alignment: isUrdu
                      ? AlignmentDirectional.centerEnd
                      : AlignmentDirectional.centerStart,
                  items: [
                    DropdownMenuItem(
                      value: "English",
                      alignment: isUrdu
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: SizedBox(
                        width: double.infinity,
                        child: Row(
                          children: [
                            const Icon(Icons.language, color: Color(0xFF4CAF50), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                strings.translate('english'),
                                textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: "Urdu",
                      alignment: isUrdu
                          ? AlignmentDirectional.centerEnd
                          : AlignmentDirectional.centerStart,
                      child: SizedBox(
                        width: double.infinity,
                        child: Row(
                          children: [
                            const Icon(Icons.translate_rounded, color: Color(0xFF2196F3), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                strings.translate('urdu'),
                                textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) async {
                    if (val != null && val != settings.language) {
                      await settings.setLanguage(val);
                    }
                  },
                  selectedItemBuilder: (context) => [
                    SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          const Icon(Icons.language, color: Color(0xFF4CAF50), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              strings.translate('english'),
                              textAlign: isUrdu ? TextAlign.right : TextAlign.left,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          const Icon(Icons.translate_rounded, color: Color(0xFF2196F3), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              strings.translate('urdu'),
                              textAlign: isUrdu ? TextAlign.right : TextAlign.left,
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
    );
  }

  Widget _settingCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required bool isUrdu,
    required AppSettings settings,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 1, offset: const Offset(0, 2))],
        border: Border.all(color: const Color(0xFFE8F4FD), width: 1),
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
                  decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: settings.highContrast ? Colors.white : const Color(0xFF1A237E),
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

  Widget _switchCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool value,
    required Color bgColor,
    required bool isUrdu,
    required AppSettings settings,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 1, offset: const Offset(0, 2))],
        border: Border.all(color: const Color(0xFFE8F4FD), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          textDirection: TextDirection.ltr,
          children: isUrdu
              ? [
            Switch.adaptive(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF00E5FF),
              activeTrackColor: const Color(0xFF00E5FF).withOpacity(0.5),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: settings.highContrast
                              ? Colors.white
                              : const Color(0xFF1A237E))),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13,
                          color: settings.highContrast
                              ? Colors.white.withOpacity(0.8)
                              : const Color(0xFF5C6BC0),
                          fontWeight: FontWeight.w400)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
          ]
              : [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: settings.highContrast
                              ? Colors.white
                              : const Color(0xFF1A237E))),
                  const SizedBox(height: 4),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 13,
                          color: settings.highContrast
                              ? Colors.white.withOpacity(0.8)
                              : const Color(0xFF5C6BC0),
                          fontWeight: FontWeight.w400)),
                ],
              ),
            ),
            const SizedBox(width: 16),
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