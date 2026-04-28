import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceCommandService {
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  BuildContext? _context;
  bool _isListening = false;
  bool _isPaused = false;
  String _lastCommand = '';

  void init(BuildContext context) {
    _context = context;
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('Speech status: $status'),
      onError: (error) => print('Speech error: $error'),
    );
    if (available) {
      _listen();
    } else {
      print('Speech recognition not available');
    }
  }

  void pause() {
    _isPaused = true;
    if (_speech.isListening) {
      _speech.stop();
    }
  }

  void resume() {
    if (_isPaused) {
      _isPaused = false;
      _listen();
    }
  }

  void _listen() {
    if (_isListening || _isPaused) return;
    _isListening = true;
    _speech.listen(
      onResult: (result) {
        String command = result.recognizedWords.toLowerCase().trim();
        if (command.isNotEmpty && command != _lastCommand) {
          _lastCommand = command;
          _processCommand(command);
        }
        _isListening = false;
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_isPaused) _listen();
        });
      },
      listenFor: Duration(seconds: 10),
      pauseFor: Duration(seconds: 3),
      partialResults: false,
    );
  }

  void _processCommand(String command) {
    print('Voice command: $command');
    final navigatorState = Navigator.of(_context!);
    final currentRoute = ModalRoute.of(_context!)?.settings.name;

    if (command.contains('object detection') || command.contains('start detection')) {
      if (currentRoute != '/detection') {
        _speak('Opening object detection');
        navigatorState.pushNamed('/detection');
      }
    } else if (command.contains('target search') || command.contains('find')) {
      if (currentRoute != '/target') {
        _speak('Opening target search');
        navigatorState.pushNamed('/target');
      }
    } else if (command.contains('settings')) {
      if (currentRoute != '/settings') {
        _speak('Opening settings');
        navigatorState.pushNamed('/settings');
      }
    } else if (command.contains('help')) {
      if (currentRoute != '/help') {
        _speak('Opening help');
        navigatorState.pushNamed('/help');
      }
    } else if (command.contains('back') || command.contains('go back')) {
      if (navigatorState.canPop()) {
        _speak('Going back');
        navigatorState.pop();
      }
    } else if (command.contains('home')) {
      _speak('Going home');
      navigatorState.popUntil((route) => route.isFirst);
    }
  }

  Future<void> _speak(String message) async {
    await _tts.stop();
    await _tts.speak(message);
  }

  void stop() {
    _isListening = false;
    _isPaused = false;
    if (_speech.isListening) {
      _speech.stop();
    }
  }
}