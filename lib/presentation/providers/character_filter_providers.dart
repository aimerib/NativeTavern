import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/character.dart';
import '../../data/repositories/character_repository.dart';
import './character_providers.dart';
import './tag_providers.dart';

/// Sort options for characters
enum CharacterSortOption {
  nameAsc,
  nameDesc,
  createdAtDesc,
  createdAtAsc,
  modifiedAtDesc,
  modifiedAtAsc,
  random,
}

/// Filter state for character list
class CharacterFilterState {
  final String searchQuery;
  final Set<String> selectedTagIds; // Tag IDs from the Tags table
  final List<String> selectedLegacyTags; // Legacy string tags from character.tags
  final bool showFavoritesOnly;
  final CharacterSortOption sortOption;

  /// Seed for the random sort order; regenerated each time the user
  /// selects Random so re-selecting it reshuffles, while filter changes
  /// keep the current order stable.
  final int randomSeed;

  const CharacterFilterState({
    this.searchQuery = '',
    this.selectedTagIds = const {},
    this.selectedLegacyTags = const [],
    this.showFavoritesOnly = false,
    this.sortOption = CharacterSortOption.modifiedAtDesc,
    this.randomSeed = 0,
  });

  CharacterFilterState copyWith({
    String? searchQuery,
    Set<String>? selectedTagIds,
    List<String>? selectedLegacyTags,
    bool? showFavoritesOnly,
    CharacterSortOption? sortOption,
    int? randomSeed,
  }) {
    return CharacterFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTagIds: selectedTagIds ?? this.selectedTagIds,
      selectedLegacyTags: selectedLegacyTags ?? this.selectedLegacyTags,
      showFavoritesOnly: showFavoritesOnly ?? this.showFavoritesOnly,
      sortOption: sortOption ?? this.sortOption,
      randomSeed: randomSeed ?? this.randomSeed,
    );
  }

  /// Check if any filters are active
  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      selectedTagIds.isNotEmpty ||
      selectedLegacyTags.isNotEmpty ||
      showFavoritesOnly;

  /// For backward compatibility - get all selected tags (both new and legacy)
  List<String> get selectedTags => selectedLegacyTags;
}

/// Notifier for character filter state
class CharacterFilterNotifier extends StateNotifier<CharacterFilterState> {
  CharacterFilterNotifier() : super(const CharacterFilterState());

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Toggle a tag ID (from Tags table)
  void toggleTagId(String tagId) {
    final tagIds = Set<String>.from(state.selectedTagIds);
    if (tagIds.contains(tagId)) {
      tagIds.remove(tagId);
    } else {
      tagIds.add(tagId);
    }
    state = state.copyWith(selectedTagIds: tagIds);
  }

  /// Toggle a legacy tag (string from character.tags)
  void toggleTag(String tag) {
    final tags = List<String>.from(state.selectedLegacyTags);
    if (tags.contains(tag)) {
      tags.remove(tag);
    } else {
      tags.add(tag);
    }
    state = state.copyWith(selectedLegacyTags: tags);
  }

  void clearTags() {
    state = state.copyWith(selectedTagIds: {}, selectedLegacyTags: []);
  }

  void setTags(List<String> tags) {
    state = state.copyWith(selectedLegacyTags: tags);
  }

  void setTagIds(Set<String> tagIds) {
    state = state.copyWith(selectedTagIds: tagIds);
  }

  void toggleFavoritesOnly() {
    state = state.copyWith(showFavoritesOnly: !state.showFavoritesOnly);
  }

  void setSortOption(CharacterSortOption option) {
    state = state.copyWith(
      sortOption: option,
      randomSeed: option == CharacterSortOption.random
          ? Random().nextInt(1 << 31)
          : state.randomSeed,
    );
  }

  void clearFilters() {
    state = const CharacterFilterState();
  }
}

/// Provider for character filter state
final characterFilterProvider =
    StateNotifierProvider<CharacterFilterNotifier, CharacterFilterState>((ref) {
  return CharacterFilterNotifier();
});

/// Provider for all unique legacy tags across all characters (from character.tags field)
final allLegacyTagsProvider = FutureProvider<List<String>>((ref) async {
  final repo = ref.watch(characterRepositoryProvider);
  final characters = await repo.getAllCharacters();
  
  final tagSet = <String>{};
  for (final character in characters) {
    tagSet.addAll(character.tags);
  }
  
  final tags = tagSet.toList()..sort();
  return tags;
});

/// Combined provider for all tags (both new Tag model and legacy string tags)
final allCombinedTagsProvider = FutureProvider<List<dynamic>>((ref) async {
  final newTags = await ref.watch(allTagsProvider.future);
  final legacyTags = await ref.watch(allLegacyTagsProvider.future);
  
  // Return new tags first, then legacy tags that aren't covered by new tags
  final newTagNames = newTags.map((t) => t.name.toLowerCase()).toSet();
  final uniqueLegacyTags = legacyTags.where(
    (t) => !newTagNames.contains(t.toLowerCase())
  ).toList();
  
  return [...newTags, ...uniqueLegacyTags];
});

