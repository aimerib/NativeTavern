import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:native_tavern/data/models/vector_storage.dart';
import 'package:native_tavern/domain/services/embedding_service.dart';
import 'package:native_tavern/domain/services/vector_storage_service.dart';

/// Provider for VectorStorageService
final vectorStorageServiceProvider = Provider<VectorStorageService>((ref) {
  return VectorStorageService();
});

/// Provider for the embeddings API client
final embeddingServiceProvider = Provider<EmbeddingService>((ref) {
  return EmbeddingService();
});

/// Provider for vector storage settings
final vectorStorageSettingsProvider =
    StateNotifierProvider<VectorStorageSettingsNotifier, VectorStorageSettings>((ref) {
  return VectorStorageSettingsNotifier();
});

/// Notifier for managing vector storage settings
class VectorStorageSettingsNotifier extends StateNotifier<VectorStorageSettings> {
  static const _storageKey = 'vector_storage_settings';

  VectorStorageSettingsNotifier() : super(const VectorStorageSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json != null) {
        state = VectorStorageSettings.deserialize(json);
      }
    } catch (e) {
      // Keep default settings on error
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, VectorStorageSettings.serialize(state));
    } catch (e) {
      // Ignore save errors
    }
  }

  /// Toggle enabled state
  void setEnabled(bool enabled) {
    state = state.copyWith(enabled: enabled);
    _saveSettings();
  }

  /// Set active collection
  void setActiveCollection(String? collectionId) {
    if (collectionId == null) {
      state = state.copyWith(clearActiveCollection: true);
    } else {
      state = state.copyWith(activeCollectionId: collectionId);
    }
    _saveSettings();
  }

  /// Set top K results
  void setTopK(int topK) {
    state = state.copyWith(topK: topK.clamp(1, 20));
    _saveSettings();
  }

  /// Set similarity threshold
  void setSimilarityThreshold(double threshold) {
    state = state.copyWith(similarityThreshold: threshold.clamp(0.0, 1.0));
    _saveSettings();
  }

  /// Toggle include in prompt
  void setIncludeInPrompt(bool include) {
    state = state.copyWith(includeInPrompt: include);
    _saveSettings();
  }

  /// Set prompt template
  void setPromptTemplate(String template) {
    state = state.copyWith(promptTemplate: template);
    _saveSettings();
  }

  /// Set embedding provider
  void setEmbeddingProvider(EmbeddingProvider provider) {
    state = state.copyWith(
      embeddingProvider: provider,
      embeddingModel: provider.defaultModel,
    );
    _saveSettings();
  }

  /// Set embedding model
  void setEmbeddingModel(String model) {
    state = state.copyWith(embeddingModel: model);
    _saveSettings();
  }

  /// Set embedding API key
  void setEmbeddingApiKey(String? apiKey) {
    state = state.copyWith(embeddingApiKey: apiKey);
    _saveSettings();
  }

  /// Set embedding endpoint override
  void setEmbeddingEndpoint(String? endpoint) {
    state = state.copyWith(embeddingEndpoint: endpoint);
    _saveSettings();
  }

  /// Reset to defaults
  void resetToDefaults() {
    state = const VectorStorageSettings();
    _saveSettings();
  }
}

/// Provider for collections list
final vectorCollectionsProvider =
    StateNotifierProvider<VectorCollectionsNotifier, List<VectorCollection>>((ref) {
  final service = ref.watch(vectorStorageServiceProvider);
  return VectorCollectionsNotifier(service, ref);
});

/// Notifier for managing collections. Collections (including embeddings)
/// are persisted to SharedPreferences so the data bank survives restarts.
class VectorCollectionsNotifier extends StateNotifier<List<VectorCollection>> {
  static const _storageKey = 'vector_collections';

  final VectorStorageService _service;
  final Ref _ref;

