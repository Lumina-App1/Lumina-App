import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings _instance = AppSettings._internal();
  factory AppSettings() => _instance;
  AppSettings._internal();

  String _language = "English";
  double _volume = 0.5;
  bool _highContrast = false;
  bool _largeText = false;

  final FlutterTts _tts = FlutterTts();

  String get language => _language;
  double get volume => _volume;
  bool get highContrast => _highContrast;
  bool get largeText => _largeText;
  FlutterTts get tts => _tts;

  Future<void> loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString('language') ?? "English";
    _volume = prefs.getDouble('volume') ?? 0.5;
    _highContrast = prefs.getBool('contrast') ?? false;
    _largeText = prefs.getBool('largeText') ?? false;

    final String ttsLangCode = _language == 'Urdu' ? 'ur-PK' : 'en-US';
    await _tts.setLanguage(ttsLangCode);
    await _tts.setVolume(_volume);
    await _tts.setSpeechRate(0.5);

    notifyListeners();
  }

  Future<void> setLanguage(String newLang) async {
    if (_language == newLang) return;
    _language = newLang;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', newLang);

    final String ttsLangCode = newLang == 'Urdu' ? 'ur-PK' : 'en-US';
    await _tts.setLanguage(ttsLangCode);
    await _tts.setSpeechRate(0.5);

    notifyListeners();

    final String confirmMsg = newLang == 'Urdu'
        ? 'زبان اردو میں تبدیل کر دی گئی ہے'
        : 'Language changed to $newLang';
    await _speak(confirmMsg);
  }

  Future<void> setVolume(double newVol) async {
    _volume = newVol;
    await _tts.setVolume(newVol);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('volume', newVol);

    notifyListeners();

    final String volumeMsg = _language == 'Urdu'
        ? 'آواز کی بلندی ${(newVol * 100).round()} فیصد مقرر کی گئی'
        : 'Volume set to ${(newVol * 100).round()} percent';
    await _speak(volumeMsg);
  }

  Future<void> setHighContrast(bool value) async {
    _highContrast = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('contrast', value);

    notifyListeners();

    final String msg = _language == 'Urdu'
        ? (value ? 'ہائی کنٹراسٹ آن کر دیا گیا' : 'ہائی کنٹراسٹ آف کر دیا گیا')
        : (value ? 'High contrast enabled' : 'High contrast disabled');
    await _speak(msg);
  }

  Future<void> setLargeText(bool value) async {
    _largeText = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('largeText', value);

    notifyListeners();

    final String msg = _language == 'Urdu'
        ? (value ? 'ٹیکسٹ بڑا کر دیا گیا' : 'ٹیکسٹ چھوٹا کر دیا گیا')
        : (value ? 'Large text enabled' : 'Large text disabled');
    await _speak(msg);
  }

  Future<void> _speak(String message) async {
    await _tts.stop();
    await Future.delayed(const Duration(milliseconds: 100));
    await _tts.speak(message);
  }
}