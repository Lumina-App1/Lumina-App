import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/app_localizations.dart';
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
  bool _ttsReady = false;

  @override
  void initState() {
    super.initState();
    _initTts();
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
      data: MediaQuery.of(context).copyWith(textScaleFactor: settings.largeText ? 1.5 : 1.0),
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
            decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, spreadRadius: 1)]),
            child: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor),
              onPressed: () async {
                String msg;
                if (widget.fromPage == FromPage.home) {
                  msg = strings.translate('returning_home');
                } else if (widget.fromPage == FromPage.about) {
                  msg = strings.translate('returning_about');
                } else {
                  msg = strings.translate('returning_help');
                }
                await _speak(msg);
                final bool isUrduLang = settings.language == 'Urdu';
                final int delayMs = isUrduLang ? 1300 : 1200;
                await Future.delayed(Duration(milliseconds: delayMs));
                if (mounted) Navigator.pop(context);
              },
            ),
          ),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: cardColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, spreadRadius: 1)]),
              child: IconButton(
                icon: Icon(Icons.help_outline_rounded, color: textColor),
                onPressed: () => _openPage(const HelpScreen(fromSettings: true), strings.translate('opening_help'), FromPage.help),
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
                              Text("${(settings.volume * 100).round()}%", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textColor)),
                              Icon(settings.volume == 0 ? Icons.volume_off_rounded : (settings.volume < 0.5 ? Icons.volume_down_rounded : Icons.volume_up_rounded), color: accentColor, size: 24),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: accentColor,
                              inactiveTrackColor: accentColor.withOpacity(0.2),
                              thumbColor: accentColor,
                              overlayColor: accentColor.withOpacity(0.1),
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 4),
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
                        gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)], begin: Alignment.centerLeft, end: Alignment.centerRight),
                        boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.3), blurRadius: 15, spreadRadius: 2, offset: const Offset(0, 4))],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => _openPage(const AboutScreen(), strings.translate('opening_about'), FromPage.about),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.info_outline_rounded, color: Colors.white, size: 24), const SizedBox(width: 12), Text(strings.translate('about_lumina'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: 0.5))])),
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

  Widget _languageCard({required String title, required IconData icon, required Color iconColor, required Color bgColor, required bool isUrdu, required AppSettings settings, required AppLocalizations strings, required Color textColor, required Color accentColor}) {
    return Container(
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 1, offset: const Offset(0, 2))], border: Border.all(color: const Color(0xFFE8F4FD), width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 22)),
                const SizedBox(width: 12),
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: settings.highContrast ? Colors.white : const Color(0xFF1A237E), letterSpacing: 0.3)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: accentColor.withOpacity(0.2), width: 1.5)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: settings.language,
                  isExpanded: true,
                  icon: Icon(Icons.arrow_drop_down_rounded, color: textColor),
                  dropdownColor: bgColor,
                  style: TextStyle(fontSize: 16, color: textColor, fontWeight: FontWeight.w500),
                  alignment: isUrdu ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                  items: [
                    DropdownMenuItem(
                      value: "English",
                      alignment: isUrdu ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                      child: SizedBox(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Icon(Icons.language, color: const Color(0xFF4CAF50), size: 20),
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
                      alignment: isUrdu ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                      child: SizedBox(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Icon(Icons.translate_rounded, color: const Color(0xFF2196F3), size: 20),
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
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(Icons.language, color: const Color(0xFF4CAF50), size: 20),
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
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Icon(Icons.translate_rounded, color: const Color(0xFF2196F3), size: 20),
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

  Widget _settingCard({required String title, required IconData icon, required Color iconColor, required Color bgColor, required bool isUrdu, required AppSettings settings, required Widget child}) {
    return Container(
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 1, offset: const Offset(0, 2))], border: Border.all(color: const Color(0xFFE8F4FD), width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 22)),
                const SizedBox(width: 12),
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: settings.highContrast ? Colors.white : const Color(0xFF1A237E), letterSpacing: 0.3)),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  // ** MODIFIED: For Urdu, switch on the left, icon on the right **
  Widget _switchCard({required String title, required String subtitle, required IconData icon, required Color iconColor, required bool value, required Color bgColor, required bool isUrdu, required AppSettings settings, required Function(bool) onChanged}) {
    return Container(
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 1, offset: const Offset(0, 2))], border: Border.all(color: const Color(0xFFE8F4FD), width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          textDirection: TextDirection.ltr, // keep LTR to avoid auto-flipping
          children: isUrdu
              ? [
            // Urdu layout: Switch (left) | Text column | Icon (right)
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
                  Text(
                    title,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: settings.highContrast ? Colors.white : const Color(0xFF1A237E)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: settings.highContrast ? Colors.white.withOpacity(0.8) : const Color(0xFF5C6BC0), fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
          ]
              : [
            // English layout: Icon (left) | Text column | Switch (right)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: settings.highContrast ? Colors.white : const Color(0xFF1A237E)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: settings.highContrast ? Colors.white.withOpacity(0.8) : const Color(0xFF5C6BC0), fontWeight: FontWeight.w400),
                  ),
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