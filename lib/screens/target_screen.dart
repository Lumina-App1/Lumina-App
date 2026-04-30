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

  // SINGLE recognizer mode state
  bool _waitingForTarget = false;
  String _heardText = "";
  Timer? _targetTimeout;
  DateTime? _lastSpokenTime;

  final String _backendUrl = "http://10.233.20.154:5000/search";

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
  //
  //   try {
  //     final settings =
  //     Provider.of<AppSettings>(
  //       context,
  //       listen: false,
  //     );
  //
  //     await settings.tts.stop();
  //     await settings.tts.speak(text);
  //   }
  //   catch (e) {
  //     print(e);
  //   }
  // }
  Future<void> _speak(String text) async {
    try {
      if (text.trim().isEmpty) return;

      final settings = Provider.of<AppSettings>(
        context,
        listen: false,
      );

      print("🔊 Speaking: $text");

      // 🔴 STOP MIC BEFORE SPEAKING
      _voiceService.pause();

      await settings.tts.stop();
      await settings.tts.speak(text);

      // Wait until speech completes (important)
      await Future.delayed(Duration(seconds: 2));

    } catch (e) {
      print("TTS ERROR:");
      print(e);
    } finally {
      // 🟢 RESUME MIC AFTER SPEAKING
      _voiceService.resume();
    }
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

      if (command.isEmpty) {
        return;
      }

      String target = _cleanTarget(command);

      if (target.isEmpty) {
        return;
      }

      _targetTimeout?.cancel();

      setState(() {
        _waitingForTarget = false;
        _heardText = target;
        _currentTarget = target;
      });

      _speak(
          _isUrduMode()
              ? "$target تلاش کر رہا ہوں"
              : "Searching for $target"
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
          'واپس'
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
          'روکو'
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
          'ریزیوم'
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
          'reset',
          'change target',
          'new target'
        ]
    )) {
      _resetSearch();
      return;
    }


    if (_matchesAny(
        command,
        [
          'set target',
          'find',
          'search',
          'ہدف',
          'فائنڈ'
        ]
    )) {
      _listenForTargetObject();
      return;
    }
  }


  // String _cleanTarget(
  //     String raw,
  //     ) {
  //
  //   String text =
  //   raw.toLowerCase().trim();
  //
  //   final prefixes = [
  //     'find ',
  //     'search for ',
  //     'look for ',
  //     'detect ',
  //     'ڈھونڈو ',
  //     'فائنڈ '
  //   ];
  //
  //   for (final p in prefixes) {
  //     if (text.startsWith(p)) {
  //       text = text.substring(
  //           p.length
  //       ).trim();
  //       break;
  //     }
  //   }
  //
  //   return text;
  // }

  // String _cleanTarget(String raw){
  //
  //   String text =
  //   raw.toLowerCase().trim();
  //
  //   final prefixes=[
  //     'find ',
  //     'search ',
  //     'search for ',
  //     'look for ',
  //     'detect ',
  //     'find my ',
  //     'ڈھونڈو ',
  //     'فائنڈ '
  //   ];
  //
  //   for(final p in prefixes){
  //     if(text.startsWith(p)){
  //       text=text.substring(
  //           p.length
  //       ).trim();
  //       break;
  //     }
  //   }
  //
  //   return text;
  // }

  String _cleanTarget(String raw) {
    String text = raw.toLowerCase().trim();

    final prefixes = [
      'say what to find ',
      'find ',
      'search for ',
      'search ',
      'look for ',
      'detect ',
      'find my ',
      'ڈھونڈو ',
      'فائنڈ '
    ];

    for (final p in prefixes) {
      if (text.startsWith(p)) {
        text = text.substring(p.length).trim();
        break;
      }
    }

    return text;
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


  // Future<void> _sendFrameToBackend(
  //     CameraImage image
  //     ) async {
  //
  //   if(
  //   _isProcessing ||
  //       _currentTarget.isEmpty ||
  //       isPaused
  //   ) return;
  //
  //   _isProcessing=true;
  //
  //   try{
  //
  //     final base64Image=
  //     await _convertImageToBase64(
  //         image
  //     );
  //
  //     if(base64Image==null){
  //       _isProcessing=false;
  //       return;
  //     }
  //
  //     final response=
  //     await http.post(
  //       Uri.parse(_backendUrl),
  //       headers:{
  //         'Content-Type':'application/json'
  //       },
  //       body:jsonEncode({
  //         'image':base64Image,
  //         'target':_currentTarget,
  //       }),
  //     );
  //
  //     if(response.statusCode==200){
  //
  //       final data=
  //       jsonDecode(
  //           response.body
  //       );
  //
  //       if(data['voice_message']!=null){
  //         await _speak(
  //             data['voice_message']
  //         );
  //       }
  //
  //       // if(
  //       // data['meters']!=null &&
  //       //     data['meters']<0.8
  //       // ){
  //       //   await _speak(
  //       //       "Target is within reach"
  //       //   );
  //       //
  //       //   setState((){
  //       //     _currentTarget="";
  //       //   });
  //       // }
  //     }
  //   }
  //   catch(e){
  //     print(e);
  //   }
  //   finally{
  //     _isProcessing=false;
  //   }
  // }

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

      // if(response.statusCode==200){
      //
      //   final data =
      //   jsonDecode(response.body);
      //
      //   // if(data['voice_message'] != null){
      //   //   await _speak(
      //   //       data['voice_message']
      //   //   );
      //   // }
      //   final message = data['voice_message'] ?? data['message'];
      //
      //   if (message != null && message.toString().isNotEmpty) {
      //     await _speak(message);
      //   }
      // }
      if (response.statusCode == 200) {

        final data = jsonDecode(response.body);

        final message = data['voice_message'] ?? data['message'];

        if (message != null && message.toString().isNotEmpty) {

          final now = DateTime.now();

          // ✅ Check if 3 seconds have passed
          if (_lastSpokenTime == null ||
              now.difference(_lastSpokenTime!) > Duration(seconds: 3)) {

            _lastSpokenTime = now;

            await _speak(message);
          }
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

    await _speak(
        strings.translate(
            'target_stopped'
        )
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

    await _speak(
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