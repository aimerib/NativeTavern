import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// STT Provider types
enum STTProvider {
  system('system', 'System STT'),
  whisper('whisper', 'Whisper'),
  azure('azure', 'Azure Speech'),
  ;

  final String id;
  final String displayName;

  const STTProvider(this.id, this.displayName);

  static STTProvider? fromId(String id) {
    try {
      return STTProvider.values.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// STT Settings
class STTSettings {
  final bool enabled;
  final STTProvider provider;
  final String language;
  final bool continuousListening;
  final bool autoSend;
  final bool showPartialResults;
  final String? apiKey;
  final String? apiEndpoint;

  const STTSettings({
    this.enabled = false,
    this.provider = STTProvider.system,
    this.language = 'en-US',
    this.continuousListening = false,
    this.autoSend = false,
    this.showPartialResults = true,
    this.apiKey,
    this.apiEndpoint,
  });

  STTSettings copyWith({
    bool? enabled,
    STTProvider? provider,
    String? language,
    bool? continuousListening,
    bool? autoSend,
    bool? showPartialResults,
    String? apiKey,
    String? apiEndpoint,
  }) {
    return STTSettings(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      language: language ?? this.language,
      continuousListening: continuousListening ?? this.continuousListening,
      autoSend: autoSend ?? this.autoSend,
      showPartialResults: showPartialResults ?? this.showPartialResults,
      apiKey: apiKey ?? this.apiKey,
      apiEndpoint: apiEndpoint ?? this.apiEndpoint,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'provider': provider.id,
        'language': language,
        'continuousListening': continuousListening,
        'autoSend': autoSend,
        'showPartialResults': showPartialResults,
        'apiKey': apiKey,
        'apiEndpoint': apiEndpoint,
      };

  factory STTSettings.fromJson(Map<String, dynamic> json) => STTSettings(
        enabled: json['enabled'] as bool? ?? false,
        provider: STTProvider.fromId(json['provider'] as String? ?? 'system') ?? STTProvider.system,
        language: json['language'] as String? ?? 'en-US',
        continuousListening: json['continuousListening'] as bool? ?? false,
        autoSend: json['autoSend'] as bool? ?? false,
        showPartialResults: json['showPartialResults'] as bool? ?? true,
        apiKey: json['apiKey'] as String?,
        apiEndpoint: json['apiEndpoint'] as String?,
      );
}

/// Supported languages for STT
class STTLanguage {
  final String code;
  final String name;
  final String nativeName;

  const STTLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  static const List<STTLanguage> supportedLanguages = [
    STTLanguage(code: 'en-US', name: 'English (US)', nativeName: 'English'),
    STTLanguage(code: 'en-GB', name: 'English (UK)', nativeName: 'English'),
    STTLanguage(code: 'es-ES', name: 'Spanish (Spain)', nativeName: 'Español'),
    STTLanguage(code: 'es-MX', name: 'Spanish (Mexico)', nativeName: 'Español'),
    STTLanguage(code: 'fr-FR', name: 'French', nativeName: 'Français'),
    STTLanguage(code: 'de-DE', name: 'German', nativeName: 'Deutsch'),
    STTLanguage(code: 'it-IT', name: 'Italian', nativeName: 'Italiano'),
    STTLanguage(code: 'pt-BR', name: 'Portuguese (Brazil)', nativeName: 'Português'),
    STTLanguage(code: 'pt-PT', name: 'Portuguese (Portugal)', nativeName: 'Português'),
    STTLanguage(code: 'ru-RU', name: 'Russian', nativeName: 'Русский'),
    STTLanguage(code: 'ja-JP', name: 'Japanese', nativeName: '日本語'),
    STTLanguage(code: 'ko-KR', name: 'Korean', nativeName: '한국어'),
    STTLanguage(code: 'zh-CN', name: 'Chinese (Simplified)', nativeName: '简体中文'),
    STTLanguage(code: 'zh-TW', name: 'Chinese (Traditional)', nativeName: '繁體中文'),
    STTLanguage(code: 'ar-SA', name: 'Arabic', nativeName: 'العربية'),
    STTLanguage(code: 'hi-IN', name: 'Hindi', nativeName: 'हिन्दी'),
  ];

  static STTLanguage? fromCode(String code) {
    try {
      return supportedLanguages.firstWhere((l) => l.code == code);
    } catch (_) {
      return null;
    }
  }
}

/// STT recognition result
class STTResult {
  final String text;
  final bool isFinal;
  final double confidence;

  const STTResult({
    required this.text,
    this.isFinal = false,
    this.confidence = 1.0,
  });
}

/// STT Service for speech-to-text functionality
class STTService {
  bool _isInitialized = false;
  bool _isListening = false;
  STTSettings _settings = const STTSettings();

  final SpeechToText _speech = SpeechToText();

  /// Callbacks
  void Function(STTResult)? onResult;
  VoidCallback? onListeningStarted;
  VoidCallback? onListeningStopped;
  void Function(String)? onError;

  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  STTSettings get settings => _settings;

  /// Initialize the STT service (requests microphone/speech permission)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _isInitialized = await _speech.initialize(
        onError: _handleError,
        onStatus: _handleStatus,
      );
      if (!_isInitialized) {
        onError?.call(
            'Speech recognition is not available (permission denied or unsupported device)');
      }
    } catch (e) {
      onError?.call('Failed to initialize STT: $e');
    }
  }

  void _handleError(SpeechRecognitionError error) {
    if (_isListening) {
      _isListening = false;
      onListeningStopped?.call();
    }
    // 'error_no_match' just means nothing was recognized; not worth surfacing
    if (error.errorMsg != 'error_no_match') {
      onError?.call('STT error: ${error.errorMsg}');
    }
  }

  void _handleStatus(String status) {
    final listening = status == 'listening';
    if (!listening && _isListening && status == 'done') {
      _isListening = false;
      onListeningStopped?.call();
    }
  }

  void _handleResult(SpeechRecognitionResult result) {
    if (!result.finalResult && !_settings.showPartialResults) return;
    onResult?.call(STTResult(
      text: result.recognizedWords,
      isFinal: result.finalResult,
      confidence: result.hasConfidenceRating ? result.confidence : 1.0,
    ));
  }

  /// Update settings
  void updateSettings(STTSettings settings) {
    _settings = settings;
  }

  /// Check if STT is available
  Future<bool> isAvailable() async {
    await initialize();
    return _isInitialized;
  }

  /// Start listening
  Future<void> startListening() async {
    if (!_settings.enabled) return;
    if (_isListening) return;
    if (_settings.provider != STTProvider.system) {
      onError?.call(
          '${_settings.provider.displayName} STT is not supported yet');
      return;
    }
    await initialize();
    if (!_isInitialized) return;

    try {
      _isListening = true;
      onListeningStarted?.call();

      await _speech.listen(
        onResult: _handleResult,
        localeId: _settings.language,
        listenOptions: SpeechListenOptions(
          partialResults: _settings.showPartialResults,
          listenMode: _settings.continuousListening
              ? ListenMode.dictation
              : ListenMode.confirmation,
        ),
        pauseFor: _settings.continuousListening
            ? const Duration(seconds: 10)
            : const Duration(seconds: 3),
      );
    } catch (e) {
      _isListening = false;
      onListeningStopped?.call();
      onError?.call('STT error: $e');
    }
  }

  /// Stop listening
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _speech.stop();
      _isListening = false;
      onListeningStopped?.call();
    } catch (e) {
      onError?.call('STT stop error: $e');
    }
  }

  /// Toggle listening
  Future<void> toggleListening() async {
    if (_isListening) {
      await stopListening();
    } else {
      await startListening();
    }
  }

  /// Cancel listening (discard results)
  Future<void> cancelListening() async {
    if (!_isListening) return;

    try {
      await _speech.cancel();
      _isListening = false;
      onListeningStopped?.call();
    } catch (e) {
      onError?.call('STT cancel error: $e');
    }
  }

  /// Dispose the service
  void dispose() {
    stopListening();
    _isInitialized = false;
  }
}