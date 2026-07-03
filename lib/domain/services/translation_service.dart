import 'dart:convert';

import 'package:dio/dio.dart';

/// Translation Provider types
enum TranslationProvider {
  google('google', 'Google Translate'),
  deepl('deepl', 'DeepL'),
  libre('libre', 'LibreTranslate'),
  ;

  final String id;
  final String displayName;

  const TranslationProvider(this.id, this.displayName);

  static TranslationProvider? fromId(String id) {
    try {
      return TranslationProvider.values.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// Translation Settings
class TranslationSettings {
  final bool enabled;
  final TranslationProvider provider;
  final String sourceLanguage;
  final String targetLanguage;
  final bool autoTranslateIncoming;
  final bool autoTranslateOutgoing;
  final bool showOriginal;
  final String? apiKey;
  final String? apiEndpoint;

  const TranslationSettings({
    this.enabled = false,
    this.provider = TranslationProvider.google,
    this.sourceLanguage = 'auto',
    this.targetLanguage = 'en',
    this.autoTranslateIncoming = false,
    this.autoTranslateOutgoing = false,
    this.showOriginal = true,
    this.apiKey,
    this.apiEndpoint,
  });

  TranslationSettings copyWith({
    bool? enabled,
    TranslationProvider? provider,
    String? sourceLanguage,
    String? targetLanguage,
    bool? autoTranslateIncoming,
    bool? autoTranslateOutgoing,
    bool? showOriginal,
    String? apiKey,
    String? apiEndpoint,
  }) {
    return TranslationSettings(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      autoTranslateIncoming: autoTranslateIncoming ?? this.autoTranslateIncoming,
      autoTranslateOutgoing: autoTranslateOutgoing ?? this.autoTranslateOutgoing,
      showOriginal: showOriginal ?? this.showOriginal,
      apiKey: apiKey ?? this.apiKey,
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'provider': provider.id,
        'sourceLanguage': sourceLanguage,
        'targetLanguage': targetLanguage,
        'autoTranslateIncoming': autoTranslateIncoming,
        'autoTranslateOutgoing': autoTranslateOutgoing,
        'showOriginal': showOriginal,
        'apiKey': apiKey,
        'apiEndpoint': apiEndpoint,
      };

  factory TranslationSettings.fromJson(Map<String, dynamic> json) => TranslationSettings(
        enabled: json['enabled'] as bool? ?? false,
        provider: TranslationProvider.fromId(json['provider'] as String? ?? 'google') ?? TranslationProvider.google,
        sourceLanguage: json['sourceLanguage'] as String? ?? 'auto',
        targetLanguage: json['targetLanguage'] as String? ?? 'en',
        autoTranslateIncoming: json['autoTranslateIncoming'] as bool? ?? false,
        autoTranslateOutgoing: json['autoTranslateOutgoing'] as bool? ?? false,
        showOriginal: json['showOriginal'] as bool? ?? true,
        apiKey: json['apiKey'] as String?,
        apiEndpoint: json['apiEndpoint'] as String?,
      );
}

/// Supported languages for translation
class TranslationLanguage {
  final String code;
  final String name;
  final String nativeName;

  const TranslationLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  static const List<TranslationLanguage> supportedLanguages = [
    TranslationLanguage(code: 'auto', name: 'Auto-detect', nativeName: 'Auto'),
    TranslationLanguage(code: 'en', name: 'English', nativeName: 'English'),
    TranslationLanguage(code: 'es', name: 'Spanish', nativeName: 'Español'),
    TranslationLanguage(code: 'fr', name: 'French', nativeName: 'Français'),
    TranslationLanguage(code: 'de', name: 'German', nativeName: 'Deutsch'),
    TranslationLanguage(code: 'it', name: 'Italian', nativeName: 'Italiano'),
    TranslationLanguage(code: 'pt', name: 'Portuguese', nativeName: 'Português'),
    TranslationLanguage(code: 'ru', name: 'Russian', nativeName: 'Русский'),
    TranslationLanguage(code: 'ja', name: 'Japanese', nativeName: '日本語'),
    TranslationLanguage(code: 'ko', name: 'Korean', nativeName: '한국어'),
    TranslationLanguage(code: 'zh', name: 'Chinese (Simplified)', nativeName: '简体中文'),
    TranslationLanguage(code: 'zh-TW', name: 'Chinese (Traditional)', nativeName: '繁體中文'),
    TranslationLanguage(code: 'ar', name: 'Arabic', nativeName: 'العربية'),
    TranslationLanguage(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
    TranslationLanguage(code: 'th', name: 'Thai', nativeName: 'ไทย'),
    TranslationLanguage(code: 'vi', name: 'Vietnamese', nativeName: 'Tiếng Việt'),
    TranslationLanguage(code: 'nl', name: 'Dutch', nativeName: 'Nederlands'),
    TranslationLanguage(code: 'pl', name: 'Polish', nativeName: 'Polski'),
    TranslationLanguage(code: 'tr', name: 'Turkish', nativeName: 'Türkçe'),
    TranslationLanguage(code: 'uk', name: 'Ukrainian', nativeName: 'Українська'),
    TranslationLanguage(code: 'id', name: 'Indonesian', nativeName: 'Bahasa Indonesia'),
    TranslationLanguage(code: 'ms', name: 'Malay', nativeName: 'Bahasa Melayu'),
    TranslationLanguage(code: 'sv', name: 'Swedish', nativeName: 'Svenska'),
    TranslationLanguage(code: 'da', name: 'Danish', nativeName: 'Dansk'),
    TranslationLanguage(code: 'fi', name: 'Finnish', nativeName: 'Suomi'),
    TranslationLanguage(code: 'no', name: 'Norwegian', nativeName: 'Norsk'),
    TranslationLanguage(code: 'cs', name: 'Czech', nativeName: 'Čeština'),
    TranslationLanguage(code: 'el', name: 'Greek', nativeName: 'Ελληνικά'),
    TranslationLanguage(code: 'he', name: 'Hebrew', nativeName: 'עברית'),
    TranslationLanguage(code: 'ro', name: 'Romanian', nativeName: 'Română'),
    TranslationLanguage(code: 'hu', name: 'Hungarian', nativeName: 'Magyar'),
  ];

  /// Get languages excluding auto-detect (for target language)
  static List<TranslationLanguage> get targetLanguages =>
      supportedLanguages.where((l) => l.code != 'auto').toList();

  static TranslationLanguage? fromCode(String code) {
    try {
      return supportedLanguages.firstWhere((l) => l.code == code);
    } catch (_) {
      return null;
    }
  }
}

/// Translation result
class TranslationResult {
  final String originalText;
  final String translatedText;
  final String sourceLanguage;
  final String targetLanguage;
  final double? confidence;

  const TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.confidence,
  });
}

/// Translation Service
class TranslationService {
  TranslationSettings _settings = const TranslationSettings();
  final Dio _dio;

  TranslationService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
            ));

  /// Callbacks
  void Function(String)? onError;

  TranslationSettings get settings => _settings;

  /// Update settings
  void updateSettings(TranslationSettings settings) {
    _settings = settings;
  }

  /// Translate text
  Future<TranslationResult?> translate(
    String text, {
    String? sourceLanguage,
    String? targetLanguage,
  }) async {
    if (!_settings.enabled) return null;
    if (text.isEmpty) return null;

    final source = sourceLanguage ?? _settings.sourceLanguage;
    final target = targetLanguage ?? _settings.targetLanguage;

    // Don't translate if source and target are the same
    if (source == target && source != 'auto') {
      return TranslationResult(
        originalText: text,
        translatedText: text,
        sourceLanguage: source,
        targetLanguage: target,
      );
    }

    try {
      switch (_settings.provider) {
        case TranslationProvider.google:
          return await _translateWithGoogle(text, source, target);
        case TranslationProvider.deepl:
          return await _translateWithDeepL(text, source, target);
        case TranslationProvider.libre:
          return await _translateWithLibre(text, source, target);
      }
    } catch (e) {
      onError?.call('Translation error: $e');
      return null;
    }
  }

  /// Google Translate via the free web endpoint (no API key required)
  Future<TranslationResult> _translateWithGoogle(
      String text, String source, String target) async {
    final response = await _dio.get<dynamic>(
      'https://translate.googleapis.com/translate_a/single',
      queryParameters: {
        'client': 'gtx',
        'sl': source,
        'tl': target,
        'dt': 't',
        'q': text,
      },
    );

    // Response shape: [[["translated","original",...], ...], null, "detectedLang", ...]
    final data = response.data is String
        ? jsonDecode(response.data as String)
        : response.data;
    final segments = data[0] as List<dynamic>;
    final translated =
        segments.map((s) => (s as List<dynamic>)[0] as String? ?? '').join();
    final detectedSource =
        data.length > 2 && data[2] is String ? data[2] as String : source;

    return TranslationResult(
      originalText: text,
      translatedText: translated,
      sourceLanguage: detectedSource,
      targetLanguage: target,
    );
  }

  /// DeepL API (requires API key; free keys end in ":fx")
  Future<TranslationResult> _translateWithDeepL(
      String text, String source, String target) async {
    final apiKey = _settings.apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('DeepL requires an API key');
    }

    final endpoint = _settings.apiEndpoint?.isNotEmpty == true
        ? _settings.apiEndpoint!
        : (apiKey.endsWith(':fx')
            ? 'https://api-free.deepl.com'
            : 'https://api.deepl.com');

    final response = await _dio.post<Map<String, dynamic>>(
      '$endpoint/v2/translate',
      options: Options(headers: {
        'Authorization': 'DeepL-Auth-Key $apiKey',
        'Content-Type': 'application/json',
      }),
      data: {
        'text': [text],
        'target_lang': target.toUpperCase(),
        if (source != 'auto') 'source_lang': source.toUpperCase(),
      },
    );

    final translations = response.data!['translations'] as List<dynamic>;
    final first = translations.first as Map<String, dynamic>;

    return TranslationResult(
      originalText: text,
      translatedText: first['text'] as String,
      sourceLanguage:
          (first['detected_source_language'] as String? ?? source).toLowerCase(),
      targetLanguage: target,
    );
  }

