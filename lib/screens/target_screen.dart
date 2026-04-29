import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:image/image.dart' as img;
import 'home_screen.dart';
import '../main.dart';
import '../core/app_settings.dart';
import '../core/app_localizations.dart';
import '../core/app_config.dart';
import '../services/voice_command_service.dart';

late List<CameraDescription> cameras;

class TargetScreen extends StatefulWidget {
  const TargetScreen({super.key});

  @override
  State<TargetScreen> createState() => _TargetScreenState();
}

class _TargetScreenState extends State<TargetScreen> with RouteAware {
  CameraController? _controller;
  bool isPaused = false;
  bool _isProcessing = false;
  String _currentTarget = "";
  bool _isListeningForTarget = false;

  final String _backendUrl = AppConfig.backendUrl;
  final SpeechToText _speechToText = SpeechToText();

  int _frameCounter = 0;
  final int _processEveryNFrames = 15;

  late VoiceCommandService _voiceService;

  @override
  void initState() {
    super.initState();
    _voiceService = VoiceCommandService();
    _initializeCamera();
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
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _voiceService.clearScreenCommands();
    _controller?.stopImageStream();
    _controller?.dispose();
    _speechToText.stop();
    final settings = Provider.of<AppSettings>(context, listen: false);
    settings.tts.stop();
    super.dispose();
  }

  // Handle all voice commands for this screen
  void _handleVoiceCommand(String command) {
    print('🎯 Target screen command: "$command"');

    // If currently listening for target, ignore nav commands
    if (_isListeningForTarget) return;

    if (command.contains('stop') || command.contains('back') || command.contains('home')) {
      _stopCamera();
    } else if (command.contains('pause')) {
      if (!isPaused) _pauseResumeCamera();
    } else if (command.contains('resume') || command.contains('continue')) {
      if (isPaused) _pauseResumeCamera();
    } else if (command.contains('reset') || command.contains('new target') || command.contains('change target')) {
      _resetSearch();
    } else if (command.contains('find ') ||
        command.contains('search for ') ||
        command.contains('look for ') ||
        command.contains('detect ')) {
      // User said "find X" directly — extract target from command
      String target = command
          .replaceAll('find ', '')
          .replaceAll('search for ', '')
          .replaceAll('look for ', '')
          .replaceAll('detect ', '')
          .trim();
      if (target.isNotEmpty) {
        _setTargetDirectly(target);
      }
    } else if (command.contains('set target') || command.contains('new search')) {
      _listenForTargetObject();
    }
  }

  // Set target directly from voice without extra mic session
  void _setTargetDirectly(String target) {
    setState(() {
      _currentTarget = target;
    });
    _speak('Searching for $target');
    print('✅ Target set directly from voice: "$target"');
  }