/// Provider for filtered and sorted characters
final filteredCharactersProvider = FutureProvider<List<Character>>((ref) async {
  final filterState = ref.watch(characterFilterProvider);
  final tagRepo = ref.watch(tagRepositoryProvider);

  // Derive from characterListProvider so refreshes and add/delete propagate.
  var characters =
      List<Character>.from(await ref.watch(characterListProvider.future));
  
  // Apply search filter
  if (filterState.searchQuery.isNotEmpty) {
    final query = filterState.searchQuery.toLowerCase();
    characters = characters.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query) ||
          c.tags.any((t) => t.toLowerCase().contains(query)) ||
          c.creator.toLowerCase().contains(query);
    }).toList();
  }
  
  // Apply tag filters. Managed tags and legacy card tags are unified by
  // name (case-insensitive): a tag matches a character when it is assigned
  // via the Tags table OR the character's card carries a tag with the same
  // name. A character must match every selected tag.
  if (filterState.selectedTagIds.isNotEmpty ||
      filterState.selectedLegacyTags.isNotEmpty) {
    final allTags = await ref.watch(allTagsProvider.future);
    final tagsById = {for (final t in allTags) t.id: t};
    final tagsByName = {for (final t in allTags) t.name.toLowerCase(): t};

    final requiredNames = <String>[];
    final requiredJunctions = <Set<String>>[];

    Future<void> addRequirement(String nameLower, String? tagId) async {
      requiredNames.add(nameLower);
      requiredJunctions.add(tagId != null
          ? (await tagRepo.getCharacterIdsForTag(tagId)).toSet()
          : const <String>{});
    }

    for (final tagId in filterState.selectedTagIds) {
      await addRequirement(tagsById[tagId]?.name.toLowerCase() ?? '', tagId);
    }
    for (final tag in filterState.selectedLegacyTags) {
      await addRequirement(tag.toLowerCase(), tagsByName[tag.toLowerCase()]?.id);
    }

    characters = characters.where((c) {
      final cardTags = c.tags.map((t) => t.toLowerCase()).toSet();
      for (var i = 0; i < requiredNames.length; i++) {
        final matches = requiredJunctions[i].contains(c.id) ||
            (requiredNames[i].isNotEmpty &&
                cardTags.contains(requiredNames[i]));
        if (!matches) return false;
      }
      return true;
    }).toList();
  }
  
  // Apply favorites filter
  if (filterState.showFavoritesOnly) {
    characters = characters.where((c) => c.isFavorite).toList();
  }
  
  // Apply sorting
  switch (filterState.sortOption) {
    case CharacterSortOption.nameAsc:
      characters.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      break;
    case CharacterSortOption.nameDesc:
      characters.sort((a, b) => b.name.toLowerCase().compareTo(a.name.toLowerCase()));
      break;
    case CharacterSortOption.createdAtDesc:
      characters.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      break;
    case CharacterSortOption.createdAtAsc:
      characters.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      break;
    case CharacterSortOption.modifiedAtDesc:
      characters.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
      break;
    case CharacterSortOption.modifiedAtAsc:
      characters.sort((a, b) => a.modifiedAt.compareTo(b.modifiedAt));
      break;
    case CharacterSortOption.random:
      characters.shuffle(Random(filterState.randomSeed));
      break;
  }
  
  return characters;
});

/// Provider for favorite characters only
final favoriteCharactersProvider = FutureProvider<List<Character>>((ref) async {
  final repo = ref.watch(characterRepositoryProvider);
  final characters = await repo.getAllCharacters();
  return characters.where((c) => c.isFavorite).toList();
});

/// Provider for character count by legacy tag
final tagCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final repo = ref.watch(characterRepositoryProvider);
  final characters = await repo.getAllCharacters();
  
  final counts = <String, int>{};
  for (final character in characters) {
    for (final tag in character.tags) {
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  
  return counts;
});

/// Helper extension for sort option display
extension CharacterSortOptionExtension on CharacterSortOption {
  String get displayName {
    switch (this) {
      case CharacterSortOption.nameAsc:
        return 'Name (A-Z)';
      case CharacterSortOption.nameDesc:
        return 'Name (Z-A)';
      case CharacterSortOption.createdAtDesc:
        return 'Newest First';
      case CharacterSortOption.createdAtAsc:
        return 'Oldest First';
      case CharacterSortOption.modifiedAtDesc:
        return 'Recently Modified';
      case CharacterSortOption.modifiedAtAsc:
        return 'Least Recently Modified';
      case CharacterSortOption.random:
        return 'Random';
    }
  }

  String get icon {
    switch (this) {
      case CharacterSortOption.nameAsc:
        return '↑';
      case CharacterSortOption.nameDesc:
        return '↓';
      case CharacterSortOption.createdAtDesc:
      case CharacterSortOption.modifiedAtDesc:
        return '↓';
      case CharacterSortOption.createdAtAsc:
      case CharacterSortOption.modifiedAtAsc:
        return '↑';
      case CharacterSortOption.random:
        return '⇄';
    }
  }
}