  /// LibreTranslate (self-hosted endpoint or libretranslate.com with API key)
  Future<TranslationResult> _translateWithLibre(
      String text, String source, String target) async {
    final endpoint = _settings.apiEndpoint?.isNotEmpty == true
        ? _settings.apiEndpoint!.replaceAll(RegExp(r'/+$'), '')
        : 'https://libretranslate.com';

    final response = await _dio.post<Map<String, dynamic>>(
      '$endpoint/translate',
      options: Options(headers: {'Content-Type': 'application/json'}),
      data: {
        'q': text,
        'source': source,
        'target': target,
        'format': 'text',
        if (_settings.apiKey?.isNotEmpty == true) 'api_key': _settings.apiKey,
      },
    );

    final data = response.data!;
    final detected = data['detectedLanguage'] as Map<String, dynamic>?;

    return TranslationResult(
      originalText: text,
      translatedText: data['translatedText'] as String,
      sourceLanguage: detected?['language'] as String? ?? source,
      targetLanguage: target,
      confidence: detected != null
          ? ((detected['confidence'] as num?)?.toDouble() ?? 0) / 100
          : null,
    );
  }

  /// Detect language of text using charset heuristics
  Future<String?> detectLanguage(String text) async {
    if (text.isEmpty) return null;

    try {
      if (_containsChinese(text)) return 'zh';
      if (_containsJapanese(text)) return 'ja';
      if (_containsKorean(text)) return 'ko';
      if (_containsArabic(text)) return 'ar';
      if (_containsCyrillic(text)) return 'ru';

      return 'en'; // Default to English
    } catch (e) {
      onError?.call('Language detection error: $e');
      return null;
    }
  }

  bool _containsChinese(String text) {
    return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
  }

  bool _containsJapanese(String text) {
    return RegExp(r'[\u3040-\u309f\u30a0-\u30ff]').hasMatch(text);
  }

  bool _containsKorean(String text) {
    return RegExp(r'[\uac00-\ud7af]').hasMatch(text);
  }

  bool _containsArabic(String text) {
    return RegExp(r'[\u0600-\u06ff]').hasMatch(text);
  }

  bool _containsCyrillic(String text) {
    return RegExp(r'[\u0400-\u04ff]').hasMatch(text);
  }

  /// Swap source and target languages
  void swapLanguages() {
    if (_settings.sourceLanguage == 'auto') return;
    
    _settings = _settings.copyWith(
      sourceLanguage: _settings.targetLanguage,
      targetLanguage: _settings.sourceLanguage,
    );
  }
}