  Future<void> _speak(String text) async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    await settings.tts.stop();
    await settings.tts.speak(text);
  }

  Future<String?> _convertImageToBase64(CameraImage image) async {
    try {
      final int width = image.width;
      final int height = image.height;

      final Plane yPlane = image.planes[0];
      final Plane uPlane = image.planes[1];
      final Plane vPlane = image.planes[2];

      final List<int> rgbData = List.filled(width * height * 3, 0);

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int yIndex = y * width + x;
          final int uvIndex = (y ~/ 2) * (width ~/ 2) + (x ~/ 2);

          final int yVal = yPlane.bytes[yIndex] & 0xFF;
          final int uVal = uPlane.bytes[uvIndex] & 0xFF;
          final int vVal = vPlane.bytes[uvIndex] & 0xFF;

          int r = (yVal + 1.402 * (vVal - 128)).toInt();
          int g = (yVal - 0.344 * (uVal - 128) - 0.714 * (vVal - 128)).toInt();
          int b = (yVal + 1.772 * (uVal - 128)).toInt();

          r = r.clamp(0, 255);
          g = g.clamp(0, 255);
          b = b.clamp(0, 255);

          final int rgbIndex = (y * width + x) * 3;
          rgbData[rgbIndex] = r;
          rgbData[rgbIndex + 1] = g;
          rgbData[rgbIndex + 2] = b;
        }
      }

      final img.Image rgbImage = img.Image(width: width, height: height);
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int index = (y * width + x) * 3;
          rgbImage.setPixelRgb(x, y, rgbData[index], rgbData[index + 1], rgbData[index + 2]);
        }
      }

      final img.Image resizedImage = img.copyResize(rgbImage, width: 320, height: 240);
      final Uint8List jpegBytes = Uint8List.fromList(img.encodeJpg(resizedImage, quality: 80));
      return base64Encode(jpegBytes);
    } catch (e) {
      print("❌ Image conversion error: $e");
      return null;
    }
  }

  Future<void> _sendFrameToBackend(CameraImage image) async {
    if (_isProcessing || _currentTarget.isEmpty || isPaused) return;
    _isProcessing = true;

    try {
      final String? base64Image = await _convertImageToBase64(image);
      if (base64Image == null) {
        _isProcessing = false;
        return;
      }

      final response = await http.post(
        Uri.parse(_backendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'image': base64Image,
          'target': _currentTarget,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'found' && data['voice_message'] != null) {
          await _speak(data['voice_message']);
          if (data['meters'] != null && data['meters'] < 0.8) {
            await _speak("Target is within reach. Stopping search.");
            setState(() => _currentTarget = "");
          }
        } else if (data['status'] == 'not_found' && data['voice_message'] != null) {
          await _speak(data['voice_message']);
        }
      }
    } catch (e) {
      print("❌ Backend error: $e");
    } finally {
      _isProcessing = false;
    }
  }

  // Called on screen launch — asks user to speak target via dedicated mic session
  Future<void> _listenForTargetObject() async {
    // Temporarily pause screen commands so "find X" doesn't re-trigger
    _voiceService.clearScreenCommands();

    final strings = AppLocalizations.of(context);
    bool available = await _speechToText.initialize();

    if (!available) {
      await _speak("Speech recognition not available");
      _voiceService.setScreenCommands(_handleVoiceCommand);
      return;
    }

    await _speak(strings.translate('target_start'));
    setState(() => _isListeningForTarget = true);

    _speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          setState(() => _isListeningForTarget = false);

          String target = result.recognizedWords.toLowerCase().trim();
          target = target.replaceAll('find ', '');
          target = target.replaceAll('search for ', '');
          target = target.replaceAll('look for ', '');
          target = target.replaceAll('detect ', '');

          if (target.isNotEmpty) {
            setState(() => _currentTarget = target);
            _speak("Searching for $target");
            print('✅ Target set: "$target"');
          } else {
            _speak("No target heard. Say find and then the object name.");
          }

          _speechToText.stop();
          // Re-register screen commands after target listening is done
          _voiceService.setScreenCommands(_handleVoiceCommand);
        }
      },
      listenFor: const Duration(seconds: 6),
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      onDevice: true,
    );

    // Timeout fallback
    Future.delayed(const Duration(seconds: 7), () {
      if (_isListeningForTarget) {
        setState(() => _isListeningForTarget = false);
        _speechToText.stop();
        if (_currentTarget.isEmpty) {
          _speak("No target set. Say find laptop or find chair anytime.");
        }
        _voiceService.setScreenCommands(_handleVoiceCommand);
      }
    });
  }

  Future<void> _initializeCamera() async {
    cameras = await availableCameras();
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.low,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {});

    _controller!.startImageStream(_processCameraImage);
    await _listenForTargetObject();
  }

  void _processCameraImage(CameraImage image) {
    if (_currentTarget.isEmpty || isPaused) return;
    _frameCounter++;
    if (_frameCounter % _processEveryNFrames == 0) {
      _sendFrameToBackend(image);
    }
  }

  Future<void> _pauseResumeCamera() async {
    if (_controller == null) return;
    final strings = AppLocalizations.of(context);

    setState(() => isPaused = !isPaused);

    if (isPaused) {
      await _controller!.pausePreview();
      await _speak(strings.translate('detection_paused'));
    } else {
      await _controller!.resumePreview();
      await _speak(strings.translate('detection_resumed'));
    }
  }

  Future<void> _stopCamera() async {
    await _controller?.stopImageStream();
    final settings = Provider.of<AppSettings>(context, listen: false);
    final strings = AppLocalizations.of(context);
    await settings.tts.stop();
    await settings.tts.speak(strings.translate('target_stopped'));
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _resetSearch() async {
    setState(() => _currentTarget = "");
    await _speak("Search reset. What object would you like to find?");
    await _listenForTargetObject();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
          textScaleFactor: settings.largeText ? 1.5 : 1.0),
      child: _buildBody(settings),
    );
  }

  Widget _buildBody(AppSettings settings) {
    final strings = AppLocalizations.of(context);
    final isUrdu = settings.language == 'Urdu';
    final bool voiceActive = _voiceService.isActive;

    if (_controller == null || !_controller!.value.isInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20),
              Text(
                strings.translate('init_camera'),
                style: const TextStyle(
                  color: Color(0xFFB3E5FC),
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              ),
              if (_isListeningForTarget) ...[
                const SizedBox(height: 20),
                const Icon(Icons.mic, color: Colors.red, size: 40),
                const SizedBox(height: 10),
                Text(
                  isUrdu ? "سن رہا ہوں..." : "Listening for target...",
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 35, bottom: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A237E), Color(0xFF0A0E21)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A237E),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF3949AB), width: 1),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: Colors.white, size: 18),
                          onPressed: () => _stopCamera(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            strings.translate('target_search_title'),
                            style: const TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _isProcessing
                              ? Colors.orange.withOpacity(0.3)
                              : Colors.green.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _isProcessing ? "..." : "●",
                          style: TextStyle(
                            color: _isProcessing ? Colors.orange : Colors.green,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (_currentTarget.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      isUrdu
                          ? "تلاش: $_currentTarget"
                          : "Searching for: $_currentTarget",
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.green,
                          fontWeight: FontWeight.w400),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (_isListeningForTarget)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      isUrdu
                          ? "اپنا ہدف بتائیں..."
                          : "Speak your target object...",
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.yellow,
                          fontWeight: FontWeight.w400),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      isUrdu
                          ? "کہیں: فائنڈ اور پھر چیز کا نام"
                          : 'Say "find laptop" or tap mic to set target',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 6),
                // Voice hint
                Text(
                  isUrdu
                      ? 'کہیں: "فائنڈ چیز"، "پاز"، "ریزیوم"، "اسٹاپ"'
                      : 'Say: "find [object]", "pause", "resume", "stop"',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.greenAccent.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(10, 10, 10, 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  const BoxShadow(
                      color: Colors.black, blurRadius: 25, spreadRadius: 3),
                  BoxShadow(
                      color: const Color(0xFF00E5FF).withOpacity(0.15),
                      blurRadius: 35,
                      spreadRadius: 8),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(
                top: 10, bottom: 25, left: 30, right: 30),
            decoration: const BoxDecoration(
              color: Color(0xFF0A0E21),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isListeningForTarget
                        ? Colors.red.withOpacity(0.15)
                        : isPaused
                        ? const Color(0xFFFFB347).withOpacity(0.15)
                        : Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: _isListeningForTarget
                          ? Colors.red
                          : isPaused
                          ? const Color(0xFFFFB347)
                          : Colors.green,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isListeningForTarget
                            ? Icons.mic
                            : isPaused
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: _isListeningForTarget
                            ? Colors.red
                            : isPaused
                            ? const Color(0xFFFFB347)
                            : Colors.green,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _isListeningForTarget
                            ? (isUrdu ? "سن رہا ہوں..." : "Listening...")
                            : isPaused
                            ? strings.translate('paused')
                            : strings.translate('active'),
                        style: TextStyle(
                          color: _isListeningForTarget
                              ? Colors.red
                              : isPaused
                              ? const Color(0xFFFFB347)
                              : Colors.green,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildEnhancedButton(
                      icon: Icons.mic,
                      label: isUrdu ? "ہدف بتائیں" : "Set Target",
                      onTap: _listenForTargetObject,
                      gradient: const [Color(0xFF2196F3), Color(0xFF1976D2)],
                      iconSize: 28,
                      buttonSize: 60,
                    ),
                    _buildEnhancedButton(
                      icon: isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      label: isPaused
                          ? strings.translate('resume')
                          : strings.translate('pause'),
                      onTap: _pauseResumeCamera,
                      gradient: const [Color(0xFFFFB347), Color(0xFFFF7A18)],
                      iconSize: 34,
                      buttonSize: 70,
                    ),
                    _buildEnhancedButton(
                      icon: Icons.stop_rounded,
                      label: strings.translate('stop'),
                      onTap: _stopCamera,
                      gradient: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                      iconSize: 34,
                      buttonSize: 70,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_currentTarget.isNotEmpty)
                  GestureDetector(
                    onTap: _resetSearch,
                    child: Text(
                      isUrdu ? "تلاش ری سیٹ کریں" : "Reset Search",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      voiceActive ? Icons.mic : Icons.mic_off,
                      color: voiceActive ? Colors.green : Colors.grey,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      voiceActive
                          ? (isUrdu ? "وائس کمانڈ فعال" : "Voice active")
                          : (isUrdu
                          ? "وائس کمانڈ غیر فعال"
                          : "Voice paused"),
                      style: TextStyle(
                        color: voiceActive ? Colors.green : Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required List<Color> gradient,
    double iconSize = 36,
    double buttonSize = 70,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(buttonSize / 2),
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: gradient.last.withOpacity(0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4)),
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    spreadRadius: 1,
                    offset: const Offset(0, 1)),
              ],
            ),
            child: Center(child: Icon(icon, color: Colors.white, size: iconSize)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}