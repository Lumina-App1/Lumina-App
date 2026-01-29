import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionDialog extends StatefulWidget {
  final VoidCallback onAllowed;

  const PermissionDialog({super.key, required this.onAllowed});

  @override
  State<PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<PermissionDialog> {
  final FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    speakPermission();
  }

  Future<void> speakPermission() async {
    await flutterTts.setLanguage("en-US");
    await flutterTts.setSpeechRate(0.45);
    await flutterTts.speak(
        "Permissions are required to continue. "
            "This application needs camera and microphone access. "
            "Please select allow to continue."
    );
  }

  Future<void> onAllow() async {
    flutterTts.stop();

    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();

    if (!mounted) return;

    if (cam.isGranted && mic.isGranted) {
      Navigator.pop(context);
      widget.onAllowed();
    } else {
      await flutterTts.speak(
          "Permissions are required to continue. Please select allow."
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        "Permission Required",
        style: TextStyle(color: Colors.black),
      ),
      content: const Text(
        "Camera and microphone access is required to assist you.",
        style: TextStyle(color: Colors.black),
        textAlign: TextAlign.center,
      ),
      actions: [
        OutlinedButton(
          onPressed: () {
            flutterTts.speak(
                "Permissions are required to continue. Please select allow."
            );
          },
          child: const Text("Deny"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
          onPressed: onAllow,
          child: const Text("Allow"),
        ),
      ],
    );
  }
}