import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:grocerylist_v2/ingredient.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class RecipeTag {
  final String name;
  final String emoji;
  final bool isCustom;

  const RecipeTag({
    required this.name,
    required this.emoji,
    required this.isCustom,
  });

  String get display => '${emoji.isEmpty ? '🏷️' : emoji} ${name.trim()}';

  Map<String, dynamic> toJson() => {
    'name': name,
    'emoji': emoji,
    'isCustom': isCustom,
  };

  static RecipeTag fromJson(Map<String, dynamic> json) => RecipeTag(
    name: (json['name'] as String? ?? '').trim(),
    emoji: (json['emoji'] as String? ?? '').trim(),
    isCustom: json['isCustom'] as bool? ?? false,
  );

  String get key => '${isCustom ? 'c' : 'b'}|${name.trim().toLowerCase()}';

  @override
  bool operator ==(Object other) =>
      other is RecipeTag &&
          other.name.trim().toLowerCase() == name.trim().toLowerCase() &&
          other.isCustom == isCustom;

  @override
  int get hashCode => Object.hash(name.trim().toLowerCase(), isCustom);
}

class RecipeStore {
  Set<Recipe> recipes = {};

  final Set<RecipeTag> builtInTags = {
    const RecipeTag(name: 'Breakfast', emoji: '🍳', isCustom: false),
    const RecipeTag(name: 'Lunch', emoji: '🥪', isCustom: false),
    const RecipeTag(name: 'Dinner', emoji: '🍽️', isCustom: false),
    const RecipeTag(name: 'Snack', emoji: '🍿', isCustom: false),
    const RecipeTag(name: 'Dessert', emoji: '🍰', isCustom: false),
    const RecipeTag(name: 'Healthy', emoji: '🥗', isCustom: false),
    const RecipeTag(name: 'High Protein', emoji: '💪', isCustom: false),
    const RecipeTag(name: 'Vegetarian', emoji: '🥬', isCustom: false),
    const RecipeTag(name: 'Vegan', emoji: '🌱', isCustom: false),
    const RecipeTag(name: 'Gluten-Free', emoji: '🚫🌾', isCustom: false),
    const RecipeTag(name: 'Spicy', emoji: '🌶️', isCustom: false),
    const RecipeTag(name: 'Comfort Food', emoji: '🍲', isCustom: false),
  };

  final Set<RecipeTag> customTags = {};


  static const String _dataFolderName = 'Data';
  static const String _fileName = 'recipe_store.json';

  Timer? _saveDebounce;
  bool _loaded = false;

  late final Future<void> ready;

  RecipeStore({Set<Recipe>? recipes, Set<RecipeTag>? customTags}) {
    if (recipes != null) this.recipes = recipes;
    if (customTags != null) {
      this.customTags
        ..clear()
        ..addAll(customTags);
    }

    ready = _loadFromDisk();
  }

  Future<Directory> _dataDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _dataFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _dataFile() async {
    final dir = await _dataDir();
    return File(p.join(dir.path, _fileName));
  }

  Future<void> _loadFromDisk() async {
    try {
      final f = await _dataFile();
      if (!await f.exists()) {
        _loaded = true;
        return;
      }

      final raw = await f.readAsString();
      if (raw.trim().isEmpty) {
        _loaded = true;
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _loaded = true;
        return;
      }

      final list = (decoded['recipes'] as List? ?? [])
          .map((e) => Recipe.fromJson(Map<String, dynamic>.from(e as Map)))
          .toSet();

      final rawTags = (decoded['customTags'] as List? ?? []);
      final tags = <RecipeTag>{};
      for (final e in rawTags) {
        if (e is Map<String, dynamic>) {
          tags.add(RecipeTag.fromJson(e));
        } else if (e is Map) {
          tags.add(RecipeTag.fromJson(e.cast<String, dynamic>()));
        }
      }

      recipes = list;
      customTags
        ..clear()
        ..addAll(tags);

      _loaded = true;
    } catch (_) {
      _loaded = true;
    }
  }

