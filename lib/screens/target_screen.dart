import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
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

class _TargetScreenState extends State<TargetScreen>
    with RouteAware {

  CameraController? _controller;

  bool isPaused = false;
  bool _isProcessing = false;

  String _currentTarget = "";
  bool _targetFound = false;

  // SINGLE recognizer mode state
  bool _waitingForTarget = false;
  String _heardText = "";
  Timer? _targetTimeout;
  DateTime? _lastSpokenTime;
  bool _isSpeaking = false;

  final String _backendUrl = "http://192.168.1.5:5000/search";

  int _frameCounter = 0;
  // final int _processEveryNFrames = 25;
  final int _processEveryNFrames = 8;
  late VoiceCommandService _voiceService;


  @override
  void initState() {
    super.initState();

    _voiceService = VoiceCommandService();

    _initializeCamera();
  }
  bool _lastCommandWasUrdu = false;
// Detect if input is Urdu
  bool _isUrduText(String text) {
    final urduRegex = RegExp(r'[\u0600-\u06FF]');
    return urduRegex.hasMatch(text);
  }


// Urdu + Roman Urdu → English mapping
  String _mapToEnglish(String input) {
    final text = input.toLowerCase().trim();

    final map = {
      // PERSON
      "آدمی": "person",
      "انسان": "person",
      "بندہ": "person",
      "عورت": "person",
      "لڑکا": "person",
      "لڑکی": "person",
      "admi": "person",
      "insaan": "person",
      "banda": "person",

// BICYCLE
      "سائیکل": "bicycle",
      "بائیسکل": "bicycle",
      "cycle": "bicycle",
      "bicycle": "bicycle",
      "saikal": "bicycle",

// CAR
      "گاڑی": "car",
      "کار": "car",
      "موٹر": "car",
      "gaari": "car",
      "car": "car",

// MOTORCYCLE
      "موٹر سائیکل": "motorcycle",
      "بائیک": "motorcycle",
      "motor cycle": "motorcycle",
      "bike": "motorcycle",
      "baik": "motorcycle",

// AIRPLANE
      "ہوائی جہاز": "airplane",
      "جہاز": "airplane",
      "hawai jahaz": "airplane",
      "airplane": "airplane",
      "plane": "airplane",

// BUS
      "بس": "bus",
      "bus": "bus",

// TRAIN
      "ریل گاڑی": "train",
      "ریل": "train",
      "ٹرین": "train",
      "train": "train",
      "rail": "train",

// TRUCK
      "ٹرک": "truck",
      "truck": "truck",
      "trak": "truck",

// BOAT
      "کشتی": "boat",
      "ناؤ": "boat",
      "boat": "boat",
      "kashti": "boat",

// TRAFFIC LIGHT
      "ٹریفک لائٹ": "traffic light",
      "سگنل": "traffic light",
      "traffic light": "traffic light",
      "signal": "traffic light",

// FIRE HYDRANT
      "فائر ہائیڈرنٹ": "fire hydrant",
      "fire hydrant": "fire hydrant",

// STOP SIGN
      "اسٹاپ سائن": "stop sign",
      "stop sign": "stop sign",
      "stop": "stop sign",

// PARKING METER
      "پارکنگ میٹر": "parking meter",
      "parking meter": "parking meter",

// BENCH
      "بینچ": "bench",
      "بنچ": "bench",
      "bench": "bench",
      "baich": "bench",

// BIRD
      "پرندہ": "bird",
      "چڑیا": "bird",
      "پرند": "bird",
      "bird": "bird",
      "parinda": "bird",
      "chirya": "bird",

// CAT
      "بلی": "cat",
      "بلا": "cat",
      "cat": "cat",
      "billi": "cat",

// DOG
      "کتا": "dog",
      "کتے": "dog",
      "dog": "dog",
      "kuta": "dog",

// HORSE
      "گھوڑا": "horse",
      "گھوڑے": "horse",
      "horse": "horse",
      "ghora": "horse",

// SHEEP
      "بھیڑ": "sheep",
      "دنبہ": "sheep",
      "sheep": "sheep",
      "bher": "sheep",

// COW
      "گائے": "cow",
      "بھینس": "cow",
      "cow": "cow",
      "gaay": "cow",

// ELEPHANT
      "ہاتھی": "elephant",
      "elephant": "elephant",
      "haathi": "elephant",

// BEAR
      "ریچھ": "bear",
      "bear": "bear",
      "reech": "bear",

// ZEBRA
      "زیبرا": "zebra",
      "zebra": "zebra",

// GIRAFFE
      "زرافہ": "giraffe",
      "giraffe": "giraffe",
      "zaraafa": "giraffe",

// BACKPACK
      "بیگ": "backpack",
      "بستہ": "backpack",
      "تھیلا": "backpack",
      "backpack": "backpack",
      "bag": "backpack",
      "basta": "backpack",

// UMBRELLA
      "چھتری": "umbrella",
      "umbrella": "umbrella",
      "chhatri": "umbrella",

// HANDBAG
      "ہینڈ بیگ": "handbag",
      "پرس": "handbag",
      "handbag": "handbag",
      "purse": "handbag",
      "pars": "handbag",

// TIE
      "ٹائی": "tie",
      "tie": "tie",

// SUITCASE
      "سوٹ کیس": "suitcase",
      "اٹیچی": "suitcase",
      "suitcase": "suitcase",
      "attaché": "suitcase",
      "atichi": "suitcase",

// FRISBEE
      "فریزبی": "frisbee",
      "frisbee": "frisbee",

// SKIS
      "اسکی": "skis",
      "skis": "skis",
      "ski": "skis",

// SNOWBOARD
      "اسنو بورڈ": "snowboard",
      "snowboard": "snowboard",

// SPORTS BALL
      "گیند": "sports ball",
      "بال": "sports ball",
      "sports ball": "sports ball",
      "ball": "sports ball",
      "gaind": "sports ball",

// KITE
      "پتنگ": "kite",
      "گڈی": "kite",
      "kite": "kite",
      "patang": "kite",

// BASEBALL BAT
      "بیس بال بیٹ": "baseball bat",
      "بیٹ": "baseball bat",
      "baseball bat": "baseball bat",
      "bat": "baseball bat",

// BASEBALL GLOVE
      "بیس بال دستانہ": "baseball glove",
      "baseball glove": "baseball glove",
      "glove": "baseball glove",

// SKATEBOARD
      "اسکیٹ بورڈ": "skateboard",
      "skateboard": "skateboard",

// SURFBOARD
      "سرف بورڈ": "surfboard",
      "surfboard": "surfboard",

// TENNIS RACKET
      "ٹینس ریکٹ": "tennis racket",
      "ریکٹ": "tennis racket",
      "tennis racket": "tennis racket",
      "racket": "tennis racket",

// BOTTLE
      "بوتل": "bottle",
      "پانی کی بوتل": "bottle",
      "bottle": "bottle",
      "paani ki botal": "bottle",
      "botal": "bottle",

// WINE GLASS
      "شراب کا گلاس": "wine glass",
      "wine glass": "wine glass",

// CUP
      "کپ": "cup",
      "گلاس": "cup",
      "پیالی": "cup",
      "cup": "cup",
      "glass": "cup",
      "kap": "cup",

// FORK
      "کانٹا": "fork",
      "fork": "fork",
      "kanta": "fork",

// KNIFE
      "چھری": "knife",
      "چاقو": "knife",
      "knife": "knife",
      "churi": "knife",
      "chaku": "knife",

// SPOON
      "چمچ": "spoon",
      "spoon": "spoon",
      "chamach": "spoon",

// BOWL
      "پیالہ": "bowl",
      "کٹورا": "bowl",
      "bowl": "bowl",
      "pyala": "bowl",
      "katora": "bowl",

// BANANA
      "کیلا": "banana",
      "کیلے": "banana",
      "banana": "banana",
      "kela": "banana",

// APPLE
      "سیب": "apple",
      "apple": "apple",
      "saib": "apple",

// SANDWICH
      "سینڈوچ": "sandwich",
      "sandwich": "sandwich",

// ORANGE
      "سنترہ": "orange",
      "مالٹا": "orange",
      "orange": "orange",
      "santra": "orange",
      "malta": "orange",

// BROCCOLI
      "بروکلی": "broccoli",
      "broccoli": "broccoli",

// CARROT
      "گاجر": "carrot",
      "carrot": "carrot",
      "gajar": "carrot",

// HOT DOG
      "ہاٹ ڈاگ": "hot dog",
      "hot dog": "hot dog",
      "hotdog": "hot dog",

// PIZZA
      "پیزا": "pizza",
      "pizza": "pizza",

// DONUT
      "ڈونٹ": "donut",
      "donut": "donut",
      "doughnut": "donut",

// CAKE
      "کیک": "cake",
      "cake": "cake",

// CHAIR
      "کرسی": "chair",
      "chair": "chair",
      "kursi": "chair",

// COUCH
      "صوفہ": "couch",
      "سوفہ": "couch",
      "couch": "couch",
      "sofa": "couch",
      "sopha": "couch",

// POTTED PLANT
      "گملا": "potted plant",
      "پودا": "potted plant",
      "potted plant": "potted plant",
      "plant": "potted plant",
      "gamla": "potted plant",

// BED
      "بستر": "bed",
      "چارپائی": "bed",
      "پلنگ": "bed",
      "bed": "bed",
      "bistar": "bed",
      "charpai": "bed",

// DINING TABLE
      "میز": "dining table",
      "ٹیبل": "dining table",
      "dining table": "dining table",
      "table": "dining table",
      "maiz": "dining table",

// TOILET
      "ٹوائلٹ": "toilet",
      "بیت الخلا": "toilet",
      "toilet": "toilet",
      "bait ul khala": "toilet",

// TV
      "ٹی وی": "tv",
      "ٹیلی ویژن": "tv",
      "tv": "tv",
      "television": "tv",
      "tivi": "tv",

// LAPTOP
      "لیپ ٹاپ": "laptop",
      "کمپیوٹر": "laptop",
      "لیپٹاپ": "laptop",
      "laptop": "laptop",
      "computer": "laptop",
      "leaptop": "laptop",

// MOUSE
      "ماؤس": "mouse",
      "mouse": "mouse",

// REMOTE
      "ریموٹ": "remote",
      "ریموٹ کنٹرول": "remote",
      "remote": "remote",
      "remote control": "remote",

// KEYBOARD
      "کی بورڈ": "keyboard",
      "keyboard": "keyboard",

// CELL PHONE
      "موبائل": "cell phone",
      "فون": "cell phone",
      "موبائل فون": "cell phone",
      "cell phone": "cell phone",
      "mobile": "cell phone",
      "phone": "cell phone",
      "mobile phone": "cell phone",

// MICROWAVE
      "مائیکرو ویو": "microwave",
      "microwave": "microwave",

// OVEN
      "تندور": "oven",
      "اوون": "oven",
      "oven": "oven",
      "tandoor": "oven",

// TOASTER
      "ٹوسٹر": "toaster",
      "toaster": "toaster",

// SINK
      "سنک": "sink",
      "واش بیسن": "sink",
      "sink": "sink",
      "wash basin": "sink",
      "basin": "sink",

// REFRIGERATOR
      "فریج": "refrigerator",
      "ریفریجریٹر": "refrigerator",
      "refrigerator": "refrigerator",
      "fridge": "refrigerator",
      "farej": "refrigerator",

// BOOK
      "کتاب": "book",
      "کتابیں": "book",
      "book": "book",
      "kitab": "book",

// CLOCK
      "گھڑی": "clock",
      "دیواری گھڑی": "clock",
      "clock": "clock",
      "ghari": "clock",
      "deewari ghari": "clock",

// VASE
      "گلدان": "vase",
      "vase": "vase",
      "guldan": "vase",

// SCISSORS
      "قینچی": "scissors",
      "scissors": "scissors",
      "qaichi": "scissors",

// TEDDY BEAR
      "ٹیڈی بیئر": "teddy bear",
      "کھلونا": "teddy bear",
      "teddy bear": "teddy bear",
      "teddy": "teddy bear",
      "khilona": "teddy bear",

// HAIR DRIER
      "ہیئر ڈرائر": "hair drier",
      "hair drier": "hair drier",
      "hair dryer": "hair drier",
      "dryer": "hair drier",

// TOOTHBRUSH
      "ٹوتھ برش": "toothbrush",
      "برش": "toothbrush",
      "toothbrush": "toothbrush",
      "brush": "toothbrush",
      "barash": "toothbrush",
    };
    for (var key in map.keys) {
      if (text.contains(key)) {
        return map[key]!;
      }
    }
    // return text;
    // fallback: return last meaningful word
    List<String> words = text.split(" ").where((w) => w.isNotEmpty).toList();
    return words.isNotEmpty ? words.last : text;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final route = ModalRoute.of(context);

    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }

    _voiceService.updateContext(context);

    _voiceService.clearScreenCommands();

    _voiceService.setScreenCommands(
      _handleVoiceCommand,
    );

    _voiceService.resume();
  }


  @override
  void didPopNext() {

    _voiceService.updateContext(context);

    _voiceService.clearScreenCommands();

    _voiceService.setScreenCommands(
      _handleVoiceCommand,
    );

    _voiceService.resume();
  }


  @override
  void dispose() {

    routeObserver.unsubscribe(this);

    _targetTimeout?.cancel();

    _voiceService.clearScreenCommands();
    _voiceService.resume();

    _controller?.stopImageStream();
    _controller?.dispose();

    final settings =
    Provider.of<AppSettings>(
      context,
      listen: false,
    );

    settings.tts.stop();

    super.dispose();
  }


  bool _isUrduMode() {
    try {
      return Provider.of<AppSettings>(
          context,
          listen: false
      ).language == 'Urdu';
    }
    catch (_) {
      return false;
    }
  }


  // Future<void> _speak(String text) async {
  //   try {
  //     if (text.trim().isEmpty) return;
  //
  //     final settings = Provider.of<AppSettings>(
  //       context,
  //       listen: false,
  //     );
  //
  //     // 🟢 SET LANGUAGE BEFORE SPEAKING
  //     if (_lastCommandWasUrdu || _isUrduMode()) {
  //       await settings.tts.setLanguage("ur-PK"); // Urdu
  //     } else {
  //       await settings.tts.setLanguage("en-US"); // English
  //     }
  //
  //     print("🔊 Speaking: $text");
  //
  //     _voiceService.pause();
  //
  //     await settings.tts.stop();
  //     await settings.tts.speak(text);
  //
  //     await Future.delayed(Duration(seconds: 4));
  //
  //   } catch (e) {
  //     print("TTS ERROR:");
  //     print(e);
  //   } finally {
  //     _voiceService.resume();
  //   }
  // }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;

    // 🟢 Wait if already speaking (prevents overlap)
    while (_isSpeaking) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _isSpeaking = true;

    try {
      final settings = Provider.of<AppSettings>(context, listen: false);

      // 🟢 Set language
      if (_lastCommandWasUrdu || _isUrduMode()) {
        await settings.tts.setLanguage("ur-PK");
      } else {
        await settings.tts.setLanguage("en-US");
      }

      print("🔊 Speaking: $text");

      _voiceService.pause();

      // ❌ REMOVED: await settings.tts.stop();

      await settings.tts.speak(text);

      // ✅ REAL COMPLETION WAIT (NO FAKE DELAY)
      await settings.tts.awaitSpeakCompletion(true);

    } catch (e) {
      print("TTS ERROR: $e");
    } finally {
      _isSpeaking = false;
      _voiceService.resume();
    }
  }

  Future<void> _interruptAndSpeak(String text) async {
    final settings = Provider.of<AppSettings>(context, listen: false);

    await settings.tts.stop(); // ONLY here we force stop
    await _speak(text);
  }


  bool _matchesAny(
      String command,
      List<String> keywords,
      ) {
    return keywords.any(
            (k) => command.contains(
          k.toLowerCase(),
        )
    );
  }


  bool _isRomanUrdu(String text) {
    text = text.toLowerCase();

    List<String> romanWords = [
      "dhundo",
      "dhoondo",
      "dhundho",
      "talash",
      "karo",
      "admi",
      "insaan",
      "gaari",
      "kursi",
      "botal",
      "paani",
      "ghari",
      "kitaab",
      "banda",
      "gaari", "bike", "botal", "paani",
      "kursi", "kitaab", "ghari",
      "pankha", "chaku", "chamach"
    ];

    return romanWords.any((word) => text.contains(word));
  }