  VectorCollectionsNotifier(this._service, this._ref) : super([]) {
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_storageKey);
      if (json != null) {
        final list = (jsonDecode(json) as List<dynamic>)
            .map((c) => VectorCollection.fromJson(c as Map<String, dynamic>))
            .toList();
        _service.loadCollections(list);
      }
    } catch (_) {
      // Start with whatever is in memory on error
    }
    if (mounted) state = _service.collections;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json =
          jsonEncode(_service.collections.map((c) => c.toJson()).toList());
      await prefs.setString(_storageKey, json);
    } catch (_) {
      // Ignore persistence errors; collections stay usable in memory
    }
  }

  /// Create a new collection
  VectorCollection createCollection({
    required String name,
    String? description,
    int dimensions = 1536,
  }) {
    final collection = _service.createCollection(
      name: name,
      description: description,
      dimensions: dimensions,
    );
    state = _service.collections;
    _persist();
    return collection;
  }

  /// Update a collection
  void updateCollection(VectorCollection collection) {
    _service.updateCollection(collection);
    state = _service.collections;
    _persist();
  }

  /// Delete a collection
  void deleteCollection(String id) {
    _service.deleteCollection(id);
    state = _service.collections;
    _persist();
  }

  /// Add document to collection
  VectorDocument addDocument({
    required String collectionId,
    required String content,
    List<double>? embedding,
    Map<String, dynamic>? metadata,
  }) {
    final doc = _service.addDocument(
      collectionId: collectionId,
      content: content,
      embedding: embedding,
      metadata: metadata,
    );
    state = _service.collections;
    _persist();
    return doc;
  }

  /// Chunk [content], embed each chunk, and add the chunks as documents.
  /// Returns the number of documents added. Throws if embedding fails.
  Future<int> addDocumentWithEmbedding({
    required String collectionId,
    required String content,
    Map<String, dynamic>? metadata,
  }) async {
    final chunks =
        _service.chunkText(content, const ChunkingOptions());
    if (chunks.isEmpty) return 0;

    final settings = _ref.read(vectorStorageSettingsProvider);
    final embeddings =
        await _ref.read(embeddingServiceProvider).embed(chunks, settings);

    _service.addDocuments(
      collectionId: collectionId,
      contents: chunks,
      embeddings: embeddings,
      metadataList: metadata != null
          ? List.generate(chunks.length, (_) => metadata)
          : null,
    );
    state = _service.collections;
    await _persist();
    return chunks.length;
  }

  /// Remove document from collection
  void removeDocument(String collectionId, String documentId) {
    _service.removeDocument(collectionId, documentId);
    state = _service.collections;
    _persist();
  }

  /// Import collection from JSON
  VectorCollection importCollection(String json) {
    final collection = _service.importCollection(json);
    state = _service.collections;
    _persist();
    return collection;
  }

  /// Export collection to JSON
  String exportCollection(String collectionId) {
    return _service.exportCollection(collectionId);
  }

  /// Refresh collections list
  void refresh() {
    state = _service.collections;
  }
}

/// Provider for active collection
final activeCollectionProvider = Provider<VectorCollection?>((ref) {
  final settings = ref.watch(vectorStorageSettingsProvider);
  final collections = ref.watch(vectorCollectionsProvider);
  
  if (settings.activeCollectionId == null) return null;
  
  try {
    return collections.firstWhere((c) => c.id == settings.activeCollectionId);
  } catch (_) {
    return null;
  }
});

/// Provider for collection statistics
final collectionStatisticsProvider = Provider.family<CollectionStatistics, String>((ref, collectionId) {
  final service = ref.watch(vectorStorageServiceProvider);
  return service.getStatistics(collectionId);
});

/// Provider for search results
final vectorSearchProvider = FutureProvider.family<List<VectorSearchResult>, VectorSearchRequest>((ref, request) async {
  final service = ref.watch(vectorStorageServiceProvider);
  final settings = ref.watch(vectorStorageSettingsProvider);
  
  if (request.queryEmbedding == null) {
    return [];
  }
  
  return service.search(
    collectionId: request.collectionId,
    queryEmbedding: request.queryEmbedding!,
    topK: request.topK ?? settings.topK,
    similarityThreshold: request.similarityThreshold ?? settings.similarityThreshold,
  );
});

/// Request for vector search
class VectorSearchRequest {
  final String collectionId;
  final List<double>? queryEmbedding;
  final int? topK;
  final double? similarityThreshold;

  const VectorSearchRequest({
    required this.collectionId,
    this.queryEmbedding,
    this.topK,
    this.similarityThreshold,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VectorSearchRequest &&
        other.collectionId == collectionId &&
        other.topK == topK &&
        other.similarityThreshold == similarityThreshold;
  }

  @override
  int get hashCode => Object.hash(collectionId, topK, similarityThreshold);
}

/// Provider for chunking text
final textChunkerProvider = Provider<TextChunker>((ref) {
  final service = ref.watch(vectorStorageServiceProvider);
  return TextChunker(service);
});

/// Helper class for text chunking
class TextChunker {
  final VectorStorageService _service;

  TextChunker(this._service);

  List<String> chunk(String text, ChunkingOptions options) {
    return _service.chunkText(text, options);
  }
}

/// Provider for checking if RAG is active
final isRAGActiveProvider = Provider<bool>((ref) {
  final settings = ref.watch(vectorStorageSettingsProvider);
  final activeCollection = ref.watch(activeCollectionProvider);
  return settings.enabled && activeCollection != null;
});