  void _markDirty() {
    if (!_loaded) return;

    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 200), () {
      _saveToDisk();
    });
  }

  Future<void> _saveToDisk() async {
    try {
      final f = await _dataFile();
      final payload = const JsonEncoder.withIndent('  ').convert(toJson());
      await f.writeAsString(payload, flush: true);
    } catch (_) {
    }
  }


  Map<String, dynamic> toJson() => {
    'recipes': recipes.map((r) => r.toJson()).toList(),
    'customTags': customTags.map((t) => t.toJson()).toList(),
  };

  static RecipeStore fromJson(Map<String, dynamic> json) {
    final list = (json['recipes'] as List? ?? [])
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toSet();

    final rawTags = (json['customTags'] as List? ?? []);
    final tags = <RecipeTag>{};
    for (final e in rawTags) {
      if (e is Map<String, dynamic>) {
        tags.add(RecipeTag.fromJson(e));
      } else if (e is Map) {
        tags.add(RecipeTag.fromJson(e.cast<String, dynamic>()));
      }
    }

    final store = RecipeStore(recipes: list, customTags: tags);

    store._loaded = true;

    return store;
  }


  List<Recipe> sortedByTitle() {
    final list = recipes.toList();
    list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return list;
  }

  List<RecipeTag> builtInTagsSorted() {
    final list = builtInTags.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<RecipeTag> customTagsSorted() {
    final list = customTags.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<RecipeTag> allTagsSorted() {
    final all = <RecipeTag>{...builtInTags, ...customTags};
    final list = all.toList();
    list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }


  void upsertRecipe(Recipe recipe) {
    recipes.removeWhere(
          (r) => r.title.trim().toLowerCase() == recipe.title.trim().toLowerCase(),
    );
    recipes.add(recipe);
    _markDirty();
  }

  void deleteRecipeByTitle(String title) {
    final t = title.trim().toLowerCase();
    recipes.removeWhere((r) => r.title.trim().toLowerCase() == t);
    _markDirty();
  }

  void upsertCustomTag(RecipeTag tag) {
    final fixed = RecipeTag(
      name: tag.name.trim(),
      emoji: tag.emoji.trim(),
      isCustom: true,
    );
    if (fixed.name.isEmpty) return;

    customTags.removeWhere((t) => t.key == fixed.key);
    customTags.add(fixed);
    _markDirty();
  }

  void deleteCustomTag(RecipeTag tag) {
    customTags.removeWhere((t) => t.key == tag.key);

    for (final r in recipes) {
      r.tags.removeWhere((t) => t.key == tag.key);
    }

    _markDirty();
  }

  Future<void> resetToDefault({bool deleteFile = false}) async {
    await ready;

    recipes.clear();
    customTags.clear();

    if (deleteFile) {
      try {
        final f = await _dataFile();
        if (await f.exists()) {
          await f.delete();
        }
      } catch (_) {
      }
    } else {
      await _saveToDisk();
    }
  }

  RecipeTag? findTag({
    required String name,
    required bool isCustom,
    String? emojiHint,
  }) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;

    final pool = isCustom ? customTags : builtInTags;
    for (final t in pool) {
      if (t.name.trim().toLowerCase() == n) return t;
    }

    return RecipeTag(
      name: name.trim(),
      emoji: (emojiHint ?? '').trim(),
      isCustom: isCustom,
    );
  }
}

class Recipe {
  String title;
  String description;

  final List<RecipeTag> tags;

  List<IngredientSection> ingredientSections;
  List<RecipeStep> stepTitles;

  bool isFavorite;

  int score10;

  Recipe({
    required this.title,
    required this.description,
    required this.ingredientSections,
    required this.stepTitles,
    List<RecipeTag>? tags,
    this.isFavorite = false,
    this.score10 = 0,
  }) : tags = tags ?? [];

  bool get hasTags => tags.isNotEmpty;