////////////////////////////////////////////////////////
// SINGLE RECOGNIZER MODE SWITCH
////////////////////////////////////////////////////////


  void _handleVoiceCommand(
      String command,
      ) {

    print('VOICE: $command');

    command =
        command
            .toLowerCase()
            .trim();


////////////////////////
// TARGET CAPTURE MODE
////////////////////////

    if (_waitingForTarget) {

      // If it's actually a command → handle it normally
      if (_matchesAny(command, [
        // English
        'stop','back','home',
        'pause','resume',
        'reset','continue',

        // Urdu
        'اسٹاپ','واپس','پاز','ریزیوم',
        'ختم کر دو',
        'روکو',
        'رک جاؤ',
        'ٹھہرو',
        'وقفہ دو',
        'عارضی بند کرو',
        'چلاؤ',
        'جاری کرو',
        'دوبارہ شروع کرو',

        'ہدف سیٹ کرو',
        'ہدف بتاؤ',
        'نیا ہدف',
        'ہدف بدل دو',
        'دوسرا ہدف',
        'ری سیٹ کرو',
        'دوبارہ شروع کرو',
        'پھر سے کرو',

        // Roman Urdu
        'stop','back','home',
        'pause','resume',
        'reset','continue',

        'stop','wapas','pause','resume',
        'khatam karo',
        'roko',
        'ruk jao',
        'rok do'
            'thehro',
        'waqfa do',
        'aarzi band karo',
        'chalao',
        'jaari karo',
        'dobara shuru karo',

        'hadaf set karo',
        'hadaf batao',
        'naya hadaf',
        'hadaf badal do',
        'dosra hadaf',
        'reset karo',
        'dobara shuru karo',
        'phir se karo'
      ])) {
        _waitingForTarget = false;
        _handleVoiceCommand(command);
        return;
      }

      if (command.isEmpty) return;

      // String target = _cleanTarget(command);
      String rawTarget = _cleanTarget(command);

      if (rawTarget.isEmpty) return;

// Detect Urdu or Roman Urdu
      _lastCommandWasUrdu =
          _isUrduText(command) ||
              _isRomanUrdu(command) ||
              _isUrduMode();

// Convert to English for backend
//       String target = _mapToEnglish(rawTarget);
      String target = _lastCommandWasUrdu
          ? _mapToEnglish(rawTarget)
          : rawTarget;
      if (target.isEmpty) return;

      _targetTimeout?.cancel();

      setState(() {
        _waitingForTarget = false;
        _heardText = target;
        _currentTarget = target;
        _targetFound = false;
      });

      //
      String spokenTarget = _lastCommandWasUrdu
          ? _translateToUrdu(target)
          : target;

      _speak(
          _isUrduMode()
              ? "$spokenTarget تلاش کر رہا ہوں"
              : "Searching for $spokenTarget"
      );

      return;
    }

////////////////////////
// COMMAND MODE
////////////////////////

    if (_matchesAny(
        command,
        [
          'stop',
          'back',
          'home',
          'اسٹاپ',
          'واپس',
          'ختم کر دو',
          // Roman Urdu
          'band',

          'stop',
          'wapas',
          'khatam karo'
        ]
    )) {
      _stopCamera();
      return;
    }


    if (_matchesAny(
        command,
        [
          'pause',
          'پاز',
          'روکو',
          'رک جاؤ',
          'ٹھہرو',
          'وقفہ دو',
          'عارضی بند کرو',

          'pause',
          'pause',
          'roko',
          'ruk jao',
          'rok do'
              'thehro',
          'waqfa do',
          'aarzi band karo'
        ]
    )) {
      if (!isPaused) {
        _pauseResumeCamera();
      }
      return;
    }


    if (_matchesAny(
        command,
        [
          'resume',
          'continue',
          'ریزیوم',
          'چلاؤ',
          'جاری کرو',
          'دوبارہ شروع کرو',
          'chalao',
          'jari karo',
          'dobara shuru karo'

        ]
    )) {
      if (isPaused) {
        _pauseResumeCamera();
      }
      return;
    }


    if (_matchesAny(
        command,
        [
          'set target',
          'reset',
          'change target',
          'new target',
          'ہدف سیٹ کرو',
          'ہدف بتاؤ',
          'نیا ہدف',
          'ہدف بدل دو',
          'دوسرا ہدف',
          'ری سیٹ کرو',
          'دوبارہ شروع کرو',
          'پھر سے کرو',

          'hadaf set karo',
          'hadaf batao',
          'naya hadaf',
          'hadaf badal do',
          'dosra hadaf',
          'reset karo',
          'dobara shuru karo',
          'phir se karo'
        ]
    )) {
      _resetSearch();
      return;
    }


    if (_matchesAny(command, [
      'find',
      'search',

      // Urdu
      'ڈھونڈو ',
      'تلاش کرو ',
      'تلاش ',
      'ڈھونڈنا ',

      // Roman Urdu
      'dhundo',
      'dhoondo',
      'talash karo',
      'talash',
    ])) {

      //  Prevent restarting listening if already in listening mode
      if (!_waitingForTarget) {
        _listenForTargetObject();
      }

      return;
    }
  }


  String _cleanTarget(String raw) {
    String text = raw.toLowerCase().trim();

    // Remove common English filler words
    text = text.replaceAll(RegExp(
        r'\b(find|search|look|detect|for|please|a|an|the|my)\b'),
        '');

    // Urdu / Roman Urdu cleanup (keep your existing behavior)
    text = text.replaceAll(RegExp(
        r'\b(dhundo|dhoondo|dhundho|talash|karo)\b'),
        '');

    return text.trim();
  }

  void _listenForTargetObject() {

    if (_waitingForTarget) {
      return;
    }

    _targetTimeout?.cancel();

    setState(() {
      _waitingForTarget = true;
      _heardText = "";
    });


    _speak(
        _isUrduMode()
            ? "بولیں کیا ڈھونڈنا ہے"
            : "Say what to find"
    );


    _targetTimeout =
        Timer(
            const Duration(
                seconds: 8
            ),
                () {

              if (!mounted) return;

              if (_waitingForTarget) {

                setState(() {
                  _waitingForTarget = false;
                });

                _speak(
                    _isUrduMode()
                        ? "کوئی ہدف نہیں ملا"
                        : "No target heard"
                );
              }
            }
        );
  }

  String _translateToUrdu(String text) {
    String result = text.toLowerCase();

    final map = {
      "person": "آدمی",
      "laptop": "لیپ ٹاپ",
      "cell phone": "موبائل",
      "bottle": "بوتل",
      "cup": "کپ",
      "fan": "پنکھا",

      "bicycle": "سائیکل",
      "car": "گاڑی",
      "motorcycle": "موٹر سائیکل",
      "airplane": "ہوائی جہاز",
      "bus": "بس",
      "train": "ٹرین",
      "truck": "ٹرک",
      "boat": "کشتی",


      "traffic light": "ٹریفک لائٹ",
      "fire hydrant": "فائر ہائیڈرنٹ",
      "stop sign": "اسٹاپ سائن",
      "parking meter": "پارکنگ میٹر",
      "bench": "بینچ",

      "bird": "پرندہ",
      "cat": "بلی",
      "dog": "کتا",
      "horse": "گھوڑا",
      "sheep": "بھیڑ",
      "cow": "گائے",
      "elephant": "ہاتھی",
      "bear": "ریچھ",
      "zebra": "زیبرا",
      "giraffe": "زرافہ",

      // ACCESSORIES
      "backpack": "بیگ",
      "umbrella": "چھتری",
      "handbag": "ہینڈ بیگ",
      "tie": "ٹائی",
      "suitcase": "سوٹ کیس",

      // SPORTS
      "frisbee": "فریزبی",
      "skis": "اسکی",
      "snowboard": "اسنو بورڈ",
      "sports ball": "گیند",
      "kite": "پتنگ",
      "baseball bat": "بیٹ",
      "baseball glove": "دستانہ",
      "skateboard": "اسکیٹ بورڈ",
      "surfboard": "سرف بورڈ",
      "tennis racket": "ٹینس ریکٹ",

      "wine glass": "گلاس",

      "fork": "کانٹا",
      "knife": "چاقو",
      "spoon": "چمچ",
      "bowl": "پیالہ",

      "banana": "کیلا",
      "apple": "سیب",
      "sandwich": "سینڈوچ",
      "orange": "سنترہ",
      "broccoli": "بروکلی",
      "carrot": "گاجر",
      "hot dog": "ہاٹ ڈاگ",
      "pizza": "پیزا",
      "donut": "ڈونٹ",
      "cake": "کیک",


      "chair": "کرسی",
      "couch": "صوفہ",
      "potted plant": "پودا",
      "bed": "بستر",
      "dining table": "میز",
      "toilet": "ٹوائلٹ",


      "tv": "ٹی وی",

      "mouse": "ماؤس",
      "remote": "ریموٹ",
      "keyboard": "کی بورڈ",


      // APPLIANCES
      "microwave": "مائیکرو ویو",
      "oven": "اوون",
      "toaster": "ٹوسٹر",
      "sink": "سنک",
      "refrigerator": "فریج",

      // MISC
      "book": "کتاب",
      "clock": "گھڑی",
      "vase": "گلدان",
      "scissors": "قینچی",
      "teddy bear": "ٹیڈی بیئر",
      "hair drier": "ہیئر ڈرائر",
      "toothbrush": "ٹوتھ برش",

      // STATUS
      "detected": "موجود ہے",
      "not found": "نہیں ملا",
      "found":"مل گیا",

      // DIRECTIONS
      "left": "بائیں",
      "right": "دائیں",
      "center": "سامنے",
      "far left": "بہت بائیں",
      "far right": "بہت دائیں",

      // DISTANCE
      "very close": "بہت قریب",
      "close": "قریب",
      "medium": "درمیانہ فاصلہ",
      "far": "دور",
      "very far": "بہت دور",
      "distant": "بہت زیادہ دور",

      // WARNINGS
      "object is about 1 meter away": "چیز تقریباً ایک میٹر دور ہے",
      "object is about 2 meters away": "چیز تقریباً دو میٹر دور ہے",
      "object is about 3-4 meters away": "چیز تقریباً تین سے چار میٹر دور ہے",
      "object is about 5 meters away": "چیز تقریباً پانچ میٹر دور ہے",
      "object is far away, about 8+ meters": "چیز بہت دور ہے",

      // ACTIONS
      "move forward slowly": "آہستہ آگے بڑھیں",
      "move forward": "آگے بڑھیں",
      "keep moving forward": "آگے بڑھتے رہیں",
      "walk straight ahead": "سیدھا چلیں",
      "move left": "بائیں جائیں",
      "move right": "دائیں جائیں",
      "move significantly to your left": "زیادہ بائیں جائیں",
      "move significantly to your right": "زیادہ دائیں جائیں",
      "stop": "رک جائیں",

      // SEARCH
      "move camera slowly left and right": "کیمرہ آہستہ بائیں دائیں گھمائیں",

      // EXTRA
      "you can reach out now": "اب آپ ہاتھ بڑھا سکتے ہیں",
      "straight ahead": "سیدھا سامنے",
    };

    //  Sort longest first (VERY IMPORTANT)
    final entries = map.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (var entry in entries) {
      result = result.replaceAll(entry.key, entry.value);
    }

    return result;
  }


