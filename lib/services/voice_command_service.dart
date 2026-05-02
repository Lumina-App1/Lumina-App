import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:provider/provider.dart';
import '../core/navigation_service.dart';
import '../core/app_settings.dart';

class VoiceCommandService {
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final Connectivity _connectivity = Connectivity();
  BuildContext? _context;
  bool _isListening = false;
  bool _isPaused = false;
  bool _isAvailable = false;
  bool _isDestroyed = false;
  String _status = "Initializing...";
  Timer? _restartTimer;
  bool _isSpeakingError = false;
  int _networkRetryCount = 0;
  Timer? _networkRetryTimer;

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

    // Check if network is already off when app launches
    final initialConnectivity = await _connectivity.checkConnectivity();
    if (initialConnectivity.first == ConnectivityResult.none) {
      await _handleNoNetworkOnLaunch();
      return;
    }

    // Monitor network connectivity
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> result) {
      _handleConnectivityChange(result);
    });

    await _initSpeech();
  }

  Future<void> _handleNoNetworkOnLaunch() async {
    print('🌐 No network on launch — speaking error then closing app');
    _isDestroyed = true;

    await _tts.stop();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);

    final bool isUrdu = _isUrduMode();

    final String errorMsg = isUrdu
        ? "نیٹ ورک کنکشن موجود نہیں ہے۔ براہ کرم انٹرنیٹ سے جڑیں اور دوبارہ کوشش کریں"
        : "Network connection lost. Please connect to internet and try again.";

    final String closingMsg = isUrdu
        ? "ایپ بند ہو رہی ہے۔ خدا حافظ"
        : "Closing the app. Goodbye.";

    if (isUrdu) await _tts.setLanguage('ur-PK');

    await _tts.speak(errorMsg);
    await Future.delayed(const Duration(milliseconds: 7000));

    await _tts.speak(closingMsg);
    await Future.delayed(const Duration(milliseconds: 2800));

    await SystemNavigator.pop();
  }

  void updateContext(BuildContext context) {
    _context = context;
    print('🔄 Context updated');
  }

  void setScreenCommands(Function(String) handler) {
    _handlerStack.clear();
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

  bool _isUrduMode() {
    try {
      if (_context == null) return false;
      final settings = Provider.of<AppSettings>(_context!, listen: false);
      return settings.language == 'Urdu';
    } catch (_) {
      return false;
    }
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
              _isAvailable &&
              !_isSpeakingError) {
            _scheduleRestart();
          }
        },
        onError: (error) {
          print('❌ Speech error: ${error.errorMsg}');
          _isListening = false;

          // Handle speech recognition errors silently
          if (error.errorMsg.contains('network') ||
              error.errorMsg.contains('connection')) {
            _handleNetworkError();
          } else if (!_isPaused && !_isDestroyed && _isAvailable) {
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
      if (!_isPaused && !_isDestroyed && _isAvailable && !_speech.isListening && !_isSpeakingError) {
        _startListening();
      }
    });
  }

  void _startListening() {
    if (_isListening || _isPaused || !_isAvailable || _isDestroyed || _isSpeakingError) {
      print(
          'Cannot start: isListening=$_isListening, isPaused=$_isPaused, isAvailable=$_isAvailable, isDestroyed=$_isDestroyed, isSpeakingError=$_isSpeakingError');
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
            // check exit FIRST before routing to screen handlers
            if (_isExitCommand(command.toLowerCase())) {
              _handleExit();
            } else {
              _processCommand(command.toLowerCase());
            }
          }
          _isListening = false;
          if (!_isPaused && !_isDestroyed && _isAvailable && !_isSpeakingError) {
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

  // Exit detection
  bool _isExitCommand(String command) {
    return command.contains('exit from app') ||
        command.contains('close the app') ||
        command.contains('exit app') ||
        command.contains('exit') ||
        command.contains('app band kar doo') ||
        command.contains('app band kardo') ||
        command.contains('app band kar do') ||
        command.contains('app close kar doo') ||
        command.contains('app close kardo') ||
        command.contains('app close kar do') ||
        command.contains('app exit kar do') ||
        command.contains('app exit kardo') ||
        command.contains('band kar doo') ||
        command.contains('band kardo');
  }

  Future<void> _handleExit() async {
    print('🚪 EXIT command — closing app');
    _isDestroyed = true;
    _restartTimer?.cancel();
    if (_speech.isListening) {
      await _speech.stop();
    }

    await _tts.stop();
    await _tts.speak('Closing the app. Back to your phone home screen.');

    await Future.delayed(const Duration(milliseconds: 2800));
    await SystemNavigator.pop();
  }

  // Handle network errors with voice feedback
  void _handleConnectivityChange(List<ConnectivityResult> results) {
    final hasNetwork = results.first != ConnectivityResult.none;

    if (!hasNetwork && !_isSpeakingError) {
      final bool isUrdu = _isUrduMode();
      final String errorMsg = isUrdu
          ? "نیٹ ورک کنکشن ختم ہو گیا۔ براہ کرم اپنا انٹرنیٹ چیک کریں اور دوبارہ کوشش کریں"
          : "Network connection lost. Please check your internet and try again.";
      _speakError(errorMsg);
    } else if (hasNetwork && _isAvailable && !_isListening && !_isSpeakingError) {
      _scheduleRestart();
    }
  }

  void _handleNetworkError() async {
    if (_isSpeakingError) return;

    _isSpeakingError = true;
    _isPaused = true;

    if (_speech.isListening) {
      _speech.stop();
    }
    _isListening = false;

    final bool isUrdu = _isUrduMode();
    String errorMsg = isUrdu
        ? "نیٹ ورک کنکشن میں مسئلہ ہے۔ براہ کرم اپنا انٹرنیٹ چیک کریں اور دوبارہ کوشش کریں"
        : "Network connection issue. Please check your internet and try again";

    await _tts.stop();
    await _tts.speak(errorMsg);

    _tts.setCompletionHandler(() async {
      _isSpeakingError = false;
      _isPaused = false;

      await Future.delayed(const Duration(seconds: 3));
      if (_isAvailable && !_isDestroyed && !_isSpeakingError) {
        _scheduleRestart();
      }
    });
  }

  void _speakError(String message) async {
    if (_isSpeakingError) return;

    _isSpeakingError = true;
    _isPaused = true;

    if (_speech.isListening) {
      _speech.stop();
    }
    _isListening = false;

    await _tts.stop();
    await _tts.speak(message);

    _tts.setCompletionHandler(() {
      _isSpeakingError = false;
      _isPaused = false;
      if (_isAvailable && !_isDestroyed) {
        _scheduleRestart();
      }
    });
  }

  void _processCommand(String command) {
    // Top of stack = current screen handler — always wins
    if (_handlerStack.isNotEmpty) {
      print('🎯 Routing to screen handler: "$command"');
      _handlerStack.last(command);
      return;
    }

    // Global fallback — only runs when no screen handler is registered
    final navigatorState = navigatorKey.currentState;
    if (navigatorState == null) {
      print('❌ Navigator not ready');
      return;
    }

    print('🔍 Processing global command: "$command"');

    try {
      if (command.contains('object') || command.contains('detection')) {
        print('✅ MATCH: Object Detection');
        _speak('Opening object detection');
        Future.delayed(const Duration(milliseconds: 500), () {
          navigatorKey.currentState?.pushNamed('/detection');
        });
      }
      else if (command.contains('target') || command.contains('search')) {
        print('✅ MATCH: Target Search');
        _speak('Opening target search');
        Future.delayed(const Duration(milliseconds: 500), () {
          navigatorKey.currentState?.pushNamed('/target');
        });
      }
      else if (command.contains('setting')) {
        print('✅ MATCH: Settings');
        _speak('Opening settings');
        Future.delayed(const Duration(milliseconds: 500), () {
          navigatorKey.currentState?.pushNamed('/settings');
        });
      }
      else if (command.contains('help')) {
        print('✅ MATCH: Help');
        _speak('Opening help');
        Future.delayed(const Duration(milliseconds: 500), () {
          navigatorKey.currentState?.pushNamed('/help');
        });
      }
      else if (command.contains('back')) {
        print('✅ MATCH: Back');
        if (navigatorState.canPop()) {
          _speak('Going back');
          Future.delayed(const Duration(milliseconds: 300), () {
            navigatorKey.currentState?.pop();
          });
        }
      }
      else if (command.contains('home') ||
          command.contains('return to home') ||
          command.contains('return to home screen') ||
          command == 'home screen') {
        print('✅ MATCH: Home');
        _speak('Going home');
        Future.delayed(const Duration(milliseconds: 500), () {
          navigatorKey.currentState?.popUntil((route) => route.isFirst);
        });
      }
      else {
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
    print('▶️ Voice service resumed');
    _isPaused = false;
    _isSpeakingError = false; // ← ADD THIS LINE
    if (_isAvailable && !_isDestroyed && !_speech.isListening) {
      _scheduleRestart();
    }
  }

  void stop() {
    print('🛑 Voice service stopped');
    _isDestroyed = true;
    _isPaused = true;
    _isListening = false;
    _restartTimer?.cancel();
    _networkRetryTimer?.cancel();
    if (_speech.isListening) {
      _speech.stop();
    }
  }

  bool get isActive => !_isPaused && _isAvailable && !_isDestroyed && !_isSpeakingError;
  String get status => _status;
}