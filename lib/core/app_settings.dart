import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  // Preferences
  String _language = "English";
  double _volume = 0.5;
  bool _highContrast = false;
  bool _largeText = false;

  // TTS instance (shared)
  final FlutterTts _tts = FlutterTts();

  // Getters
  String get language => _language;
  double get volume => _volume;
  bool get highContrast => _highContrast;
  bool get largeText => _largeText;
  FlutterTts get tts => _tts;

  // Load saved preferences
  Future<void> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString('language') ?? "English";
    _volume = prefs.getDouble('volume') ?? 0.5;
    _highContrast = prefs.getBool('contrast') ?? false;
    _largeText = prefs.getBool('largeText') ?? false;

    await _tts.setVolume(_volume);

    // ✅ Set TTS language based on saved preference
    String ttsLangCode = _language == 'Urdu' ? 'ur-PK' : 'en-US';
    await _tts.setLanguage(ttsLangCode);

    notifyListeners();
  }

  Future<void> setLanguage(String newLang) async {
    if (_language == newLang) return;
    _language = newLang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', newLang);

    // ✅ Set TTS voice language BEFORE speaking confirmation
    String ttsLangCode = newLang == 'Urdu' ? 'ur-PK' : 'en-US';
    await _tts.setLanguage(ttsLangCode);

    notifyListeners();

    // ✅ Speak confirmation in the NEW language
    String confirmMsg = newLang == 'Urdu'
        ? 'زبان تبدیل کر دی گئی اردو'
        : 'Language changed to $newLang';
    await _speak(confirmMsg);
  }

  Future<void> setVolume(double newVol) async {
    _volume = newVol;
    await _tts.setVolume(newVol);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('volume', newVol);
    notifyListeners();

    // Volume confirmation (keep in current language, but TTS language already set)
    String volumeMsg = _language == 'Urdu'
        ? 'آواز کی بلندی ${(newVol * 100).round()} فیصد مقرر کی گئی'
        : 'Volume set to ${(newVol * 100).round()} percent';
    await _speak(volumeMsg);
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('contrast', value);
    notifyListeners();

    String contrastMsg;
    if (_language == 'Urdu') {
      contrastMsg = value ? 'ہائی کنٹراسٹ فعال کر دیا گیا' : 'ہائی کنٹراسٹ غیر فعال کر دیا گیا';
    } else {
      contrastMsg = value ? "High contrast enabled" : "High contrast disabled";
    }
    await _speak(contrastMsg);
  }

  Future<void> setLargeText(bool value) async {
    _largeText = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('largeText', value);
    notifyListeners();

    String largeTextMsg;
    if (_language == 'Urdu') {
      largeTextMsg = value ? 'بڑا متن فعال کر دیا گیا' : 'بڑا متن غیر فعال کر دیا گیا';
    } else {
      largeTextMsg = value ? "Large text enabled" : "Large text disabled";
    }
    await _speak(largeTextMsg);
  }

  Future<void> _speak(String message) async {
    await _tts.stop();
    await Future.delayed(const Duration(milliseconds: 100));
    await _tts.speak(message);
  }
}