import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_settings.dart';

class AppLocalizations {
  final String language;

  AppLocalizations(this.language);

  // Returns the localized string for a given key
  String translate(String key) {
    if (language == 'Urdu') {
      return _urduStrings[key] ?? _englishStrings[key]!;
    } else {
      return _englishStrings[key]!;
    }
  }

  // Convenience method to get from BuildContext
  static AppLocalizations of(BuildContext context) {
    final settings = Provider.of<AppSettings>(context, listen: false);
    return AppLocalizations(settings.language);
  }

  // English strings (default)
  static final Map<String, String> _englishStrings = {
    // Splash
    'welcome_splash': 'Welcome to Lumina App. Seeing Beyond Vision',

    // Home screen
    'welcome_home': 'Welcome to home. How can I assist you today? For object detection, select object detection. To search something specific, select target search. To change settings, select settings.',
    'home_title': 'HOME',
    'home_subtitle': 'How can I assist you today?',
    'object_detection': 'Object Detection',
    'object_detection_sub': 'Identify objects around you',
    'target_search': 'Target Search',
    'target_search_sub': 'Find specific items',
    'settings': 'Settings',
    'settings_sub': 'Customize your experience',
    'voice_guidance_active': 'Voice guidance is active. Tap any option for audio feedback.',

    // Detection screen
    'live_detection_started': 'Live Detection Started.',
    'detection_resumed': 'Detection resumed',
    'detection_paused': 'Detection paused',
    'detection_stopped': 'Detection stopped returning to home screen',
    'init_camera': 'Initializing Camera...',
    'live_object_detection': 'Live Object Detection',
    'identifying_objects': 'Identifying objects in real-time',
    'detecting': 'DETECTING',
    'paused': 'PAUSED',
    'resume': 'RESUME',
    'pause': 'PAUSE',
    'stop': 'STOP',

    // Target screen
    'target_start': 'Please tell which specific object you want to detect.',
    'target_stopped': 'Detection stopped returning to home screen',
    'target_search_title': 'Target Object Search',
    'target_subtitle': 'Speak object name to search',
    'active': 'ACTIVE',

    // Settings screen
    'settings_title': 'Settings',
    'returning_home': 'Returning to home screen.',
    'returning_about': 'Returning to About page.',
    'returning_help': 'Returning to Help page.',
    'opening_help': 'Opening help screen.',
    'opening_about': 'Opening about screen.',
    'language': 'Language',
    'volume': 'Volume',
    'high_contrast': 'High Contrast Mode',
    'high_contrast_sub': 'Enhances visibility for better readability',
    'large_text': 'Large Text Size',
    'large_text_sub': 'Increases text size for better readability',
    'about_lumina': 'About Lumina',
    'select_language': 'Select Language',
    'english': 'English',
    'urdu': 'Urdu',
    'settings_announce': 'You are on the settings page. Options available are language, volume, high contrast, large text, about, and help.',
    'about_announce': 'Returning from About page.',
    'help_announce': 'Returning from Help page.',

    // About screen
    'about_lumina_title': 'ABOUT LUMINA',
    'about_subtitle': 'Seeing Beyond Vision',
    'app_name': 'App Name',
    'version': 'Version',
    'purpose': 'Purpose',
    'purpose_content': 'Helps visually impaired users navigate the app, adjust accessibility settings, and use text to speech features.',
    'developer': 'Developer',
    'contact': 'Contact',
    'our_mission': 'Our Mission',
    'mission_text': 'To empower visually impaired individuals with technology that enhances independence, accessibility, and confidence in navigating the world around them.',
    'returning_to_settings': 'Returning to Settings screen.',

    // Help screen
    'help_title': 'HELP GUIDE',
    'help_subtitle': 'Tap any section to hear guidance',
    'navigation': 'Navigation',
    'navigation_content': 'Use the back button to go to previous screens and swipe gestures for quick navigation.',
    'settings_help': 'Settings',
    'settings_help_content': 'Adjust language and volume from the settings screen.',
    'about_page': 'About Page',
    'about_page_content': 'Learn about the app, version, developer, and contact information.',
    'object_detection_help': 'Object Detection',
    'object_detection_help_content': 'Detect objects in your surroundings using the camera. The app will describe what it sees.',
    'target_search_help': 'Target Search',
    'target_search_help_content': 'Search for a specific object by name, and the app will help you locate it.',
    'voice_control': 'Voice Control',
    'voice_control_content': 'This app is voice-operated. You can give commands or tap buttons for guidance.',
    'help_help': 'Help',
    'help_help_content': 'You are currently on the Help screen for guidance.',
    'voice_guidance_card': 'Voice Guidance',
    'voice_guidance_card_text': 'This app will automatically read each section. Tap any section to hear it again.',
    'help_page_announce': 'You are on the Help screen. This app is voice operated. Here is guidance for all its features.',
    'returning_from_help': 'Returning from Help page.',

    // Generic
    'returning_home_screen': 'Returning to Home screen.',
  };

