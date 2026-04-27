import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart';
import 'package:image/image.dart' as img;
import 'home_screen.dart';
import '../core/app_settings.dart';
import '../core/app_localizations.dart';
import '../core/app_config.dart';

late List<CameraDescription> cameras;

class TargetScreen extends StatefulWidget {
  const TargetScreen({super.key});

  @override
  State<TargetScreen> createState() => _TargetScreenState();
}

class _TargetScreenState extends State<TargetScreen> {
  CameraController? _controller;
  bool isPaused = false;
  bool _isProcessing = false;
  String _currentTarget = "";
  bool _isListeningForTarget = false;

  // 🔴 CHANGE THIS TO YOUR LAPTOP'S IP ADDRESS
  // final String _backendUrl = "http://10.24.30.129:5000/search";
  final String _backendUrl = AppConfig.backendUrl;

  final SpeechToText _speechToText = SpeechToText();

  int _frameCounter = 0;
  final int _processEveryNFrames = 15;

  Future<void> _speak(String text) async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    await settings.tts.stop();
    await settings.tts.speak(text);
  }

  // ============================================================
  // IMAGE CONVERSION - YUV to JPEG with RESIZE for speed
  // ============================================================
  Future<String?> _convertImageToBase64(CameraImage image) async {
    try {
      print("🔄 Converting YUV to JPEG...");

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

      // RESIZE for faster processing
      final img.Image resizedImage = img.copyResize(rgbImage, width: 160, height: 120);

      final Uint8List jpegBytes = Uint8List.fromList(img.encodeJpg(resizedImage, quality: 50));
      final String base64Image = base64Encode(jpegBytes);

      print("✅ JPEG size: ${jpegBytes.length} bytes");

      return base64Image;

    } catch (e) {
      print("❌ Image conversion error: $e");
      return null;
    }
  }

  Future<void> _sendFrameToBackend(CameraImage image) async {
    if (_isProcessing) return;
    if (_currentTarget.isEmpty) return;
    if (isPaused) return;

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
            _currentTarget = "";
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

  Future<void> _listenForTargetObject() async {
    final strings = AppLocalizations.of(context);

    bool available = await _speechToText.initialize();
    if (!available) {
      await _speak("Speech recognition not available");
      return;
    }

    await _speak(strings.translate('target_start'));

    setState(() => _isListeningForTarget = true);

    _speechToText.listen(
      onResult: (result) {
        setState(() => _isListeningForTarget = false);
        String target = result.recognizedWords.toLowerCase();
        _currentTarget = target;
        _speak("Searching for $target");
      },
      listenFor: const Duration(seconds: 5),
      pauseFor: const Duration(seconds: 2),
    );

    Future.delayed(const Duration(seconds: 6), () {
      if (_speechToText.isListening) {
        setState(() => _isListeningForTarget = false);
        _speechToText.stop();
        if (_currentTarget.isEmpty) {
          _speak("No target specified. Please try again.");
        }
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
    if (_currentTarget.isEmpty) return;
    if (isPaused) return;

    _frameCounter++;
    if (_frameCounter % _processEveryNFrames == 0) {
      _sendFrameToBackend(image);
    }
  }

  Future<void> _pauseResumeCamera() async {
    if (_controller == null) return;
    final strings = AppLocalizations.of(context);

    setState(() {
      isPaused = !isPaused;
    });

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
    _currentTarget = "";
    await _speak("Search reset. What object would you like to find?");
    await _listenForTargetObject();
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _speechToText.stop();
    final settings = Provider.of<AppSettings>(context, listen: false);
    settings.tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaleFactor: settings.largeText ? 1.5 : 1.0),
      child: _buildBody(settings),
    );
  }

  Widget _buildBody(AppSettings settings) {
    final strings = AppLocalizations.of(context);

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
                style: const TextStyle(color: Color(0xFFB3E5FC), fontSize: 16, fontWeight: FontWeight.w300),
              ),
              if (_isListeningForTarget) ...[
                const SizedBox(height: 20),
                const Icon(Icons.mic, color: Colors.red, size: 40),
                const SizedBox(height: 10),
                const Text("Listening...", style: TextStyle(color: Colors.white)),
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
                          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                          onPressed: () => _stopCamera(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strings.translate('target_search_title'),
                          style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _currentTarget.isNotEmpty ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _currentTarget.isNotEmpty ? "Searching for: $_currentTarget" : "Say your target object",
                    style: TextStyle(
                      color: _currentTarget.isNotEmpty ? Colors.green : Colors.orange,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
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
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 25, spreadRadius: 3),
                  BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.15), blurRadius: 35, spreadRadius: 8),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: CameraPreview(_controller!),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 10, bottom: 25, left: 30, right: 30),
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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: isPaused ? const Color(0xFFFFB347).withOpacity(0.15) : const Color(0xFF4CAF50).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: isPaused ? const Color(0xFFFFB347) : const Color(0xFF4CAF50), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(isPaused ? Icons.pause : Icons.play_arrow,
                          color: isPaused ? const Color(0xFFFFB347) : const Color(0xFF4CAF50), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        isPaused ? strings.translate('paused') : strings.translate('active'),
                        style: TextStyle(
                          color: isPaused ? const Color(0xFFFFB347) : const Color(0xFF4CAF50),
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
                      label: "Speak",
                      onTap: () async {
                        await _controller?.stopImageStream();
                        await _listenForTargetObject();
                        _controller?.startImageStream(_processCameraImage);
                      },
                      gradient: const [Color(0xFF2196F3), Color(0xFF1976D2)],
                      iconSize: 30,
                      buttonSize: 60,
                    ),
                    _buildEnhancedButton(
                      icon: isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      label: isPaused ? "Resume" : "Pause",
                      onTap: _pauseResumeCamera,
                      gradient: const [Color(0xFFFFB347), Color(0xFFFF7A18)],
                      iconSize: 30,
                      buttonSize: 60,
                    ),
                    _buildEnhancedButton(
                      icon: Icons.stop_rounded,
                      label: "Stop",
                      onTap: _stopCamera,
                      gradient: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                      iconSize: 30,
                      buttonSize: 60,
                    ),
                  ],
                ),
                if (_currentTarget.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: GestureDetector(
                      onTap: _resetSearch,
                      child: Text(
                        "Reset Search",
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                      ),
                    ),
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
              gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: gradient.last.withOpacity(0.6), blurRadius: 12, spreadRadius: 2, offset: const Offset(0, 4)),
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, spreadRadius: 1, offset: const Offset(0, 1)),
              ],
            ),
            child: Center(child: Icon(icon, color: Colors.white, size: iconSize)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: label == "Speak" ? 11 : 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}