////////////////////////////////////////////////////////
// CAMERA
////////////////////////////////////////////////////////


  Future<void> _initializeCamera() async {

    try {
      cameras = await availableCameras();

      _controller =
          CameraController(
            cameras.first,
            ResolutionPreset.low,
            enableAudio: false,
          );

      await _controller!.initialize();

      if (!mounted) return;

      setState(() {});

      _controller!.startImageStream(
          _processCameraImage
      );

      _listenForTargetObject();
    }
    catch (e) {
      print(e);
    }
  }


  void _processCameraImage(
      CameraImage image,
      ) {

    if (
    _currentTarget.isEmpty ||
        isPaused
    ) {
      return;
    }

    _frameCounter++;

    if (
    _frameCounter %
        _processEveryNFrames == 0
    ) {
      _sendFrameToBackend(image);
    }
  }


  Future<String?> _convertImageToBase64(
      CameraImage image,
      ) async {

    try {

      final int width = image.width;
      final int height = image.height;

      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];

      final rgbData =
      List<int>.filled(
          width * height * 3,
          0
      );

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {

          final yIndex = y * width + x;

          final uvIndex =
              (y ~/ 2) *
                  (width ~/ 2) +
                  (x ~/ 2);

          final yVal = yPlane.bytes[yIndex] & 255;
          final uVal = uPlane.bytes[uvIndex] & 255;
          final vVal = vPlane.bytes[uvIndex] & 255;

          final rgbIndex =
              (y * width + x) * 3;

          rgbData[rgbIndex] =
              (yVal + 1.402 * (vVal - 128))
                  .toInt()
                  .clamp(0,255);

          rgbData[rgbIndex+1] =
              (
                  yVal
                      -0.344*(uVal-128)
                      -0.714*(vVal-128)
              )
                  .toInt()
                  .clamp(0,255);

          rgbData[rgbIndex+2] =
              (yVal + 1.772*(uVal-128))
                  .toInt()
                  .clamp(0,255);
        }
      }

      final rgbImage =
      img.Image(
          width: width,
          height: height
      );

      for(int y=0;y<height;y++){
        for(int x=0;x<width;x++){
          int i=(y*width+x)*3;
          rgbImage.setPixelRgb(
              x,
              y,
              rgbData[i],
              rgbData[i+1],
              rgbData[i+2]
          );
        }
      }

      final resized=
      img.copyResize(
          rgbImage,
          width:320,
          height:240
      );

      final jpegBytes=
      Uint8List.fromList(
          img.encodeJpg(
              resized,
              quality:80
          )
      );

      return base64Encode(
          jpegBytes
      );
    }
    catch(e){
      print(e);
      return null;
    }
  }



  Future<void> _sendFrameToBackend(
      CameraImage image
      ) async {

    if(
    _isProcessing ||
        _currentTarget.isEmpty ||
        isPaused
    ) return;

    _isProcessing = true;

    try{
      print("Sending frame...");
      print("Target: $_currentTarget");

      final base64Image =
      await _convertImageToBase64(image);

      if(base64Image==null){
        print("Image conversion failed");
        _isProcessing=false;
        return;
      }

      final response =
      await http.post(
        Uri.parse(_backendUrl),
        headers:{
          'Content-Type':'application/json'
        },
        body:jsonEncode({
          'image':base64Image,
          'target':_currentTarget,
        }),
      );

      print("Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {

        final data = jsonDecode(response.body);

        final message = data['voice_message'] ?? data['message'];

        if (message != null && message.toString().isNotEmpty) {

          // STOP camera processing first
          _isProcessing = true;

          await _controller?.stopImageStream();

          setState(() {
            _currentTarget = "";
          });

          print("FOUND MESSAGE: $message");

          // await _speak(message);

          String finalMessage = message;

          // 🔥 Replace "object" with actual label
          final label = data['label'] ?? _currentTarget;

          if (label != null && label.toString().isNotEmpty) {
            finalMessage = finalMessage.replaceAll("object", label);
          }

          // 🔥 Then translate
          if (_isUrduMode()) {
            finalMessage = _translateToUrdu(finalMessage);
          }

          // 🟢 Wait if something is already speaking
          while (_isSpeaking) {
            await Future.delayed(const Duration(milliseconds: 100));
          }

          await _speak(finalMessage);
          // restart camera stream
          await _controller?.startImageStream(_processCameraImage);

          _isProcessing = false;

          _listenForTargetObject();
        }
      }
    }
    catch(e){
      print("BACKEND ERROR:");
      print(e);
    }
    finally{
      _isProcessing=false;
    }
  }


  Future<void> _pauseResumeCamera() async{

    if(_controller==null) return;

    final strings=
    AppLocalizations.of(context);

    setState((){
      isPaused=!isPaused;
    });

    if(isPaused){
      await _controller!.pausePreview();
      await _speak(
          strings.translate(
              'detection_paused'
          )
      );
    }
    else{
      await _controller!.resumePreview();
      await _speak(
          strings.translate(
              'detection_resumed'
          )
      );
    }
  }


  Future<void> _stopCamera() async{

    _targetTimeout?.cancel();

    _voiceService.clearScreenCommands();
    _voiceService.resume();

    await _controller?.stopImageStream();

    final strings=
    AppLocalizations.of(context);

    await _interruptAndSpeak(
        strings.translate('target_stopped')
    );


    await Future.delayed(
        const Duration(
            milliseconds:800
        )
    );

    if(mounted){
      Navigator.pop(
          context,
          true
      );
    }
  }


  Future<void> _resetSearch() async{

    setState((){
      _currentTarget="";
    });

    await _interruptAndSpeak(
        _isUrduMode()
            ? "تلاش ری سیٹ ہو گئی"
            : "Search reset"
    );

    _listenForTargetObject();
  }

