import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class IngredientTag {
  final String name;
  final String emoji;
  final bool isCustom;

  const IngredientTag({
    required this.name,
    required this.emoji,
    required this.isCustom,
  });

  Map<String, dynamic> toJSON() => {
    'name': name,
    'emoji': emoji,
    'isCustom': isCustom,
  };

  static IngredientTag fromJSON(Map<String, dynamic> json) {
    return IngredientTag(
      name: json['name'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '',
      isCustom: json['isCustom'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is IngredientTag &&
        other.name.trim().toLowerCase() == name.trim().toLowerCase() &&
        other.emoji == emoji &&
        other.isCustom == isCustom;
  }

  @override
  int get hashCode => Object.hash(name.trim().toLowerCase(), emoji, isCustom);
}

class Ingredient {
  String name;
  String unit;

  String tagName;
  String tagEmoji;
  bool tagIsCustom;

  String storeTag;

  Ingredient({
    required this.name,
    required this.unit,
    required this.tagName,
    required this.tagEmoji,
    required this.tagIsCustom,
    required this.storeTag,
  });

  bool get hasTag => tagName.trim().isNotEmpty && tagEmoji.trim().isNotEmpty;
  bool get hasStore => storeTag.trim().isNotEmpty;

  IngredientTag? get tagOrNull {
    if (!hasTag) return null;
    return IngredientTag(name: tagName, emoji: tagEmoji, isCustom: tagIsCustom);
  }

  Map<String, dynamic> toJSON() {
    return {
      'name': name,
      'unit': unit,
      'tagName': tagName,
      'tagEmoji': tagEmoji,
      'tagIsCustom': tagIsCustom,
      'storeTag': storeTag,
    };
  }

  static Ingredient fromJSON(Map<String, dynamic> json) {
    return Ingredient(
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      tagName: json['tagName'] as String? ?? (json['tag'] as String? ?? ''), // legacy fallback
      tagEmoji: json['tagEmoji'] as String? ?? '',
      tagIsCustom: json['tagIsCustom'] as bool? ?? false,
      storeTag: json['storeTag'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) {
    return other is Ingredient && other.name.trim().toLowerCase() == name.trim().toLowerCase();
  }

  @override
  int get hashCode => name.trim().toLowerCase().hashCode;
}

class IngredientStore {
  Set<Ingredient> ingredients = {};
  Set<IngredientTag> customTags = {};
  Set<String> customStores = {};


  static const String _dataFolderName = 'Data';
  static const String _fileName = 'ingredient_store.json';

  Timer? _saveDebounce;
  bool _loaded = false;

  late final Future<void> ready;

  IngredientStore({
    Set<Ingredient>? ingredients,
    Set<IngredientTag>? customTags,
    Set<String>? customStores,
  }) {
    if (ingredients != null) this.ingredients = ingredients;
    if (customTags != null) this.customTags = customTags;
    if (customStores != null) this.customStores = customStores;

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

      final ingList = (decoded['ingredients'] as List? ?? [])
          .map((e) => Ingredient.fromJSON(Map<String, dynamic>.from(e as Map)))
          .toSet();

      final tagList = (decoded['customTags'] as List? ?? [])
          .map((e) => IngredientTag.fromJSON(Map<String, dynamic>.from(e as Map)))
          .toSet();

      final storeList = (decoded['customStores'] as List? ?? []).map((e) => e.toString()).toSet();

      ingredients = ingList;
      customTags = tagList;
      customStores = storeList;

      _sanitizeAfterLoad();

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
      final payload = const JsonEncoder.withIndent('  ').convert(toJSON());
      await f.writeAsString(payload, flush: true);
    } catch (_) {
    }
  }

  static const List<IngredientTag> builtInTags = [
    IngredientTag(name: 'Produce', emoji: '🥬', isCustom: false),
    IngredientTag(name: 'Meat', emoji: '🥩', isCustom: false),
    IngredientTag(name: 'Seafood', emoji: '🐟', isCustom: false),
    IngredientTag(name: 'Dairy', emoji: '🧀', isCustom: false),
    IngredientTag(name: 'Bakery', emoji: '🍞', isCustom: false),
    IngredientTag(name: 'Frozen', emoji: '🧊', isCustom: false),
    IngredientTag(name: 'Pantry', emoji: '🥫', isCustom: false),
    IngredientTag(name: 'Spices', emoji: '🧂', isCustom: false),
    IngredientTag(name: 'Beverages', emoji: '🥤', isCustom: false),
    IngredientTag(name: 'Household', emoji: '🧻', isCustom: false),
    IngredientTag(name: 'Pharmacy', emoji: '💊', isCustom: false),
  ];


  static const List<String> builtInStores = [
    'Costco',
    "Trader Joe's",
    'Whole Foods',
    'Walmart',
    'Target',
    'Safeway',
  ];


  String _norm(String s) => s.trim().toLowerCase();

  IngredientTag? _builtInByName(String name) {
    final n = _norm(name);
    if (n.isEmpty) return null;
    for (final t in builtInTags) {
      if (_norm(t.name) == n) return t;
    }
    return null;
  }

  void _resolveBuiltInCollisionByName(String tagName) {
    final builtIn = _builtInByName(tagName);
    if (builtIn == null) return;

    final builtInKey = _norm(builtIn.name);

    customTags.removeWhere((t) => _norm(t.name) == builtInKey);

    for (final ing in ingredients.toList()) {
      if (ing.tagIsCustom == true && _norm(ing.tagName) == builtInKey) {
        ingredients.remove(ing);
        ingredients.add(
          Ingredient(
            name: ing.name,
            unit: ing.unit,
            tagName: builtIn.name,
            tagEmoji: builtIn.emoji,
            tagIsCustom: false,
            storeTag: ing.storeTag,
          ),
        );
      }
    }
  }

  Ingredient _normalizeIngredientTag(Ingredient ing) {
    if (ing.tagIsCustom != true) return ing;
    final builtIn = _builtInByName(ing.tagName);
    if (builtIn == null) return ing;

    _resolveBuiltInCollisionByName(builtIn.name);

    return Ingredient(
      name: ing.name,
      unit: ing.unit,
      tagName: builtIn.name,
      tagEmoji: builtIn.emoji,
      tagIsCustom: false,
      storeTag: ing.storeTag,
    );
  }

  void _sanitizeAfterLoad() {
    for (final t in customTags.toList()) {
      final builtIn = _builtInByName(t.name);
      if (builtIn != null) {
        _resolveBuiltInCollisionByName(builtIn.name);
      }
    }

    for (final ing in ingredients.toList()) {
      final normalized = _normalizeIngredientTag(ing);
      if (!identical(normalized, ing)) {
        ingredients.remove(ing);
        ingredients.add(normalized);
      }
    }
  }


  void upsertIngredient(Ingredient ing) {
    final normalized = _normalizeIngredientTag(ing);

    ingredients.remove(normalized);
    ingredients.add(normalized);
    _markDirty();
  }

  void deleteIngredientByName(String name) {
    ingredients.removeWhere((i) => i.name.trim().toLowerCase() == name.trim().toLowerCase());
    _markDirty();
  }


  List<IngredientTag> builtInTagsSorted() {
    final list = builtInTags.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<IngredientTag> customTagsSorted() {
    final list = customTags.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<IngredientTag> allTagsSorted() {
    final list = [...builtInTags, ...customTags]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  void upsertCustomTag(IngredientTag tag) {
    if (tag.name.trim().isEmpty || tag.emoji.trim().isNotEmpty == false) return;

    final cleanedName = tag.name.trim();
    final cleanedEmoji = tag.emoji.trim();

    final builtIn = _builtInByName(cleanedName);
    if (builtIn != null) {
      _resolveBuiltInCollisionByName(builtIn.name);
      _markDirty();
      return;
    }

    final cleaned = IngredientTag(name: cleanedName, emoji: cleanedEmoji, isCustom: true);

    customTags.removeWhere((t) => _norm(t.name) == _norm(cleaned.name));
    customTags.add(cleaned);
    _markDirty();
  }

  void deleteCustomTag(IngredientTag tag) {
    customTags.removeWhere((t) => t.name.trim().toLowerCase() == tag.name.trim().toLowerCase());

    for (final ing in ingredients.toList()) {
      if (ing.hasTag &&
          ing.tagName.trim().toLowerCase() == tag.name.trim().toLowerCase() &&
          ing.tagIsCustom == true) {
        ingredients.remove(ing);
        ingredients.add(
          Ingredient(
            name: ing.name,
            unit: ing.unit,
            tagName: '',
            tagEmoji: '',
            tagIsCustom: false,
            storeTag: ing.storeTag,
          ),
        );
      }
    }

    _markDirty();
  }


  List<String> builtInStoresSorted() {
    final list = builtInStores.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> customStoresSorted() {
    final list = customStores.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  List<String> allStoresSorted() {
    final list = {...builtInStores, ...customStores}.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  void upsertCustomStore(String store) {
    final s = store.trim();
    if (s.isEmpty) return;
    customStores.removeWhere((x) => x.trim().toLowerCase() == s.toLowerCase());
    customStores.add(s);
    _markDirty();
  }

  void deleteCustomStore(String store) {
    final s = store.trim().toLowerCase();
    customStores.removeWhere((x) => x.trim().toLowerCase() == s);

    for (final ing in ingredients.toList()) {
      if (ing.storeTag.trim().toLowerCase() == s) {
        ingredients.remove(ing);
        ingredients.add(
          Ingredient(
            name: ing.name,
            unit: ing.unit,
            tagName: ing.tagName,
            tagEmoji: ing.tagEmoji,
            tagIsCustom: ing.tagIsCustom,
            storeTag: '',
          ),
        );
      }
    }

    _markDirty();
  }

  Future<void> resetToDefault({bool deleteFile = false}) async {
    await ready;

    _saveDebounce?.cancel();

    ingredients.clear();
    customTags.clear();
    customStores.clear();

    _sanitizeAfterLoad();

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


  Map<String, dynamic> toJSON() {
    return {
      'ingredients': ingredients.map((i) => i.toJSON()).toList(),
      'customTags': customTags.map((t) => t.toJSON()).toList(),
      'customStores': customStores.toList(),
    };
  }

  static IngredientStore fromJSON(Map<String, dynamic> json) {
    final ingList = (json['ingredients'] as List? ?? [])
        .map((e) => Ingredient.fromJSON(e as Map<String, dynamic>))
        .toSet();

    final tagList = (json['customTags'] as List? ?? [])
        .map((e) => IngredientTag.fromJSON(e as Map<String, dynamic>))
        .toSet();

    final storeList = (json['customStores'] as List? ?? []).map((e) => e.toString()).toSet();

    final store = IngredientStore(
      ingredients: ingList,
      customTags: tagList,
      customStores: storeList,
    );

    store._loaded = true;
    store._sanitizeAfterLoad();

    return store;
  }
}