  // Urdu strings (key same as English)
  static final Map<String, String> _urduStrings = {
    'welcome_splash': 'لومینا ایپ میں خوش آمدید۔ بصارت سے آگے دیکھنا',
    'welcome_home': 'ہوم پیج پر خوش آمدید۔ میں آپ کی کیا مدد کر سکتی ہوں؟ آبجیکٹ ڈیٹیکشن کے لیے آبجیکٹ ڈیٹیکشن منتخب کریں۔ کسی خاص چیز کو تلاش کرنے کے لیے ٹارگٹ سرچ منتخب کریں۔ سیٹنگز تبدیل کرنے کے لیے سیٹنگز منتخب کریں۔',
    'home_title': 'ہوم',
    'home_subtitle': 'آج میں آپ کی کس طرح مدد کر سکتی ہوں؟',
    'object_detection': ' آبجیکٹ ڈیٹیکشن',
    'object_detection_sub': 'اپنے ارد گرد کی چیزوں کو پہچانیں',
    'target_search': 'ٹارگٹ سرچ',
    'target_search_sub': 'مخصوص اشیاء تلاش کریں',
    'settings': 'سیٹنگز',
    'settings_sub': 'اپنا تجربہ حسب ضرورت بنائیں',
    'voice_guidance_active': 'وائس گائیڈنس فعال ہے۔ آڈیو فیڈ بیک کے لیے کسی بھی آپشن کو تھپتھپائیں۔',
    'live_detection_started': 'لائیو ڈیٹیکشن شروع ہو گئی۔',
    'detection_resumed': 'ڈیٹیکشن دوبارہ شروع ہوئی',
    'detection_paused': 'ڈیٹیکشن روک دی گئی',
    'detection_stopped': 'ڈیٹیکشن بند ہوئی، ہوم اسکرین پر واپس جا رہے ہیں',
    'init_camera': 'کیمرہ شروع ہو رہا ہے...',
    'live_object_detection': 'لائیو آبجیکٹ ڈیٹیکشن',
    'identifying_objects': 'ریئل ٹائم میں اشیاء کی شناخت',
    'detecting': 'شناخت ہو رہی ہے',
    'paused': 'روکا گیا',
    'resume': 'دوبارہ شروع کریں',
    'pause': 'روکیں',
    'stop': 'بند کریں',
    'target_start': 'براہ کرم بتائیں کہ آپ کون سی مخصوص چیز ڈھونڈنا چاہتے ہیں۔',
    'target_stopped': 'ڈیٹیکشن بند ہوئی، ہوم اسکرین پر واپس جا رہے ہیں',
    'target_search_title': 'ٹارگٹ آبجیکٹ سرچ',
    'target_subtitle': 'تلاش کے لیے چیز کا نام بولیں',
    'active': 'فعال',
    'settings_title': 'سیٹنگز',
    'returning_home': 'ہوم اسکرین پر واپس جا رہے ہیں۔',
    'returning_about': 'اباؤٹ پیج پر واپس جا رہے ہیں۔',
    'returning_help': 'ہیلپ پیج پر واپس جا رہے ہیں۔',
    'opening_help': 'ہیلپ اسکرین کھولی جا رہی ہے۔',
    'opening_about': 'اباؤٹ اسکرین کھولی جا رہی ہے۔',
    'language': 'زبان',
    'volume': 'والِیُوم',
    'high_contrast': 'ہائی کنٹراسٹ موڈ',
    'high_contrast_sub': 'بہتر پڑھنے کے لیے مرئیت بڑھاتا ہے',
    'large_text': 'لارج ٹیکسٹ',
    'large_text_sub': 'بہتر پڑھنے کے لیے متن کا سائز بڑھاتا ہے',
    'about_lumina': 'لومینا کے بارے میں',
    'select_language': 'زبان منتخب کریں',
    'english': 'انگریزی',
    'urdu': 'اردو',
    'settings_announce': 'آپ سیٹنگز پیج پر ہیں۔ دستیاب اختیارات: زبان، آواز کی بلندی، ہائی کنٹراسٹ، لارج ٹیکسٹ، اباؤٹ، اور ہیلپ۔',
    'about_announce': 'اباؤٹ پیج سے واپس آ رہے ہیں۔',
    'help_announce': 'ہیلپ پیج سے واپس آ رہے ہیں۔',
    'about_lumina_title': 'لومینا کے بارے میں',
    'about_subtitle': 'بصارت سے آگے دیکھنا',
    'app_name': 'ایپ کا نام',
    'version': 'ورژن',
    'purpose': 'مقصد',
    'purpose_content': 'بصارت سے محروم صارفین کو ایپ نیویگیٹ کرنے، رسائی کی ترتیبات ایڈجسٹ کرنے، اور ٹیکسٹ ٹو اسپیچ فیچرز استعمال کرنے میں مدد کرتا ہے۔',
    'developer': 'ڈویلپر',
    'contact': 'رابطہ',
    'our_mission': 'ہمارا مشن',
    'mission_text': 'بصارت سے محروم افراد کو ٹیکنالوجی کے ذریعے بااختیار بنانا جو ان کی آزادی، رسائی، اور اپنے ارد گرد کی دنیا میں اعتماد کو بڑھاتی ہے۔',
    'returning_to_settings': 'سیٹنگز اسکرین پر واپس جا رہے ہیں۔',
    'help_title': 'ہیلپ گائیڈ',
    'help_subtitle': 'رہنمائی سننے کے لیے کسی بھی سیکشن کو تھپتھپائیں',
    'navigation': 'نیویگیشن',
    'navigation_content': 'پچھلی اسکرینوں پر جانے کے لیے بیک بٹن اور فوری نیویگیشن کے لیے سوائپ اشاروں کا استعمال کریں۔',
    'settings_help': 'ترتیبات',
    'settings_help_content': 'سیٹنگز اسکرین سے زبان اور آواز کی بلندی ایڈجسٹ کریں۔',
    'about_page': 'اباؤٹ پیج',
    'about_page_content': 'ایپ، ورژن، ڈویلپر، اور رابطہ کی معلومات جانیں۔',
    'object_detection_help': 'آبجیکٹ ڈیٹیکشن',
    'object_detection_help_content': 'کیمرے کا استعمال کرتے ہوئے اپنے ارد گرد کی اشیاء کا پتہ لگائیں۔ ایپ بتائے گی کہ وہ کیا دیکھ رہی ہے۔',
    'target_search_help': 'ٹارگٹ سرچ',
    'target_search_help_content': 'نام سے کسی مخصوص چیز کو تلاش کریں، اور ایپ آپ کو اسے تلاش کرنے میں مدد دے گی۔',
    'voice_control': 'وائس کنٹرول',
    'voice_control_content': 'یہ ایپ آواز سے چلتی ہے۔ آپ کمانڈ دے سکتے ہیں یا رہنمائی کے لیے بٹن تھپتھپا سکتے ہیں۔',
    'help_help': 'ہیلپ',
    'help_help_content': 'آپ فی الحال ہیلپ اسکرین پر ہیں رہنمائی کے لیے۔',
    'voice_guidance_card': 'وائس گائیڈنس',
    'voice_guidance_card_text': 'یہ ایپ خود بخود ہر سیکشن کو پڑھے گی۔ کسی بھی سیکشن کو دوبارہ سننے کے لیے تھپتھپائیں۔',
    'help_page_announce': 'آپ ہیلپ اسکرین پر ہیں۔ یہ ایپ آواز سے چلتی ہے۔ یہاں اس کی تمام خصوصیات کے لیے رہنمائی ہے۔',
    'returning_from_help': 'ہیلپ پیج سے واپس آ رہے ہیں۔',
    'returning_home_screen': 'ہوم اسکرین پر واپس جا رہے ہیں۔',
  };
}