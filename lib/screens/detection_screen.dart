import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'home_screen.dart';
import '../core/app_settings.dart';
import '../core/app_localizations.dart';

late List<CameraDescription> cameras;

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  CameraController? _controller;
  bool isPaused = false;
  bool _hasSpoken = false;

  Future<void> _speak(String text) async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    await settings.tts.stop();
    settings.tts.speak(text);
  }

  Future<void> _initializeCamera() async {
    cameras = await availableCameras();
    if (cameras.isNotEmpty) {
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();

      if (!mounted) return;
      setState(() {});

      if (!_hasSpoken) {
        _hasSpoken = true;
        final strings = AppLocalizations.of(context);
        await _speak(strings.translate('live_detection_started'));
      }
    }
  }

  void _pauseResumeCamera() async {
    if (_controller == null) return;
    final strings = AppLocalizations.of(context);

    if (isPaused) {
      await _controller!.resumePreview();
      await _speak(strings.translate('detection_resumed'));
    } else {
      await _controller!.pausePreview();
      await _speak(strings.translate('detection_paused'));
    }
    setState(() {
      isPaused = !isPaused;
    });
  }

  void _stopCamera() async {
    final settings = Provider.of<AppSettings>(context, listen: false);
    final strings = AppLocalizations.of(context);
    await settings.tts.stop();
    await settings.tts.speak(strings.translate('detection_stopped'));
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
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
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  const Color(0xFF00E5FF).withOpacity(0.8),
                ),
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
                colors: [
                  Color(0xFF1A237E),
                  Color(0xFF0A0E21),
                ],
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
                          border: Border.all(
                            color: const Color(0xFF3949AB),
                            width: 1,
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: () => _stopCamera(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          strings.translate('live_object_detection'),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    strings.translate('identifying_objects'),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
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
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 25,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: const Color(0xFF00E5FF).withOpacity(0.15),
                    blurRadius: 35,
                    spreadRadius: 8,
                  ),
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
                    color: isPaused
                        ? const Color(0xFFFFB347).withOpacity(0.15)
                        : const Color(0xFF4CAF50).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isPaused
                          ? const Color(0xFFFFB347)
                          : const Color(0xFF4CAF50),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPaused ? Icons.pause : Icons.play_arrow,
                        color: isPaused
                            ? const Color(0xFFFFB347)
                            : const Color(0xFF4CAF50),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPaused ? strings.translate('paused') : strings.translate('detecting'),
                        style: TextStyle(
                          color: isPaused
                              ? const Color(0xFFFFB347)
                              : const Color(0xFF4CAF50),
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
                      icon: isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      label: isPaused ? strings.translate('resume') : strings.translate('pause'),
                      onTap: _pauseResumeCamera,
                      gradient: const [
                        Color(0xFFFFB347),
                        Color(0xFFFF7A18),
                      ],
                      iconSize: 34,
                      buttonSize: 70,
                    ),
                    _buildEnhancedButton(
                      icon: Icons.stop_rounded,
                      label: strings.translate('stop'),
                      onTap: _stopCamera,
                      gradient: const [
                        Color(0xFFFF416C),
                        Color(0xFFFF4B2B),
                      ],
                      iconSize: 34,
                      buttonSize: 70,
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
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: gradient.last.withOpacity(0.6),
                  blurRadius: 12,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  spreadRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                icon,
                color: Colors.white,
                size: iconSize,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}