  void addTag(RecipeTag tag) {
    final k = tag.key;
    if (tags.any((t) => t.key == k)) return;
    tags.add(tag);
  }

  void removeTag(RecipeTag tag) {
    tags.removeWhere((t) => t.key == tag.key);
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'description': description,

    'tagsV2': tags.map((t) => t.toJson()).toList(),

    'ingredientSections': ingredientSections.map((s) => s.toJson()).toList(),
    'stepTitles': stepTitles.map((s) => s.toJson()).toList(),
    'isFavorite': isFavorite,
    'score10': score10,
  };

  static Recipe fromJson(Map<String, dynamic> json) {
    final tagsV2raw = json['tagsV2'];
    final parsedTags = <RecipeTag>[];

    if (tagsV2raw is List) {
      for (final e in tagsV2raw) {
        if (e is Map<String, dynamic>) {
          final t = RecipeTag.fromJson(e);
          if (t.name.isNotEmpty) parsedTags.add(t);
        } else if (e is Map) {
          final t = RecipeTag.fromJson(e.cast<String, dynamic>());
          if (t.name.isNotEmpty) parsedTags.add(t);
        }
      }
    } else {
      final old = (json['tags'] as List? ?? [])
          .map((e) => (e as String).trim())
          .where((e) => e.isNotEmpty)
          .toList();

      for (final name in old) {
        parsedTags.add(RecipeTag(name: name, emoji: '🏷️', isCustom: false));
      }
    }

    final seen = <String>{};
    final uniqueTags = <RecipeTag>[];
    for (final t in parsedTags) {
      if (t.name.trim().isEmpty) continue;
      if (seen.add(t.key)) uniqueTags.add(t);
    }

    return Recipe(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      tags: uniqueTags,
      ingredientSections: (json['ingredientSections'] as List? ?? [])
          .map((e) => IngredientSection.fromJson(e as Map<String, dynamic>))
          .toList(),
      stepTitles: (json['stepTitles'] as List? ?? [])
          .map((e) => RecipeStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      isFavorite: json['isFavorite'] as bool? ?? false,
      score10: ((json['score10'] as num?)?.toInt() ?? 0).clamp(0, 10),
    );
  }
}

class IngredientSection {
  String sectionTitle;

  List<RecipeIngredient> ingredients;

  IngredientSection({
    required this.sectionTitle,
    required this.ingredients,
  });

  Map<String, dynamic> toJson() => {
    'sectionTitle': sectionTitle,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
  };

  static IngredientSection fromJson(Map<String, dynamic> json) {
    final raw = (json['ingredients'] as List? ?? []);
    final parsed = <RecipeIngredient>[];

    for (final e in raw) {
      if (e is Map<String, dynamic>) {
        parsed.add(RecipeIngredient.fromJson(e));
      } else if (e is Map) {
        parsed.add(RecipeIngredient.fromJson(e.cast<String, dynamic>()));
      }
    }

    return IngredientSection(
      sectionTitle: json['sectionTitle'] as String? ?? '',
      ingredients: parsed,
    );
  }
}

class RecipeIngredient {
  String name;
  String quantity;
  String unit;

  RecipeIngredient({
    required this.name,
    this.quantity = '',
    this.unit = '',
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'quantity': quantity,
    'unit': unit,
  };

  static RecipeIngredient fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String? ?? '').trim();
    final unit = (json['unit'] as String? ?? '').trim();
    final quantity = (json['quantity'] as String? ?? '').trim();

    return RecipeIngredient(
      name: name,
      quantity: quantity,
      unit: unit,
    );
  }
}

class RecipeStep {
  String stepTitle;
  String description;

  RecipeStep({
    required this.stepTitle,
    required this.description,
  });

  Map<String, dynamic> toJson() => {
    'stepTitle': stepTitle,
    'description': description,
  };

  static RecipeStep fromJson(Map<String, dynamic> json) => RecipeStep(
    stepTitle: json['stepTitle'] as String? ?? '',
    description: json['description'] as String? ?? '',
  );
}
