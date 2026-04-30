import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/navigation_service.dart';

class VoiceCommandService {
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  BuildContext? _context;
  bool _isListening = false;
  bool _isPaused = false;
  bool _isAvailable = false;
  bool _isDestroyed = false;
  String _status = "Initializing...";
  Timer? _restartTimer;

  // Stack-based handler — top of stack is always the active screen
  final List<Function(String)> _handlerStack = [];

  Future<void> init(BuildContext context) async {
    _context = context;
    _isDestroyed = false;

    print('📱 Initializing VoiceCommandService...');

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
      if (!status.isGranted) {
        _status = "Microphone permission denied";
        print('❌ Microphone permission denied');
        return;
      }
    }

    print('✅ Microphone permission granted');
    await _initSpeech();
  }

  void updateContext(BuildContext context) {
    _context = context;
    print('🔄 Context updated');
  }

  /// Push a screen-specific handler. Top of stack = active handler.
  void setScreenCommands(Function(String) handler) {
    _handlerStack.remove(handler);
    _handlerStack.add(handler);
    print('📌 Handler pushed — stack depth: ${_handlerStack.length}');
  }

  /// Pop the screen handler when leaving the screen.
  void clearScreenCommands() {
    if (_handlerStack.isNotEmpty) {
      _handlerStack.removeLast();
    }
    print('🗑️ Handler popped — stack depth: ${_handlerStack.length}');
  }

  Future<void> _initSpeech() async {
    try {
      _status = "Initializing...";
      print('🔄 Initializing speech recognition...');

      bool available = await _speech.initialize(
        onStatus: (status) {
          print('📢 Speech status: $status');
          _status = status;
          if ((status == 'notListening' || status == 'done') &&
              !_isPaused &&
              !_isDestroyed &&
              _isAvailable) {
            _scheduleRestart();
          }
        },
        onError: (error) {
          print('❌ Speech error: ${error.errorMsg}');
          _isListening = false;
          if (!_isPaused && !_isDestroyed && _isAvailable) {
            _scheduleRestart();
          }
        },
      );

      if (available) {
        _isAvailable = true;
        _status = "Listening...";
        print('✅ Speech recognition ready!');
        _startListening();
      } else {
        _isAvailable = false;
        _status = "Not available";
        print('❌ Speech recognition not available');
      }
    } catch (e) {
      print('❌ Exception: $e');
      _isAvailable = false;
      _status = "Error";
    }
  }

  void _scheduleRestart() {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 300), () {
      if (!_isPaused && !_isDestroyed && _isAvailable && !_speech.isListening) {
        _startListening();
      }
    });
  }

  void _startListening() {
    if (_isListening || _isPaused || !_isAvailable || _isDestroyed) {
      print(
          'Cannot start: isListening=$_isListening, isPaused=$_isPaused, isAvailable=$_isAvailable, isDestroyed=$_isDestroyed');
      return;
    }

    _isListening = true;
    print('🎤 STARTED LISTENING - Speak now!');

    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          final String command = result.recognizedWords.trim();
          if (command.isNotEmpty) {
            print('🎤 RECOGNIZED: "$command"');
            _processCommand(command.toLowerCase());
          }
          _isListening = false;
          if (!_isPaused && !_isDestroyed && _isAvailable) {
            _scheduleRestart();
          }
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      partialResults: false,
      localeId: 'en_US',
      cancelOnError: false,
    );
  }

  void _processCommand(String command) {
    // Top of stack = current screen handler — always wins
    if (_handlerStack.isNotEmpty) {
      print('🎯 Routing to screen handler: "$command"');
      _handlerStack.last(command);
      return;
    }

    // Global fallback — only runs on Home screen (no handler registered)
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) {
      print('❌ Navigator not ready');
      return;
    }

    print('🔍 Processing command: "$command"');

    try {
      if (command.contains('object') || command.contains('detection')) {
        print('✅ MATCH: Object Detection');
        _speak('Opening object detection');
        Future.delayed(const Duration(milliseconds: 500), () {
          navigatorKey.currentState?.pushNamed('/detection');
        });
      } else if (command.contains('target') || command.contains('search')) {
        print('✅ MATCH: Target Search');
        _speak('Opening target search');
        Future.delayed(const Duration(milliseconds: 500), () {
          navigatorKey.currentState?.pushNamed('/target');
        });
      } else if (command.contains('setting')) {
        print('✅ MATCH: Settings');
        _speak('Opening settings');
        Future.delayed(const Duration(milliseconds: 500), () {
          navigatorKey.currentState?.pushNamed('/settings');
        });
      } else if (command.contains('help')) {
        print('✅ MATCH: Help');
        _speak('Opening help');
        Future.delayed(const Duration(milliseconds: 500), () {
          navigatorKey.currentState?.pushNamed('/help');
        });
      } else if (command.contains('back')) {
        print('✅ MATCH: Back');
        if (navigatorState.canPop()) {
          _speak('Going back to settings');
          Future.delayed(const Duration(milliseconds: 300), () {
            navigatorKey.currentState?.pop();
          });
        }
      } else if (command.contains('home')) {
        print('✅ MATCH: Home');
        _speak('Going home');
        Future.delayed(const Duration(milliseconds: 500), () {
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
        });
      } else {
        print('❌ No match for: "$command"');
      }
    } catch (e) {
      print('❌ Error processing: $e');
    }
  }

  Future<void> _speak(String message) async {
    print('🔊 Speaking: "$message"');
    _isPaused = true;
    await _tts.stop();
    await _tts.speak(message);
    _tts.setCompletionHandler(() {
      print('🔊 TTS done, resuming listening');
      _isPaused = false;
      if (_isAvailable && !_isDestroyed) {
        _scheduleRestart();
      }
    });
  }

  void pause() {
    print('⏸️ Voice service paused');
    _isPaused = true;
    _restartTimer?.cancel();
    if (_speech.isListening) {
      _speech.stop();
    }
    _isListening = false;
  }

  void resume() {
    if (_isPaused) {
      print('▶️ Voice service resumed');
      _isPaused = false;
      if (_isAvailable && !_isDestroyed && !_speech.isListening) {
        _scheduleRestart();
      }
    }
  }

  void stop() {
    print('🛑 Voice service stopped');
    _isDestroyed = true;
    _isPaused = true;
    _isListening = false;
    _restartTimer?.cancel();
    if (_speech.isListening) {
      _speech.stop();
    }
  }

  bool get isActive => !_isPaused && _isAvailable && !_isDestroyed;
  String get status => _status;
}