////////////////////////////////////////////////////////
// ORIGINAL UI KEPT
////////////////////////////////////////////////////////

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<AppSettings>(context);

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(
          textScaleFactor:
          settings.largeText
              ?1.5
              :1.0
      ),
      child: _buildBody(settings),
    );
  }


  Widget _buildBody(
      AppSettings settings
      ) {

    final strings=
    AppLocalizations.of(context);

    final isUrdu=
        settings.language=="Urdu";

    final voiceActive=
        _voiceService.isActive;

    if(
    _controller==null ||
        !_controller!.value.isInitialized
    ){
      return Scaffold(
        backgroundColor:
        const Color(0xFF0A0E21),
        body:Center(
          child:Column(
            mainAxisAlignment:
            MainAxisAlignment.center,
            children:[
              const CircularProgressIndicator(),
              SizedBox(height:20),
              Text(
                strings.translate(
                    'init_camera'
                ),
                style:TextStyle(
                    color:Colors.white
                ),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
      const Color(0xFF0A0E21),
      body:Column(
        children:[

          Container(
            padding:
            const EdgeInsets.only(
                top:35,
                bottom:10
            ),
            decoration:
            const BoxDecoration(
                gradient:LinearGradient(
                    colors:[
                      Color(0xFF1A237E),
                      Color(0xFF0A0E21)
                    ]
                )
            ),
            child:Column(
              children:[

                Padding(
                  padding:
                  const EdgeInsets.symmetric(
                      horizontal:15
                  ),
                  child:Row(
                    children:[
                      IconButton(
                        icon:Icon(
                            Icons.arrow_back_ios_new,
                            color:Colors.white
                        ),
                        onPressed:_stopCamera,
                      ),
                      Expanded(
                        child:Text(
                          strings.translate(
                              'target_search_title'
                          ),
                          textAlign:
                          TextAlign.center,
                          style:TextStyle(
                              color:Colors.white,
                              fontSize:20,
                              fontWeight:
                              FontWeight.bold
                          ),
                        ),
                      ),
                      Text(
                        _isProcessing
                            ?"..."
                            :"●",
                        style:TextStyle(
                            color:
                            _isProcessing
                                ?Colors.orange
                                :Colors.green
                        ),
                      )
                    ],
                  ),
                ),

                SizedBox(height:10),

                if(_currentTarget.isNotEmpty)
                  Text(
                    isUrdu
                        ?"تلاش: $_currentTarget"
                        :"Searching for: $_currentTarget",
                    style:TextStyle(
                        color:Colors.green
                    ),
                  )
                else if(_waitingForTarget)
                  Column(
                    children:[
                      Text(
                        isUrdu
                            ?"اپنا ہدف بتائیں"
                            :"Speak your target",
                        style:TextStyle(
                            color:Colors.yellow
                        ),
                      ),
                      if(_heardText.isNotEmpty)
                        Text(
                          "Heard: $_heardText",
                          style:TextStyle(
                              color:
                              Colors.lightBlueAccent
                          ),
                        )
                    ],
                  )
                else
                  Text(
                    'Say "find laptop"',
                    style:TextStyle(
                        color:Colors.white70
                    ),
                  )
              ],
            ),
          ),

          Expanded(
            child:Container(
              margin:
              const EdgeInsets.all(10),
              decoration:BoxDecoration(
                  borderRadius:
                  BorderRadius.circular(15)
              ),
              child:ClipRRect(
                borderRadius:
                BorderRadius.circular(15),
                child:CameraPreview(
                    _controller!
                ),
              ),
            ),
          ),

          Container(
            padding:
            const EdgeInsets.only(
                top:10,
                bottom:25,
                left:30,
                right:30
            ),
            child:Column(
              children:[

                Container(
                  padding:
                  const EdgeInsets.symmetric(
                      horizontal:20,
                      vertical:8
                  ),
                  decoration:BoxDecoration(
                    color:
                    _waitingForTarget
                        ?Colors.red.withOpacity(.15)
                        :isPaused
                        ?Colors.orange.withOpacity(.15)
                        :Colors.green.withOpacity(.15),
                    borderRadius:
                    BorderRadius.circular(15),
                  ),
                  child:Row(
                    mainAxisSize:
                    MainAxisSize.min,
                    children:[
                      Icon(
                        _waitingForTarget
                            ?Icons.mic
                            :isPaused
                            ?Icons.pause
                            :Icons.play_arrow,
                        color:
                        _waitingForTarget
                            ?Colors.red
                            :isPaused
                            ?Colors.orange
                            :Colors.green,
                      ),
                      SizedBox(width:6),
                      Text(
                        _waitingForTarget
                            ?"Listening..."
                            :isPaused
                            ?strings.translate('paused')
                            :strings.translate('active'),
                        style:TextStyle(
                            color:Colors.white
                        ),
                      )
                    ],
                  ),
                ),

                SizedBox(height:20),

                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceEvenly,
                  children:[

                    _buildEnhancedButton(
                      icon:Icons.mic,
                      label:
                      isUrdu
                          ?"ہدف بتائیں"
                          :"Set Target",
                      onTap:
                      _listenForTargetObject,
                      gradient:[
                        Color(0xFF2196F3),
                        Color(0xFF1976D2)
                      ],
                      iconSize:28,
                      buttonSize:60,
                    ),

                    _buildEnhancedButton(
                      icon:
                      isPaused
                          ?Icons.play_arrow_rounded
                          :Icons.pause_rounded,
                      label:
                      isPaused
                          ?strings.translate('resume')
                          :strings.translate('pause'),
                      onTap:
                      _pauseResumeCamera,
                      gradient:[
                        Color(0xFFFFB347),
                        Color(0xFFFF7A18)
                      ],
                    ),

                    _buildEnhancedButton(
                      icon:Icons.stop_rounded,
                      label:
                      strings.translate('stop'),
                      onTap:
                      _stopCamera,
                      gradient:[
                        Color(0xFFFF416C),
                        Color(0xFFFF4B2B)
                      ],
                    ),
                  ],
                ),

                SizedBox(height:10),

                if(_currentTarget.isNotEmpty)
                  GestureDetector(
                    onTap:_resetSearch,
                    child:Text(
                      "Reset Search",
                      style:TextStyle(
                          color:Colors.white54
                      ),
                    ),
                  ),

                SizedBox(height:5),

                Row(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children:[
                    Icon(
                      voiceActive
                          ?Icons.mic
                          :Icons.mic_off,
                      size:12,
                      color:
                      voiceActive
                          ?Colors.green
                          :Colors.grey,
                    ),
                    SizedBox(width:4),
                    Text(
                      voiceActive
                          ?"Voice active"
                          :"Voice paused",
                      style:TextStyle(
                        fontSize:10,
                        color:
                        voiceActive
                            ?Colors.green
                            :Colors.grey,
                      ),
                    )
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }


  Widget _buildEnhancedButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required List<Color> gradient,
    double iconSize=36,
    double buttonSize=70,
  }){
    return Column(
      children:[
        InkWell(
          onTap:onTap,
          child:Container(
            width:buttonSize,
            height:buttonSize,
            decoration:BoxDecoration(
              gradient:LinearGradient(
                  colors:gradient
              ),
              shape:BoxShape.circle,
            ),
            child:Center(
              child:Icon(
                icon,
                color:Colors.white,
                size:iconSize,
              ),
            ),
          ),
        ),
        SizedBox(height:8),
        Text(
          label,
          style:TextStyle(
            color:Colors.white70,
            fontSize:11,
            fontWeight:
            FontWeight.w600,
          ),
        )
      ],
    );
  }

}