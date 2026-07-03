import 'package:dio/dio.dart';
import 'package:native_tavern/data/models/vector_storage.dart';

/// Client for generating text embeddings for the vector storage / RAG
/// feature. OpenAI, local (Ollama / llama.cpp) and custom providers all
/// speak the OpenAI-compatible `/embeddings` API; Cohere has its own.
class EmbeddingService {
  final Dio _dio;

  EmbeddingService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
            ));

  /// Generate embeddings for [texts] using the provider configured in
  /// [settings]. Returns one vector per input text, in order.
  Future<List<List<double>>> embed(
    List<String> texts,
    VectorStorageSettings settings,
  ) async {
    if (texts.isEmpty) return [];

    final model = settings.embeddingModel?.isNotEmpty == true
        ? settings.embeddingModel!
        : settings.embeddingProvider.defaultModel;

    switch (settings.embeddingProvider) {
      case EmbeddingProvider.openai:
      case EmbeddingProvider.local:
      case EmbeddingProvider.custom:
        return _embedOpenAICompatible(texts, settings, model);
      case EmbeddingProvider.cohere:
        return _embedCohere(texts, settings, model);
    }
  }

  String _baseEndpoint(VectorStorageSettings settings) {
    final custom = settings.embeddingEndpoint;
    if (custom != null && custom.isNotEmpty) {
      return custom.replaceAll(RegExp(r'/+$'), '');
    }
    switch (settings.embeddingProvider) {
      case EmbeddingProvider.openai:
        return 'https://api.openai.com/v1';
      case EmbeddingProvider.local:
        // Ollama's OpenAI-compatible endpoint
        return 'http://localhost:11434/v1';
      case EmbeddingProvider.cohere:
        return 'https://api.cohere.ai/v1';
      case EmbeddingProvider.custom:
        throw Exception('Custom embedding provider requires an endpoint');
    }
  }

  Future<List<List<double>>> _embedOpenAICompatible(
    List<String> texts,
    VectorStorageSettings settings,
    String model,
  ) async {
    final apiKey = settings.embeddingApiKey;
    if (settings.embeddingProvider == EmbeddingProvider.openai &&
        (apiKey == null || apiKey.isEmpty)) {
      throw Exception('OpenAI embeddings require an API key');
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '${_baseEndpoint(settings)}/embeddings',
      options: Options(headers: {
        if (apiKey != null && apiKey.isNotEmpty)
          'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': model,
        'input': texts,
      },
    );

    final data = response.data!['data'] as List<dynamic>;
    // The API may reorder results; sort by index to match the input order
    final items = data.cast<Map<String, dynamic>>().toList()
      ..sort((a, b) => (a['index'] as int).compareTo(b['index'] as int));
    return items
        .map((item) => (item['embedding'] as List<dynamic>)
            .map((e) => (e as num).toDouble())
            .toList())
        .toList();
  }

  Future<List<List<double>>> _embedCohere(
    List<String> texts,
    VectorStorageSettings settings,
    String model,
  ) async {
    final apiKey = settings.embeddingApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Cohere embeddings require an API key');
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '${_baseEndpoint(settings)}/embed',
      options: Options(headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': model,
        'texts': texts,
        'input_type': 'search_document',
      },
    );

    final embeddings = response.data!['embeddings'] as List<dynamic>;
    return embeddings
        .map((e) =>
            (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
        .toList();
  }
}
