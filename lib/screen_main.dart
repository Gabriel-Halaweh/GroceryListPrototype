
import 'package:flutter/material.dart';
import 'package:grocerylist_v2/background_generator.dart';
import 'package:grocerylist_v2/measurements.dart';
import 'package:grocerylist_v2/fuzzy_search.dart';
import 'package:grocerylist_v2/ingredient.dart';
import 'package:grocerylist_v2/recipe.dart';
import 'package:flutter/services.dart';
import 'package:grocerylist_v2/grocerylist.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:firebase_database/firebase_database.dart';
import 'dart:ui'; // ImageFilter (blur)
import 'dart:convert';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

enum _RecipeSortMode { alpha, scoreHigh }

class _BackIntent extends Intent {
  const _BackIntent();
}

enum MainMode {
  mainMenu,
  grocery,
  recipes,
  ingredients,
  calculator,
  settings,
  measurements,
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final MovingIconBackgroundController _bgCtrl = MovingIconBackgroundController();
  MainMode _mode = MainMode.mainMenu;

  final MeasurementStore _measurementStore = MeasurementStore();
  final IngredientStore _ingredientStore = IngredientStore();


  final GroceryListStore _groceryStore = GroceryListStore();
  final GlobalKey<_GroceryPanelState> _groceryKey = GlobalKey<_GroceryPanelState>();


  final RecipeStore _recipeStore = RecipeStore();
  final GlobalKey<_RecipesPanelState> _recipesKey = GlobalKey<_RecipesPanelState>();

  final GlobalKey<_IngredientsPanelState> _ingredientsKey = GlobalKey<_IngredientsPanelState>();

  static const _mainBg = Color(0xFF101B2D);
  static const _mainIc = Color(0xFF9AA6B2);
  static const _mainIcons = <IconData>[
    Icons.menu_book,
    Icons.book,
    Icons.auto_stories,
    Icons.library_books,
  ];

  static const _groceryBg = Color(0xFF0D2A1F);
  static const _groceryIc = Color(0xFF9FF0C9);
  static const _grocerySeq = <Color>[
    Color(0xFF101B2D),
    Color(0xFF0B3A2B),
    Color(0xFF0D2A1F),
  ];
  static const _groceryIcons = <IconData>[
    Icons.list_alt,
    Icons.check_circle_outline,
    Icons.shopping_cart_outlined,
    Icons.playlist_add_check,
  ];

  static const _recipesBg = Color(0xFF3A1116);
  static const _recipesIc = Color(0xFFFFD37A);
  static const _recipesSeq = <Color>[
    Color(0xFF101B2D),
    Color(0xFF4A141B),
    Color(0xFF3A1116),
  ];
  static const _recipesIcons = <IconData>[
    Icons.menu_book,
    Icons.restaurant_menu,
    Icons.local_dining,
    Icons.auto_stories,
  ];

  static const _ingredientsBg = Color(0xFF0E2246);
  static const _ingredientsIc = Color(0xFF9FD3FF);
  static const _ingredientsSeq = <Color>[
    Color(0xFF101B2D),
    Color(0xFF10305C),
    Color(0xFF0E2246),
  ];
  static const _ingredientsIcons = <IconData>[
    Icons.shopping_basket_outlined,
    Icons.egg_alt_outlined,
    Icons.local_grocery_store_outlined,
    Icons.spa_outlined,
  ];

  static const _calcBg = Color(0xFF0E0E18);
  static const _calcIc = Color(0xFFC7D2FE);
  static const _calcSeq = <Color>[
    Color(0xFF17173A),
    Color(0xFF11112A),
  ];
  static const _calcIcons = <IconData>[
    Icons.calculate_outlined,
    Icons.functions,
    Icons.percent,
    Icons.exposure_plus_1,
  ];

  static const _settingsBg = Color(0xFF2A2F37);
  static const _settingsIc = Color(0xFFB1BCC8);
  static const _settingsSeq = <Color>[
    Color(0xFF101B2D),
    Color(0xFF2F343D),
    Color(0xFF2A2F37),
  ];
  static const _settingsIcons = <IconData>[
    Icons.settings,
    Icons.tune,
    Icons.build_outlined,
    Icons.security_outlined,
  ];

  static const _measureBg = Color(0xFF20242B);
  static const _measureIc = Color(0xFFD4DCE6);
  static const _measureSeq = <Color>[
    Color(0xFF2A2F37),
    Color(0xFF232831),
    Color(0xFF20242B),
  ];
  static const _measureIcons = <IconData>[
    Icons.straighten,
    Icons.swap_horiz,
    Icons.square_foot,
    Icons.scale_outlined,
  ];

  static String _cell(List<String> row, int i) => (i >= 0 && i < row.length) ? row[i].trim() : '';

  static bool _isNumeric(String s) => RegExp(r'^-?\d+(\.\d+)?$').hasMatch(s.trim());

  static void _validateTagPair(String tagName, String tagEmoji) {
    final a = tagName.trim().isNotEmpty;
    final b = tagEmoji.trim().isNotEmpty;
    if (a != b) throw FormatException('Tag Name and Tag Emoji must both be filled or both empty.');
  }

  static String _defaultListNameForType(String type) {
    final t = type.trim().toLowerCase();
    if (t == 'template') return 'Imported Template';
    if (t == 'archived') return 'Imported Archived List';
    return 'Imported Grocery List';
  }

  static _GroceryDest _destForType(String type) {
    switch (type.trim().toLowerCase()) {
      case 'archived':
        return _GroceryDest.archived;
      case 'template':
        return _GroceryDest.templates;
      default:
        return _GroceryDest.active;
    }
  }

  static List<List<String>> _parseCsv(String text) {
    final out = <List<String>>[];
    final lines = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#')) continue;
      out.add(_splitCsvLine(raw));
    }
    return out;
  }

  static List<String> _splitCsvLine(String line) {
    final res = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"'); i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == ',' && !inQuotes) {
        res.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(c);
      }
    }
    res.add(sb.toString().trim());
    return res;
  }

  static Map<String, dynamic> _mergeIngredientJsonFromRows({
    required Map<String, dynamic> existing,
    required List<_CsvIngredientRow> ingredientRows,
    required List<_CsvIngredientRow> groceryIngredientRows,
    required Set<String> existingNormalizedNames,
  }) {
    final merged = Map<String, dynamic>.from(existing);

    final existingIngredients = (merged['ingredients'] as List? ?? []).toList();
    final existingTags = (merged['customTags'] as List? ?? []).toList();
    final existingStores = (merged['customStores'] as List? ?? [])
        .map((e) => e.toString()).toSet();

    final normNames = <String>{...existingNormalizedNames};

    final tagKeySet = <String>{};
    for (final t in existingTags) {
      if (t is Map) {
        final name = (t['name'] ?? '').toString().trim().toLowerCase();
        final emoji = (t['emoji'] ?? '').toString().trim();
        if (name.isNotEmpty && emoji.isNotEmpty) tagKeySet.add('$name|$emoji');
      }
    }

    void addIngredientIfMissing(_CsvIngredientRow r) {
      final n = r.name.trim();
      if (n.isEmpty) return;
      final k = n.toLowerCase();
      if (normNames.contains(k)) return;
      normNames.add(k);

      // 🔧 This map MUST match Ingredient.fromJSON keys in your app.
      final hasTag = r.tagName.trim().isNotEmpty && r.tagEmoji.trim().isNotEmpty;

      existingIngredients.add({
        'name': n,
        'unit': r.unit.trim(),
        'tagName': r.tagName.trim(),
        'tagEmoji': r.tagEmoji.trim(),
        'tagIsCustom': hasTag,
        'storeTag': r.store.trim(),
      });


      if (r.store.trim().isNotEmpty) existingStores.add(r.store.trim());

      if (r.tagName.trim().isNotEmpty && r.tagEmoji.trim().isNotEmpty) {
        final tk = '${r.tagName.trim().toLowerCase()}|${r.tagEmoji.trim()}';
        if (!tagKeySet.contains(tk)) {
          tagKeySet.add(tk);
          existingTags.add({'name': r.tagName, 'emoji': r.tagEmoji, 'isCustom': true});

        }
      }
    }

    for (final r in ingredientRows) addIngredientIfMissing(r);
    for (final r in groceryIngredientRows) addIngredientIfMissing(r);

    merged['ingredients'] = existingIngredients;
    merged['customTags'] = existingTags;
    merged['customStores'] = existingStores.toList();
    return merged;
  }

  static Map<String, dynamic> _mergeGroceryStoreJson({
    required Map<String, dynamic> existing,
    required Map<_GroceryGroupKey, List<_CsvIngredientRow>> groups,
  }) {
    final merged = Map<String, dynamic>.from(existing);

    final active = (merged['active'] as List? ?? []).toList();
    final archived = (merged['archived'] as List? ?? []).toList();
    final templates = (merged['templates'] as List? ?? []).toList();

    int nextListNumber = (merged['nextListNumber'] is int)
        ? merged['nextListNumber'] as int
        : 1;

    for (final entry in groups.entries) {
      final key = entry.key;
      final rows = entry.value;

      final itemJson = rows.map((r) {
        return {
          'id': GroceryIds.uid(),
          'ingredientName': r.name.trim(),
          'quantity': r.quantity.trim(),
          'unit': r.unit.trim(),
          'store': r.store.trim(),
          'checked': false,
          'tagName': r.tagName.trim(),
          'tagEmoji': r.tagEmoji.trim(),
          'tagIsCustom': false,
        };
      }).toList();

      final nowIso = DateTime.now().toIso8601String();

      final listMap = {
        'id': GroceryIds.uid(),
        'name': key.listName,
        'createdAt': nowIso,
        'completedAt': nowIso,               // ✅ critical for archived behavior
        'items': itemJson,
      };


      nextListNumber += 1;

      switch (key.dest) {
        case _GroceryDest.active:
          active.add(listMap);
          break;
        case _GroceryDest.archived:
          archived.add(listMap);
          break;
        case _GroceryDest.templates:
          templates.add(listMap);
          break;
      }
    }

    merged['active'] = active;
    merged['archived'] = archived;
    merged['templates'] = templates;
    merged['nextListNumber'] = nextListNumber;
    return merged;
  }



  late final DatabaseReference _dbRef;

  bool get _firebaseReady => Firebase.apps.isNotEmpty;




  Future<void> syncExport() async {
    if (!_firebaseReady) {
      debugPrint("Sync skipped: Firebase not initialized in main().");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Firebase not ready (init in main.dart).")),
      );
      return;
    }

    try {
      final Map<String, dynamic> cloudPayload = {
        'recipes': _recipeStore.toJson(),
        'grocery': _groceryStore.toJson(),
        'ingredients': _ingredientStore.toJSON(),
        'measurements': _measurementStore.toJSON(),
      };

      await _dbRef.set(cloudPayload);

      debugPrint("Cloud sync successful: All 4 stores uploaded.");

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Cloud Sync Complete ✅"), duration: Duration(seconds: 2)),
      );
    } catch (e) {
      debugPrint("Failed to export to cloud: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sync Failed: $e"), backgroundColor: Colors.red),
      );
    }
  }


  Future<void> syncLoad({bool showSnackbars = true}) async {
    if (!_firebaseReady) {
      debugPrint("Load skipped: Firebase not initialized in main().");
      if (showSnackbars && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Firebase not ready (init in main.dart)."),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final snapshot = await _dbRef.get();

      if (!snapshot.exists) {
        debugPrint("No cloud data found at ${_dbRef.path}");
        if (showSnackbars && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No cloud data found.")),
          );
        }
        return;
      }


      final normalized = jsonDecode(jsonEncode(snapshot.value));
      if (normalized is! Map) {
        throw StateError(
          "Unexpected cloud payload type: ${normalized.runtimeType}. Expected a Map at root.",
        );
      }

      final Map<String, dynamic> data = Map<String, dynamic>.from(normalized);

      if (!mounted) return;
      setState(() {
        final recipesRaw = data['recipes'];
        if (recipesRaw is Map) {
          final recipesMap = Map<String, dynamic>.from(recipesRaw);
          final newStore = RecipeStore.fromJson(recipesMap);
          _recipeStore.recipes = newStore.recipes;
          _recipeStore.customTags
            ..clear()
            ..addAll(newStore.customTags);
        }

        final ingredientsRaw = data['ingredients'];
        if (ingredientsRaw is Map) {
          final ingredientsMap = Map<String, dynamic>.from(ingredientsRaw);
          final newIngStore = IngredientStore.fromJSON(ingredientsMap);
          _ingredientStore.ingredients = newIngStore.ingredients;
          _ingredientStore.customTags = newIngStore.customTags;
          _ingredientStore.customStores = newIngStore.customStores;
        }

        final measurementsRaw = data['measurements'];
        if (measurementsRaw is Map) {
          final measurementsMap = Map<String, dynamic>.from(measurementsRaw);
          final newMeasStore = MeasurementStore.fromJSON(measurementsMap);

          _measurementStore.measurements.clear();
          for (var m in newMeasStore.measurements) {
            _measurementStore.getOrCreate(m.unit).relations = m.relations;
          }
        }

        final groceryRaw = data['grocery'];
        if (groceryRaw is Map) {
          final groceryData = Map<String, dynamic>.from(groceryRaw);

          final active = (groceryData['active'] is List)
              ? (groceryData['active'] as List)
              .whereType<dynamic>()
              .map((e) =>
              GroceryList.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
              : <GroceryList>[];

          final archived = (groceryData['archived'] is List)
              ? (groceryData['archived'] as List)
              .whereType<dynamic>()
              .map((e) =>
              GroceryList.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
              : <GroceryList>[];

          final templates = (groceryData['templates'] is List)
              ? (groceryData['templates'] as List)
              .whereType<dynamic>()
              .map((e) => GroceryListTemplate.fromJson(
              Map<String, dynamic>.from(e as Map)))
              .toList()
              : <GroceryListTemplate>[];

          _groceryStore.replaceFromCloud(
            active: active,
            archived: archived,
            templates: templates,
            nextListNumber:
            (groceryData['nextListNumber'] is int) ? groceryData['nextListNumber'] as int : null,
            markDirty: false,
          );
        }
      });

      debugPrint("Local data refreshed from Cloud.");

      if (showSnackbars && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Loaded from cloud ✅"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, st) {
      debugPrint("Failed to load from cloud: $e");
      debugPrint("$st");
      if (showSnackbars && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Load failed: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> importFromCsvText(
      String csvText, {
        bool showSnackbars = true,
      }) async {
    try {
      final rows = _parseCsv(csvText);
      if (rows.isEmpty) {
        if (showSnackbars && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No CSV rows found.')),
          );
        }
        return;
      }

      // Existing ingredient name set (normalized) using toJSON()
      final existingIngNames = <String>{};
      for (final ing in _ingredientStore.ingredients) {
        final m = ing.toJSON();
        final n = (m['name'] ?? '').toString().trim().toLowerCase();
        if (n.isNotEmpty) existingIngNames.add(n);
      }

      // Collect parsed import rows
      final ingredientRows = <_CsvIngredientRow>[];
      final groceryGroups = <_GroceryGroupKey, List<_CsvIngredientRow>>{};

      for (final r in rows) {
        if (r.isEmpty) continue;
        final type = r[0].trim();
        if (type.isEmpty) continue;

        final t = type.toLowerCase();

        // Ingredient row: Type, Name, CommonUnit, TagName, TagEmoji, Store
        if (t == 'ingredient') {
          final ingName = _cell(r, 1);
          if (ingName.isEmpty) continue;
          final commonUnit = _cell(r, 2);
          final tagName = _cell(r, 3);
          final tagEmoji = _cell(r, 4);
          final store = _cell(r, 5);
          _validateTagPair(tagName, tagEmoji);

          ingredientRows.add(_CsvIngredientRow(
            name: ingName,
            quantity: '',
            unit: commonUnit,
            tagName: tagName,
            tagEmoji: tagEmoji,
            store: store,
          ));
          continue;
        }

        // Grocery list row: GroceryList / Archived / Template
        if (t == 'grocerylist' || t == 'archived' || t == 'template') {
          // Supports TWO formats:
          // A) Type, ListName, IngredientName, Qty, Unit, TagName, TagEmoji, Store, (repeat groups...)
          // B) Type, IngredientName, Qty, Unit, TagName, TagEmoji, Store, (repeat groups...)
          final hasCol2 = r.length > 2 ? r[2].trim() : '';
          final col2IsNumeric = _isNumeric(hasCol2);
          final bool isLayoutB = col2IsNumeric || r.length < 8;

          final listName = isLayoutB
              ? _defaultListNameForType(type)
              : (_cell(r, 1).isEmpty ? _defaultListNameForType(type) : _cell(r, 1));

          final dest = _destForType(type);
          final key = _GroceryGroupKey(dest: dest, listName: listName);

          int start = isLayoutB ? 1 : 2;

          while (start < r.length) {
            final ingName = _cell(r, start + 0);
            if (ingName.isEmpty) {
              start += 6;
              continue;
            }

            final qty = _cell(r, start + 1);
            final unit = _cell(r, start + 2);
            final tagName = _cell(r, start + 3);
            final tagEmoji = _cell(r, start + 4);
            final store = _cell(r, start + 5);
            _validateTagPair(tagName, tagEmoji);

            groceryGroups.putIfAbsent(key, () => []).add(_CsvIngredientRow(
              name: ingName,
              quantity: qty,
              unit: unit,
              tagName: tagName,
              tagEmoji: tagEmoji,
              store: store,
            ));

            start += 6;
          }
        }
      }

      // Merge ingredient store JSON
      final mergedIngredientJson = _mergeIngredientJsonFromRows(
        existing: _ingredientStore.toJSON(),
        ingredientRows: ingredientRows,
        groceryIngredientRows: groceryGroups.values.expand((x) => x).toList(),
        existingNormalizedNames: existingIngNames,
      );
      final mergedIngredientStore = IngredientStore.fromJSON(mergedIngredientJson);

      // Merge grocery store JSON
      final mergedGroceryJson = _mergeGroceryStoreJson(
        existing: _groceryStore.toJson(),
        groups: groceryGroups,
      );
      final mergedGroceryStore = GroceryListStore.fromJson(mergedGroceryJson);

      // Apply merged stores (does not wipe, because we built merged JSON)
      _applyImportedStores(
        ingredients: mergedIngredientStore,
        groceryLists: mergedGroceryStore,
      );

      if (showSnackbars && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSV import complete ✅')),
        );
      }
    } catch (e) {
      if (showSnackbars && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV import failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _toMainMenu() {
    setState(() => _mode = MainMode.mainMenu);
    _bgCtrl.transitionTo(
      directionX: -1,
      directionY: -1,
      targetSpeedX: 22,
      targetSpeedY: 13,
      maxSpeedX: 56,
      maxSpeedY: 34,
      durationIn: const Duration(milliseconds: 1),
      durationOut: const Duration(milliseconds: 1),
      newBackgroundColor: _mainBg,
      backgroundColorSequence: const [Color(0xFF0B1220), _mainBg],
      newIconColor: _mainIc,
      newIcons: _mainIcons,
      curve: Curves.easeInOutCubic,
      curveStrength: 0.95,
    );
  }

  void _toGrocery() {
    setState(() => _mode = MainMode.grocery);
    _bgCtrl.transitionTo(
      directionX: -1,
      directionY: -1,
      targetSpeedX: 22,
      targetSpeedY: 13,
      maxSpeedX: 56,
      maxSpeedY: 34,
      durationIn: const Duration(milliseconds: 1),
      durationOut: const Duration(milliseconds: 1),
      newBackgroundColor: _groceryBg,
      backgroundColorSequence: _grocerySeq,
      newIconColor: _groceryIc,
      newIcons: _groceryIcons,
      curve: Curves.fastOutSlowIn,
      curveStrength: 0.95,
    );
  }

  void _toRecipes() {
    setState(() => _mode = MainMode.recipes);
    _bgCtrl.transitionTo(
      directionX: -1,
      directionY: -1,
      targetSpeedX: 22,
      targetSpeedY: 13,
      maxSpeedX: 56,
      maxSpeedY: 34,
      durationIn: const Duration(milliseconds: 1),
      durationOut: const Duration(milliseconds: 1),
      newBackgroundColor: _recipesBg,
      backgroundColorSequence: _recipesSeq,
      newIconColor: _recipesIc,
      newIcons: _recipesIcons,
      curve: Curves.fastOutSlowIn,
      curveStrength: 0.92,
    );
  }

  void _toIngredients() {
    setState(() => _mode = MainMode.ingredients);
    _bgCtrl.transitionTo(
      directionX: -1,
      directionY: -1,
      targetSpeedX: 22,
      targetSpeedY: 13,
      maxSpeedX: 56,
      maxSpeedY: 34,
      durationIn: const Duration(milliseconds: 1),
      durationOut: const Duration(milliseconds: 1),
      newBackgroundColor: _ingredientsBg,
      backgroundColorSequence: _ingredientsSeq,
      newIconColor: _ingredientsIc,
      newIcons: _ingredientsIcons,
      curve: Curves.easeInOutCubic,
      curveStrength: 0.95,
    );
  }

  void _toCalculator() {
    setState(() => _mode = MainMode.calculator);
    _bgCtrl.transitionTo(
      directionX: -1,
      directionY: -1,
      targetSpeedX: 22,
      targetSpeedY: 13,
      maxSpeedX: 56,
      maxSpeedY: 34,
      durationIn: const Duration(milliseconds: 1),
      durationOut: const Duration(milliseconds: 1),
      newBackgroundColor: _calcBg,
      backgroundColorSequence: _calcSeq,
      newIconColor: _calcIc,
      newIcons: _calcIcons,
      curve: Curves.easeInOutExpo,
      curveStrength: 0.88,
    );
  }

  void _toSettings() {
    setState(() => _mode = MainMode.settings);
    _bgCtrl.transitionTo(
      directionX: -1,
      directionY: -1,
      targetSpeedX: 22,
      targetSpeedY: 13,
      maxSpeedX: 56,
      maxSpeedY: 34,
      durationIn: const Duration(milliseconds: 1),
      durationOut: const Duration(milliseconds: 1),
      newBackgroundColor: _settingsBg,
      backgroundColorSequence: _settingsSeq,
      newIconColor: _settingsIc,
      newIcons: _settingsIcons,
      curve: Curves.easeInOutCubic,
      curveStrength: 0.93,
    );
  }

  void _toMeasurements() {
    setState(() => _mode = MainMode.measurements);
    _bgCtrl.transitionTo(
      directionX: -1,
      directionY: -1,
      targetSpeedX: 22,
      targetSpeedY: 13,
      maxSpeedX: 56,
      maxSpeedY: 34,
      durationIn: const Duration(milliseconds: 1),
      durationOut: const Duration(milliseconds: 1),
      newBackgroundColor: _measureBg,
      backgroundColorSequence: _measureSeq,
      newIconColor: _measureIc,
      newIcons: _measureIcons,
      curve: Curves.easeInOutCubic,
      curveStrength: 0.93,
    );
  }

  void _applyImportedStores({
    RecipeStore? recipes,
    IngredientStore? ingredients,
    MeasurementStore? measurements,
    GroceryListStore? groceryLists,
  }) {
    if (!mounted) return;

    setState(() {
      // Recipes
      if (recipes != null) {
        _recipeStore.recipes = recipes.recipes;
        _recipeStore.customTags
          ..clear()
          ..addAll(recipes.customTags);
      }

      // Ingredients
      if (ingredients != null) {
        _ingredientStore.ingredients = ingredients.ingredients;
        _ingredientStore.customTags = ingredients.customTags;
        _ingredientStore.customStores = ingredients.customStores;
      }

      // Measurements
      if (measurements != null) {
        _measurementStore.measurements.clear();
        for (final m in measurements.measurements) {
          _measurementStore.getOrCreate(m.unit).relations = m.relations;
        }
      }

      // Grocery Lists
      if (groceryLists != null) {
        // We avoid touching private fields by using toJson() and re-parsing like syncLoad does.
        final groceryData = groceryLists.toJson();

        final active = (groceryData['active'] is List)
            ? (groceryData['active'] as List)
            .whereType<dynamic>()
            .map((e) => GroceryList.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
            : <GroceryList>[];

        final archived = (groceryData['archived'] is List)
            ? (groceryData['archived'] as List)
            .whereType<dynamic>()
            .map((e) => GroceryList.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
            : <GroceryList>[];

        final templates = (groceryData['templates'] is List)
            ? (groceryData['templates'] as List)
            .whereType<dynamic>()
            .map((e) => GroceryListTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList()
            : <GroceryListTemplate>[];

        _groceryStore.replaceFromCloud(
          active: active,
          archived: archived,
          templates: templates,
          nextListNumber: (groceryData['nextListNumber'] is int)
              ? groceryData['nextListNumber'] as int
              : null,
          markDirty: true, // ✅ import from file should generally be treated as a local change
        );
      }
    });
  }





  Future<void> _openGroceryRecipePicker() async {
    final picked = await showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.88,
        child: _RecipeQuickPickSheet(store: _recipeStore),
      ),
    );

    if (!mounted || picked == null) return;

    final selectedIngredients = await showModalBottomSheet<List<RecipeIngredient>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _RecipeIngredientChecklistSheet(recipe: picked),
      ),
    );

    if (!mounted || selectedIngredients == null || selectedIngredients.isEmpty) return;

    final items = selectedIngredients.map((i) {
      return GroceryListItem(
        id: GroceryIds.uid(),
        ingredientName: i.name.trim(),
        quantity: i.quantity.trim(),
        unit: i.unit.trim(),
        store: '',
        checked: false,
        tagName: '',
        tagEmoji: '',
        tagIsCustom: false,
      );
    }).toList();

    _groceryKey.currentState?.addItemsToOpenList(items);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${items.length} item(s) from "${picked.title}"')),
      );
    }
  }

  Future<void> _openGroceryTemplateOrArchivedPicker() async {
    final picked = await showModalBottomSheet<_GrocerySourceEntry>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.88,
        child: _GrocerySourcePickSheet(store: _groceryStore),
      ),
    );

    if (!mounted || picked == null) return;

    final selectedItems = await showModalBottomSheet<List<GroceryListItem>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: _GroceryItemChecklistSheet(
          title: picked.label,
          items: picked.items,
        ),
      ),
    );

    if (!mounted || selectedItems == null || selectedItems.isEmpty) return;

    final toAdd = selectedItems.map((src) {
      return GroceryListItem(
        id: GroceryIds.uid(),
        ingredientName: src.ingredientName,
        quantity: src.quantity,
        unit: src.unit,
        store: src.store,
        checked: false,
        tagName: src.tagName,
        tagEmoji: src.tagEmoji,
        tagIsCustom: src.tagIsCustom,
      );
    }).toList();

    _groceryKey.currentState?.addItemsToOpenList(toAdd);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${toAdd.length} item(s) from ${picked.label}')),
      );
    }
  }


  @override
  void initState() {
    super.initState();


    _dbRef = FirebaseDatabase.instance.ref('appData');

    WidgetsBinding.instance.addPostFrameCallback((_) {

      syncLoad(showSnackbars: false);
    });
  }


  @override
  Widget build(BuildContext context) {
    final showBack = _mode != MainMode.mainMenu;

    void handleBack() {
      if (_mode == MainMode.measurements) {
        _toSettings();
        return;
      }
      _toMainMenu();
    }

    final fab = switch (_mode) {
      MainMode.grocery => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'grocery_list_source_fab',
            tooltip: 'Add from template / archived',
            onPressed: _openGroceryTemplateOrArchivedPicker,
            child: const Icon(Icons.bookmarks_outlined),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'grocery_recipe_fab',
            tooltip: 'Add from recipe',
            onPressed: _openGroceryRecipePicker,
            child: const Icon(Icons.menu_book),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'grocery_add_item_fab',
            tooltip: 'Add Item',
            onPressed: () => _groceryKey.currentState?.openAddItem(),
            child: const Icon(Icons.add),
          ),
        ],
      ),
      MainMode.ingredients => FloatingActionButton(
        tooltip: 'Add Ingredient',
        onPressed: () => _ingredientsKey.currentState?.openAddIngredient(),
        child: const Icon(Icons.add),
      ),
      MainMode.recipes => FloatingActionButton(
        tooltip: 'Add Recipe',
        onPressed: () => _recipesKey.currentState?.openAddRecipe(),
        child: const Icon(Icons.add),
      ),
      _ => null,
    };

    return PopScope(
      canPop: _mode == MainMode.mainMenu,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_mode != MainMode.mainMenu) handleBack();
      },
      child: Shortcuts(
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.escape): _BackIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _BackIntent: CallbackAction<_BackIntent>(
              onInvoke: (_) {
                if (_mode != MainMode.mainMenu) handleBack();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              floatingActionButton: fab,
              appBar: AppBar(
                centerTitle: true,
                leading: showBack
                    ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: handleBack,
                  tooltip: 'Back',
                )
                    : null,
                title: Text(
                  _mode == MainMode.mainMenu
                      ? 'Main Menu'
                      : switch (_mode) {
                    MainMode.grocery => 'Grocery List',
                    MainMode.recipes => 'Recipes',
                    MainMode.ingredients => 'Ingredients',
                    MainMode.calculator => 'Calculator',
                    MainMode.settings => 'Settings',
                    MainMode.measurements => 'Measurements',
                    MainMode.mainMenu => 'Main Menu',
                  },
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.cloud_upload_outlined),
                    onPressed: () async {
                      await syncExport();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Data exported to cloud!')),
                        );
                      }
                    },
                    tooltip: 'Sync to Cloud',
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings),
                    onPressed: _toSettings,
                    tooltip: 'Settings',
                  ),
                ],
              ),
              body: Stack(
                children: [
                  MovingIconBackground(
                    controller: _bgCtrl,
                    baseSpeedX: 22,
                    baseSpeedY: 13,
                    initialDirectionX: -1,
                    initialDirectionY: -1,
                    iconSpacingX: 72,
                    iconSpacingY: 72,
                    iconSize: 28,
                    icons: _mainIcons,
                    backgroundColor: _mainBg,
                    iconColor: _mainIc,
                    rowIconOffsetStep: 2,
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _mode == MainMode.mainMenu
                        ? _MainMenuPanel(
                      key: const ValueKey('mainMenu'),
                      onGrocery: _toGrocery,
                      onRecipes: _toRecipes,
                      onIngredients: _toIngredients,
                      onCalculator: _toCalculator,
                    )
                        : const SizedBox.shrink(key: ValueKey('empty')),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _mode == MainMode.mainMenu
                        ? const SizedBox.shrink(key: ValueKey('noModePanel'))
                        : _MainModePanel(
                      key: ValueKey('panel_${_mode.name}'),
                      mode: _mode,
                      measurementStore: _measurementStore,
                      ingredientStore: _ingredientStore,
                      groceryStore: _groceryStore,
                      groceryKey: _groceryKey,
                      recipeStore: _recipeStore,
                      recipesKey: _recipesKey,
                      ingredientsKey: _ingredientsKey,
                      onOpenMeasurements: () async {
                        final open = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Measurements'),
                            content: const Text(
                              'Manage units and conversion relationships (e.g., 7:13).',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Open'),
                              ),
                            ],
                          ),
                        );

                        if (open == true && context.mounted) {
                          _toMeasurements();
                        }
                      },


                      onSyncLoad: () async {
                        await syncLoad(showSnackbars: true);
                      },

                      onImportStores: _applyImportedStores,
                      onImportCsv: (csvText) async {
                        await importFromCsvText(csvText, showSnackbars: true);
                      },

                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _MainMenuPanel extends StatelessWidget {
  const _MainMenuPanel({
    super.key,
    required this.onGrocery,
    required this.onRecipes,
    required this.onIngredients,
    required this.onCalculator,
  });

  final VoidCallback onGrocery;
  final VoidCallback onRecipes;
  final VoidCallback onIngredients;
  final VoidCallback onCalculator;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;


    final bool isWide = w >= 720;


    final double buttonHeight = isWide ? 60 : 56;
    final double gap = isWide ? 14 : 12;

    Widget glassButton({
      required String heroTag,
      required VoidCallback onPressed,
      required IconData icon,
      required String label,
    }) {
      return SizedBox(
        width: double.infinity,
        height: buttonHeight,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0x20FFFFFF), // slightly stronger tint for readability
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x33FFFFFF)),
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: FloatingActionButton.extended(
                heroTag: heroTag,
                onPressed: onPressed,
                icon: Icon(icon),
                label: Text(
                  label,
                  style: TextStyle(
                    fontSize: isWide ? 16 : 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(isWide ? 20 : 16),
                decoration: BoxDecoration(
                  color: const Color(0x10FFFFFF),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: isWide
                    ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: gap,
                        crossAxisSpacing: gap,
                        childAspectRatio: 3.6, // wide “pill” buttons
                      ),
                      children: [
                        glassButton(
                          heroTag: 'main_grocery',
                          onPressed: onGrocery,
                          icon: Icons.list_alt,
                          label: 'Grocery List',
                        ),
                        glassButton(
                          heroTag: 'main_recipes',
                          onPressed: onRecipes,
                          icon: Icons.menu_book,
                          label: 'Recipes',
                        ),
                        glassButton(
                          heroTag: 'main_ingredients',
                          onPressed: onIngredients,
                          icon: Icons.shopping_basket_outlined,
                          label: 'Ingredients',
                        ),
                        glassButton(
                          heroTag: 'main_calc',
                          onPressed: onCalculator,
                          icon: Icons.calculate_outlined,
                          label: 'Calculator',
                        ),
                      ],
                    ),
                  ],
                )
                    : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    glassButton(
                      heroTag: 'main_grocery',
                      onPressed: onGrocery,
                      icon: Icons.list_alt,
                      label: 'Grocery List',
                    ),
                    SizedBox(height: gap),
                    glassButton(
                      heroTag: 'main_recipes',
                      onPressed: onRecipes,
                      icon: Icons.menu_book,
                      label: 'Recipes',
                    ),
                    SizedBox(height: gap),
                    glassButton(
                      heroTag: 'main_ingredients',
                      onPressed: onIngredients,
                      icon: Icons.shopping_basket_outlined,
                      label: 'Ingredients',
                    ),
                    SizedBox(height: gap),
                    glassButton(
                      heroTag: 'main_calc',
                      onPressed: onCalculator,
                      icon: Icons.calculate_outlined,
                      label: 'Calculator',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}

class _MainModePanel extends StatelessWidget {
  const _MainModePanel({
    super.key,
    required this.mode,
    required this.measurementStore,
    required this.ingredientStore,
    required this.groceryStore,
    required this.groceryKey,
    required this.recipeStore,
    required this.recipesKey,
    required this.ingredientsKey,
    required this.onOpenMeasurements,
    required this.onSyncLoad,
    required this.onImportStores,
    required this.onImportCsv,
  });

  final MainMode mode;
  final MeasurementStore measurementStore;
  final IngredientStore ingredientStore;

  final GroceryListStore groceryStore;
  final GlobalKey<_GroceryPanelState> groceryKey;

  final RecipeStore recipeStore;
  final GlobalKey<_RecipesPanelState> recipesKey;

  final GlobalKey<_IngredientsPanelState> ingredientsKey;
  final VoidCallback onOpenMeasurements;

  final Future<void> Function() onSyncLoad;

  final void Function({
  RecipeStore? recipes,
  IngredientStore? ingredients,
  MeasurementStore? measurements,
  GroceryListStore? groceryLists,
  }) onImportStores;

  // ✅ changed: now takes pasted CSV text
  final Future<void> Function(String csvText) onImportCsv;

  @override
  Widget build(BuildContext context) {
    return switch (mode) {
      MainMode.settings => _SettingsPanel(
        key: const ValueKey('settingsPanel'),
        onOpenMeasurements: onOpenMeasurements,
        recipeStore: recipeStore,
        measurementStore: measurementStore,
        ingredientStore: ingredientStore,
        groceryListStore: groceryStore,
        onImportStores: onImportStores,
        onSyncLoad: onSyncLoad,
        onImportCsv: onImportCsv,
      ),
      MainMode.measurements => _MeasurementsPanel(
        key: const ValueKey('measurementsPanel'),
        store: measurementStore,
      ),
      MainMode.calculator => _CalculatorPanel(
        key: const ValueKey('calculatorPanel'),
        store: measurementStore,
      ),
      MainMode.grocery => _GroceryPanel(
        key: groceryKey,
        store: groceryStore,
        ingredientStore: ingredientStore,
        measurementStore: measurementStore,
      ),
      MainMode.ingredients => _IngredientsPanel(
        key: ingredientsKey,
        store: ingredientStore,
        measurementStore: measurementStore,
      ),
      MainMode.recipes => _RecipesPanel(
        key: recipesKey,
        store: recipeStore,
        ingredientStore: ingredientStore,
        measurementStore: measurementStore,
      ),
      _ => _PlaceholderPanel(
        key: ValueKey('placeholder_${mode.name}'),
        text: switch (mode) {
          MainMode.grocery => '',
          MainMode.recipes => '',
          MainMode.mainMenu => '',
          MainMode.settings => '',
          MainMode.measurements => '',
          MainMode.ingredients => '',
          MainMode.calculator => '',
        },
      ),
    };
  }
}


class _PlaceholderPanel extends StatelessWidget {
  const _PlaceholderPanel({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5F7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x1F000000)),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black87),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}


class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    super.key,
    required this.onOpenMeasurements,
    this.onAfterDataReset,
    required this.recipeStore,
    required this.ingredientStore,
    required this.measurementStore,
    required this.groceryListStore,
    required this.onSyncLoad,
    required this.onImportStores,
    required this.onImportCsv,
  });

  final void Function({
  RecipeStore? recipes,
  IngredientStore? ingredients,
  MeasurementStore? measurements,
  GroceryListStore? groceryLists,
  }) onImportStores;

  // ✅ changed: now takes pasted CSV text
  final Future<void> Function(String csvText) onImportCsv;

  static const _importTargets = <String, String>{
    'Grocery Lists': 'grocery_list_store.json',
    'Ingredients': 'ingredient_store.json',
    'Measurements': 'measurement_store.json',
    'Recipes': 'recipe_store.json',
  };

  final RecipeStore recipeStore;
  final IngredientStore ingredientStore;
  final MeasurementStore measurementStore;
  final GroceryListStore groceryListStore;

  final VoidCallback onOpenMeasurements;
  final VoidCallback? onAfterDataReset;
  final Future<void> Function() onSyncLoad;

  static const String _dataFolderName = 'Data';

  static const _exportTargets = <String, String>{
    'Grocery Lists': 'grocery_list_store.json',
    'Ingredients': 'ingredient_store.json',
    'Measurements': 'measurement_store.json',
    'Recipes': 'recipe_store.json',
  };

  Future<Directory> _dataDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, _dataFolderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> _dataFile(String fileName) async {
    final dir = await _dataDir();
    return File(p.join(dir.path, fileName));
  }

  // ✅ safer reset: requires explicit confirmation phrase
  Future<void> _resetAllData(BuildContext context) async {
    final confirm = TextEditingController();
    bool understood = false;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Delete ALL app data?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'This deletes all local saved data:\n'
                    '• Grocery Lists\n'
                    '• Ingredients\n'
                    '• Measurements\n'
                    '• Recipes\n\n'
                    'This cannot be undone.\n\n'
                    'To confirm, type: DELETE ALL',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirm,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Type DELETE ALL',
                ),
                onChanged: (v) {
                  setState(() {
                    understood = v.trim().toUpperCase() == 'DELETE ALL';
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: understood ? () => Navigator.of(ctx).pop(true) : null,
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    try {
      await Future.wait([
        recipeStore.ready,
        ingredientStore.ready,
        measurementStore.ready,
        groceryListStore.ready,
      ]);

      await Future.wait([
        recipeStore.resetToDefault(deleteFile: true),
        ingredientStore.resetToDefault(deleteFile: true),
        measurementStore.resetToDefault(deleteFile: true),
        groceryListStore.resetToDefault(deleteFile: true),
      ]);

      onAfterDataReset?.call();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data deleted.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete data: $e')),
        );
      }
    }
  }

  Future<void> _exportJson(BuildContext context) async {
    final chosen = await showModalBottomSheet<MapEntry<String, String>>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  'Export JSON',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              ..._exportTargets.entries.map(
                    (e) => ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: Text(e.key),
                  subtitle: Text(e.value),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(ctx).pop(e),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (chosen == null) return;

    try {
      final Map<String, dynamic> jsonMap;
      switch (chosen.value) {
        case 'grocery_list_store.json':
          jsonMap = groceryListStore.toJson();
          break;
        case 'ingredient_store.json':
          jsonMap = ingredientStore.toJSON();
          break;
        case 'measurement_store.json':
          jsonMap = measurementStore.toJSON();
          break;
        case 'recipe_store.json':
          jsonMap = recipeStore.toJson();
          break;
        default:
          throw StateError('Unknown export target: ${chosen.value}');
      }

      final jsonString = const JsonEncoder.withIndent('  ').convert(jsonMap);
      final bytes = utf8.encode(jsonString);

      final xfile = XFile.fromData(
        bytes,
        name: chosen.value,
        mimeType: 'application/json',
      );

      await Share.shareXFiles(
        [xfile],
        text: 'Export: ${chosen.key}',
        subject: chosen.key,
      );
    } catch (e, st) {
      debugPrint('Export failed: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importJson(BuildContext context) async {
    final chosen = await showModalBottomSheet<MapEntry<String, String>>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Text(
                  'Import JSON',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              ..._importTargets.entries.map(
                    (e) => ListTile(
                  leading: const Icon(Icons.file_open_outlined),
                  title: Text(e.key),
                  subtitle: Text(e.value),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(ctx).pop(e),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (chosen == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final picked = result.files.single;
      final bytes = picked.bytes;
      if (bytes == null) throw StateError('Could not read the selected file.');

      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) throw FormatException('Expected a JSON object at the top level.');

      final map = decoded.cast<String, dynamic>();

      switch (chosen.value) {
        case 'recipe_store.json': {
          final imported = RecipeStore.fromJson(map);
          onImportStores(recipes: imported);
          break;
        }
        case 'ingredient_store.json': {
          final imported = IngredientStore.fromJSON(map);
          onImportStores(ingredients: imported);
          break;
        }
        case 'measurement_store.json': {
          final imported = MeasurementStore.fromJSON(map);
          onImportStores(measurements: imported);
          break;
        }
        case 'grocery_list_store.json': {
          final imported = GroceryListStore.fromJson(map);
          onImportStores(groceryLists: imported);
          break;
        }
        default:
          throw StateError('Unknown import target: ${chosen.value}');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported: ${chosen.key}')),
        );
      }
    } catch (e, st) {
      debugPrint('Import failed: $e\n$st');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  // ✅ NEW: paste panel for CSV
  Future<void> _openCsvPastePanel(BuildContext context) async {
    final controller = TextEditingController();

    final csvText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import CSV'),
        content: SizedBox(
          width: 720,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Paste CSV rows.\n\n'
                    'Supported row types:\n'
                    '• Ingredient, Name, CommonUnit(optional), TagName(optional), TagEmoji(optional), Store(optional)\n'
                    '• GroceryList rows (ACTIVE only):\n'
                    '  Format A: GroceryList, ListName, IngredientName, Qty(optional), Unit(optional), TagName(optional), TagEmoji(optional), Store(optional), (repeat groups of 6)\n'
                    '  Format B: GroceryList, IngredientName, Qty(optional), Unit(optional), TagName(optional), TagEmoji(optional), Store(optional), (repeat groups of 6)\n\n'
                    'Rule: TagName and TagEmoji must both be filled or both be empty.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 14,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Paste CSV here...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (csvText == null || csvText.trim().isEmpty) return;

    await onImportCsv(csvText);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Card(
          elevation: 0,
          color: const Color(0xFFF3F5F7),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x1F000000)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.straighten, color: Colors.black87),
                  title: const Text('Measurements', style: TextStyle(color: Colors.black87)),
                  subtitle: const Text('Units, ratios, and conversions', style: TextStyle(color: Colors.black54)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.black54),
                  onTap: onOpenMeasurements,
                ),
                const Divider(height: 1, color: Color(0x1F000000)),

                ListTile(
                  leading: const Icon(Icons.upload_file, color: Colors.black87),
                  title: const Text('Export JSON', style: TextStyle(color: Colors.black87)),
                  subtitle: const Text('Share a selected data file', style: TextStyle(color: Colors.black54)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.black54),
                  onTap: () => _exportJson(context),
                ),
                const Divider(height: 1, color: Color(0x1F000000)),

                ListTile(
                  leading: const Icon(Icons.download_for_offline_outlined, color: Colors.black87),
                  title: const Text('Import JSON', style: TextStyle(color: Colors.black87)),
                  subtitle: const Text('Pick a JSON file and import it', style: TextStyle(color: Colors.black54)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.black54),
                  onTap: () => _importJson(context),
                ),
                const Divider(height: 1, color: Color(0x1F000000)),

                // ✅ ACTIVE-only CSV import via paste panel
                ListTile(
                  leading: const Icon(Icons.table_chart_outlined, color: Colors.black87),
                  title: const Text('Import CSV', style: TextStyle(color: Colors.black87)),
                  subtitle: const Text('Paste CSV text and import', style: TextStyle(color: Colors.black54)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.black54),
                  onTap: () => _openCsvPastePanel(context),
                ),
                const Divider(height: 1, color: Color(0x1F000000)),

                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined, color: Colors.black87),
                  title: const Text('Load from Cloud', style: TextStyle(color: Colors.black87)),
                  subtitle: const Text('Replace local data with cloud data', style: TextStyle(color: Colors.black54)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.black54),
                  onTap: () async => onSyncLoad(),
                ),
                const Divider(height: 1, color: Color(0x1F000000)),

                // ✅ spacing + safety section way below
                const SizedBox(height: 28),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: const Color(0x12FF0000),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0x33FF0000)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Danger Zone',
                        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Deletes all local data on this device. You will be asked to type a confirmation phrase.',
                        style: TextStyle(color: Colors.black87),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('Delete All Data', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                  subtitle: const Text('Irreversible — removes all saved data', style: TextStyle(color: Colors.black54)),
                  trailing: const Icon(Icons.chevron_right, color: Colors.black54),
                  onTap: () => _resetAllData(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}






enum _GrocerySourceKind { template, archived }

class _GrocerySourceEntry {
  const _GrocerySourceEntry({
    required this.kind,
    required this.id,
    required this.name,
    required this.items,
  });

  final _GrocerySourceKind kind;
  final String id;
  final String name;
  final List<GroceryListItem> items;

  String get kindLabel => kind == _GrocerySourceKind.template ? 'Template' : 'Archived';
  String get label => '$kindLabel: $name';
}

class _GrocerySourcePickSheet extends StatefulWidget {
  const _GrocerySourcePickSheet({required this.store});

  final GroceryListStore store;

  @override
  State<_GrocerySourcePickSheet> createState() => _GrocerySourcePickSheetState();
}

class _GrocerySourcePickSheetState extends State<_GrocerySourcePickSheet> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_GrocerySourceEntry> _allEntries() {
    final out = <_GrocerySourceEntry>[];

    for (final t in widget.store.templates) {
      out.add(_GrocerySourceEntry(
        kind: _GrocerySourceKind.template,
        id: (t as dynamic).id as String,
        name: (t as dynamic).name as String,
        items: ((t as dynamic).items as List<GroceryListItem>),
      ));
    }

    for (final l in widget.store.archived) {
      out.add(_GrocerySourceEntry(
        kind: _GrocerySourceKind.archived,
        id: l.id,
        name: l.name,
        items: l.items.toList(),
      ));
    }

    out.sort((a, b) {
      final k = a.kind.index.compareTo(b.kind.index);
      if (k != 0) return k;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return out;
  }

  List<_GrocerySourceEntry> _filtered() {
    final q = _searchCtrl.text.trim();
    final all = _allEntries();

    if (q.isEmpty) return all;

    final hits = fuzzySearch<_GrocerySourceEntry>(
      all,
      q,
      250,
      0.18,
      stringify: (e) {
        final sample = e.items.take(20).map((it) => it.ingredientName).join(' ');
        return '${e.name} ${e.kindLabel} $sample';
      },
    );
    return hits.toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.bookmarks_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Add from template / archived',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Search',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchCtrl.text.trim().isEmpty
                    ? null
                    : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No results'))
                  : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final e = list[i];
                  return ListTile(
                    title: Text(e.name, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${e.kindLabel} • ${e.items.length} items'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).pop(e),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroceryItemChecklistSheet extends StatefulWidget {
  const _GroceryItemChecklistSheet({
    required this.title,
    required this.items,
  });

  final String title;
  final List<GroceryListItem> items;

  @override
  State<_GroceryItemChecklistSheet> createState() => _GroceryItemChecklistSheetState();
}

class _GroceryItemChecklistSheetState extends State<_GroceryItemChecklistSheet> {
  late final List<GroceryListItem> _sortedItems;
  late final List<_Row> _rows;

  /// Checked state keyed by item id so headers don’t interfere with indices.
  late final Map<String, bool> _checkedById;

  @override
  void initState() {
    super.initState();

    _sortedItems = widget.items.toList()
      ..sort((a, b) {
        final at = _tagKey(a);
        final bt = _tagKey(b);
        final tc = at.compareTo(bt);
        if (tc != 0) return tc;

        final an = a.ingredientName.trim().toLowerCase();
        final bn = b.ingredientName.trim().toLowerCase();
        return an.compareTo(bn);
      });

    _checkedById = {
      for (final it in _sortedItems) it.id: true,
    };

    _rows = _buildRows(_sortedItems);
  }

  /// Sort/group key: tagName (trim/lower). Untagged goes last.
  String _tagKey(GroceryListItem it) {
    final t = it.tagName.trim().toLowerCase();
    if (t.isEmpty) return '{untagged}'; // '{' sorts after letters in ASCII
    return t;
  }

  /// Display label for section headers.
  String _tagLabel(GroceryListItem it) {
    final name = it.tagName.trim();
    final emoji = it.tagEmoji.trim();

    if (name.isEmpty) return 'Untagged';
    if (emoji.isEmpty) return name;
    return '$emoji $name';
  }

  List<_Row> _buildRows(List<GroceryListItem> sorted) {
    final rows = <_Row>[];
    String? currentTagKey;

    for (final it in sorted) {
      final tk = _tagKey(it);
      if (tk != currentTagKey) {
        currentTagKey = tk;
        rows.add(_Row.header(_tagLabel(it)));
      }
      rows.add(_Row.item(it));
    }

    return rows;
  }

  String _fmtSub(GroceryListItem it) {
    final bits = <String>[];
    final q = it.quantity.trim();
    final u = it.unit.trim();
    if (q.isNotEmpty && u.isNotEmpty) {
      bits.add('$q $u');
    } else if (q.isNotEmpty) {
      bits.add(q);
    } else if (u.isNotEmpty) {
      bits.add(u);
    }
    final s = it.store.trim();
    if (s.isNotEmpty) bits.add(s);
    return bits.join(' • ');
  }

  bool get _canAdd => _checkedById.values.any((v) => v);

  void _setAll(bool value) {
    setState(() {
      for (final it in _sortedItems) {
        _checkedById[it.id] = value;
      }
    });
  }

  void _toggleItem(GroceryListItem it, bool? v) {
    setState(() => _checkedById[it.id] = v ?? false);
  }

  void _popSelected() {
    final selected = <GroceryListItem>[];
    for (final it in _sortedItems) {
      if (_checkedById[it.id] == true) selected.add(it);
    }
    Navigator.of(context).pop(selected);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.checklist),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _rows.isEmpty
                  ? const Center(child: Text('No items.'))
                  : ListView.separated(
                itemCount: _rows.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final row = _rows[i];

                  if (row.isHeader) {
                    // Non-selectable section title.
                    return Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 6),
                      child: Text(
                        row.headerText!,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }

                  final it = row.item!;
                  final sub = _fmtSub(it);

                  return CheckboxListTile(
                    value: _checkedById[it.id] ?? false,
                    onChanged: (v) => _toggleItem(it, v),
                    title: Text(it.ingredientName),
                    subtitle: sub.isEmpty ? null : Text(sub),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: () => _setAll(false),
                  child: const Text('None'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _setAll(true),
                  child: const Text('All'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _canAdd ? _popSelected : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Row {
  final String? headerText;
  final GroceryListItem? item;

  bool get isHeader => headerText != null;

  const _Row._({this.headerText, this.item});

  factory _Row.header(String text) => _Row._(headerText: text);
  factory _Row.item(GroceryListItem it) => _Row._(item: it);
}



class _GroceryPanel extends StatefulWidget {
  const _GroceryPanel({
    super.key,
    required this.store,
    required this.ingredientStore,
    required this.measurementStore,
  });

  final GroceryListStore store;
  final IngredientStore ingredientStore;
  final MeasurementStore measurementStore;

  @override
  State<_GroceryPanel> createState() => _GroceryPanelState();
}

class _GroceryPanelState extends State<_GroceryPanel> {
  String? _openListId;

  bool _showArchive = false; // archive toggle
  String _templateQuery = '';

  final TextEditingController _itemSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _itemSearchCtrl.dispose();
    super.dispose();
  }

  void openAddItem() {
    if (_openListId == null) {
      final l = widget.store.createNewList(name: 'New List');
      setState(() => _openListId = l.id);
    }
    _openItemEditor();
  }

  void addItemsToOpenList(List<GroceryListItem> items) {
    if (items.isEmpty) return;

    if (_openListId == null) {
      final l = widget.store.createNewList(name: 'New List');
      _openListId = l.id;
    }

    if (_openListIsArchived) return;

    final l = _openList;
    if (l == null) return;

    for (final it in items) {
      widget.store.upsertItem(l.id, it);
    }
    setState(() {});
  }

  GroceryList? get _openList {
    final id = _openListId;
    if (id == null) return null;
    return widget.store.getActiveById(id) ?? widget.store.getArchivedById(id);
  }

  bool get _openListIsArchived {
    final id = _openListId;
    if (id == null) return false;
    return widget.store.getArchivedById(id) != null;
  }

  String _fmtDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  _TagInfo _tagForIngredientName(String ingredientName) {
    final t = ingredientName.trim().toLowerCase();
    Ingredient? hit;
    for (final ing in widget.ingredientStore.ingredients) {
      if (ing.name.trim().toLowerCase() == t) {
        hit = ing;
        break;
      }
    }
    if (hit == null) return const _TagInfo(key: 'Other', label: 'Other');

    final tag = hit.tagOrNull;
    if (tag == null) return const _TagInfo(key: 'Other', label: 'Other');

    final label = '${tag.emoji} ${tag.name}'.trim();
    return _TagInfo(key: label, label: label);
  }

  List<GroceryListItem> _itemsForOpenListFiltered() {
    final l = _openList;
    if (l == null) return const <GroceryListItem>[];

    final q = _itemSearchCtrl.text.trim().toLowerCase();

    final items = l.items.toList();
    if (q.isEmpty) return items;

    return items.where((it) => it.ingredientName.toLowerCase().contains(q)).toList();
  }

  List<_TagSection> _buildSections(List<GroceryListItem> items) {
    final map = <String, List<GroceryListItem>>{};
    final labels = <String, String>{};

    for (final it in items) {
      late final _TagInfo tag;

      if (it.tagName.trim().isNotEmpty) {
        final name = it.tagName.trim();
        final key = '${it.tagIsCustom ? 1 : 0}:${name.toLowerCase()}';
        final label = '${it.tagEmoji} $name'.trim();
        tag = _TagInfo(key: key, label: label.isEmpty ? name : label);
      } else {
        tag = _tagForIngredientName(it.ingredientName);
      }

      map.putIfAbsent(tag.key, () => <GroceryListItem>[]).add(it);
      labels[tag.key] = tag.label;
    }


    final keys = map.keys.toList()
      ..sort((a, b) {
        if (a == 'Other') return 1;
        if (b == 'Other') return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    final sections = <_TagSection>[];
    for (final k in keys) {
      final list = map[k]!..sort((a, b) => a.ingredientName.toLowerCase().compareTo(b.ingredientName.toLowerCase()));
      sections.add(_TagSection(tagKey: k, tagLabel: labels[k] ?? k, items: list));
    }
    return sections;
  }

  Future<String?> _promptText({
    required String title,
    required String label,
    String? hint,
    String? initial,
  }) async {
    final ctrl = TextEditingController(text: initial ?? '');
    final res = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.of(ctx).pop(ctrl.text),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text), child: const Text('OK')),
        ],
      ),
    );
    return res?.trim();
  }

  Future<void> _openTemplatesSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx2, setLocal) {
            final q = _templateQuery.trim().toLowerCase();
            final templates = widget.store.templates.where((t) {
              if (q.isEmpty) return true;
              return t.name.toLowerCase().contains(q);
            }).toList();

            return SafeArea(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: MediaQuery.of(ctx2).viewInsets.bottom),
                child: DraggableScrollableSheet(
                  expand: false,
                  initialChildSize: 0.75,
                  minChildSize: 0.40,
                  maxChildSize: 0.95,
                  builder: (context, scrollCtrl) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Templates',
                                  style: Theme.of(ctx2).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Create template from an active list',
                                icon: const Icon(Icons.bookmark_add_outlined),
                                onPressed: () async {
                                  final activeLists = widget.store.active;

                                  if (activeLists.isEmpty) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('No active lists to save as a template.')),
                                      );
                                    }
                                    return;
                                  }

                                  final pickedList = await showModalBottomSheet<GroceryList>(
                                    context: context,
                                    isScrollControlled: true,
                                    showDragHandle: true,
                                    builder: (pickCtx) {
                                      return SafeArea(
                                        child: DraggableScrollableSheet(
                                          expand: false,
                                          initialChildSize: 0.75,
                                          minChildSize: 0.40,
                                          maxChildSize: 0.95,
                                          builder: (_, scrollCtrl2) {
                                            return Padding(
                                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          'Create template from…',
                                                          style: Theme.of(pickCtx).textTheme.titleLarge?.copyWith(
                                                            fontWeight: FontWeight.w800,
                                                            color: Colors.black87,
                                                          ),
                                                        ),
                                                      ),
                                                      IconButton(
                                                        tooltip: 'Close',
                                                        icon: const Icon(Icons.close),
                                                        onPressed: () => Navigator.of(pickCtx).pop(null),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Expanded(
                                                    child: Card(
                                                      clipBehavior: Clip.antiAlias,
                                                      child: ListView.separated(
                                                        controller: scrollCtrl2,
                                                        itemCount: activeLists.length,
                                                        separatorBuilder: (_, __) => const Divider(height: 1),
                                                        itemBuilder: (_, i) {
                                                          final l = activeLists[i];
                                                          return ListTile(
                                                            title: Text(l.name, overflow: TextOverflow.ellipsis),
                                                            subtitle: Text('${l.items.length} items • Created: ${_fmtDate(l.createdAt)}'),
                                                            onTap: () => Navigator.of(pickCtx).pop(l),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    },
                                  );

                                  if (!mounted || pickedList == null) return;

                                  final templateName = await _promptText(
                                    title: 'Save as template',
                                    label: 'Template name',
                                    initial: '${pickedList.name} Template',
                                  );
                                  if (templateName == null || templateName.trim().isEmpty) return;

                                  widget.store.createTemplateFromList(
                                    pickedList,
                                    templateName: templateName.trim(),
                                  );

                                  setState(() {});
                                  setLocal(() {});

                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Template saved: "${templateName.trim()}" ✅')),
                                    );
                                  }
                                },

                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          TextField(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Search templates…',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onChanged: (v) {
                              setState(() => _templateQuery = v);
                              setLocal(() {});
                            },
                          ),

                          const SizedBox(height: 12),

                          Expanded(
                            child: templates.isEmpty
                                ? const Center(child: Text('No templates.'))
                                : ListView.separated(
                              controller: scrollCtrl, // ✅ key piece
                              itemCount: templates.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (_, i) {
                                final t = templates[i];
                                return ListTile(
                                  title: Text(t.name, overflow: TextOverflow.ellipsis),
                                  subtitle: Text('${t.items.length} items'),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'delete') {
                                        widget.store.deleteTemplate(t.id);
                                        setState(() {});
                                        setLocal(() {});
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                                    ],
                                  ),
                                  onTap: () async {
                                    final nameOverride = await _promptText(
                                      title: 'Create list from template',
                                      label: 'List name',
                                      initial: t.name,
                                    );
                                    if (nameOverride == null) return;

                                    final list = widget.store.createListFromTemplate(t, nameOverride: nameOverride);
                                    setState(() => _openListId = list.id);
                                    if (mounted) Navigator.of(ctx2).pop();
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );


          },
        );
      },
    );
  }

  Widget _sectionHeader({
    required String title,
    required IconData icon,
    required Color barColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: barColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildListOverview() {
    final active = widget.store.active;
    final archived = widget.store.archived;

    return Card(
      elevation: 0,
      color: const Color(0xFFF3F5F7),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0x1F000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _showArchive ? 'Archive' : 'Grocery Lists',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Templates',
                  icon: const Icon(Icons.bookmarks_outlined),
                  onPressed: _openTemplatesSheet,
                ),
                IconButton(
                  tooltip: _showArchive ? 'Back to active' : 'View archive',
                  icon: Icon(_showArchive ? Icons.arrow_back : Icons.archive_outlined),
                  onPressed: () => setState(() => _showArchive = !_showArchive),
                ),
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: () async {
                    final name = await _promptText(
                      title: 'New list',
                      label: 'List name',
                      initial: 'New List',
                    );
                    if (name == null) return;
                    final list = widget.store.createNewList(name: name);
                    setState(() => _openListId = list.id);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Expanded(
              child: _showArchive
                  ? Column(
                children: [
                  _sectionHeader(
                    title: 'Archive',
                    icon: Icons.history,
                    barColor: Colors.purple.shade200,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: archived.isEmpty
                          ? const Center(child: Text('No archived lists yet.'))
                          : ListView.separated(
                        itemCount: archived.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final l = archived[i];
                          return ListTile(
                            title: Text(l.name, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              'Completed: ${l.completedAt == null ? '—' : _fmtDate(l.completedAt!)} • ${l.items.length} items',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Restore',
                                  icon: const Icon(Icons.restore),
                                  onPressed: () {
                                    widget.store.reactivate(l.id);
                                    setState(() {});
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete archived list?'),
                                        content: Text('Delete "${l.name}"? This cannot be undone.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                          FilledButton.tonal(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      widget.store.deleteArchived(l.id);
                                      setState(() {});
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () => setState(() => _openListId = l.id),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              )
                  : Column(
                children: [
                  _sectionHeader(
                    title: 'Active',
                    icon: Icons.playlist_add_check,
                    barColor: Colors.green.shade200,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: active.isEmpty
                          ? const Center(child: Text('No active lists. Tap New to create one.'))
                          : ListView.separated(
                        itemCount: active.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final l = active[i];
                          return ListTile(
                            title: Text(l.name, overflow: TextOverflow.ellipsis),
                            subtitle: Text('Created: ${_fmtDate(l.createdAt)} • ${l.items.length} items'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Done',
                                  icon: const Icon(Icons.check_circle_outline),
                                  onPressed: () {
                                    widget.store.markDone(l.id);
                                    setState(() {});
                                  },
                                ),
                                IconButton(
                                  tooltip: 'Delete',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete list?'),
                                        content: Text('Delete "${l.name}"? This cannot be undone.'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                          FilledButton.tonal(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                                        ],
                                      ),
                                    );
                                    if (ok == true) {
                                      widget.store.deleteActive(l.id);
                                      setState(() {});
                                    }
                                  },
                                ),
                              ],
                            ),
                            onTap: () => setState(() => _openListId = l.id),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (archived.isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.archive_outlined, color: Colors.black54),
                        const SizedBox(width: 8),
                        Text(
                          '${archived.length} archived list${archived.length == 1 ? '' : 's'}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() => _showArchive = true),
                          child: const Text('View'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildListDetail(GroceryList list) {
    final items = _itemsForOpenListFiltered();
    final sections = _buildSections(items);

    final title = list.name.trim().isEmpty ? 'Untitled' : list.name.trim();

    final checkedCount = list.items.where((x) => x.checked).length;
    final total = list.items.length;

    return Card(
      elevation: 0,
      color: const Color(0xFFF3F5F7),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0x1F000000)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => setState(() {
                    _openListId = null;
                    _itemSearchCtrl.clear();
                  }),
                ),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Rename',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    final name = await _promptText(
                      title: 'Rename list',
                      label: 'Name',
                      initial: title,
                    );
                    if (name == null || name.isEmpty) return;
                    widget.store.renameList(list.id, name);
                    setState(() {});
                  },
                ),
                if (!_openListIsArchived)
                  IconButton(
                    tooltip: 'Mark done (move to archive)',
                    icon: const Icon(Icons.check_circle_outline),
                    onPressed: () {
                      widget.store.markDone(list.id);
                      setState(() => _openListId = null);
                    },
                  ),
                if (_openListIsArchived)
                  IconButton(
                    tooltip: 'Restore to active',
                    icon: const Icon(Icons.restore),
                    onPressed: () {
                      widget.store.reactivate(list.id);
                      setState(() {});
                    },
                  ),
              ],
            ),

            const SizedBox(height: 6),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$checkedCount / $total checked',
                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
              ),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: _itemSearchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Search items in this list',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _itemSearchCtrl.text.trim().isEmpty
                    ? null
                    : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _itemSearchCtrl.clear();
                    setState(() {});
                  },
                ),
              ),
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0x1F000000)),
            const SizedBox(height: 6),

            Expanded(
              child: sections.isEmpty
                  ? Center(
                child: Text(
                  list.items.isEmpty ? 'No items yet. Tap + to add one.' : 'No matches.',
                  style: const TextStyle(color: Colors.black54),
                ),
              )
                  : ListView.builder(
                itemCount: sections.length,
                itemBuilder: (ctx, si) {
                  final s = sections[si];
                  final allChecked = s.items.isNotEmpty && s.items.every((x) => x.checked);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0x14000000)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    s.tagLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                if (!_openListIsArchived)
                                  TextButton.icon(
                                    onPressed: () {
                                      for (final it in s.items) {
                                        widget.store.setChecked(list.id, it.id, !allChecked);
                                      }
                                      setState(() {});
                                    },
                                    icon: Icon(allChecked ? Icons.check_box : Icons.check_box_outline_blank),
                                    label: Text(allChecked ? 'Uncheck all' : 'Check all'),
                                  ),
                              ],
                            ),
                            const Divider(height: 10),
                            for (final it in s.items) _buildItemRow(list, it),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(GroceryList list, GroceryListItem it) {
    final qty = it.quantity.trim();
    final unit = it.unit.trim();
    final qtyLabel = [if (qty.isNotEmpty) qty, if (unit.isNotEmpty) unit].join(' ');

    return InkWell(
      onTap: _openListIsArchived ? null : () => _openItemEditor(existing: it),
      onLongPress: _openListIsArchived ? null : () => _confirmDelete(it),
      onSecondaryTap: _openListIsArchived ? null : () => _confirmDelete(it),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: Checkbox(
                value: it.checked,
                onChanged: _openListIsArchived
                    ? null
                    : (v) {
                  widget.store.setChecked(list.id, it.id, v ?? false);
                  setState(() {});
                },
              ),
            ),
            Expanded(
              flex: 4,
              child: Text(
                it.ingredientName.trim().isEmpty ? 'Untitled' : it.ingredientName,
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                  decoration: it.checked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                qtyLabel.isEmpty ? '—' : qtyLabel,
                style: TextStyle(
                  color: Colors.black54,
                  decoration: it.checked ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(GroceryListItem it) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Delete "${it.ingredientName}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (ok == true) {
      final l = _openList;
      if (l == null) return;
      widget.store.deleteItem(l.id, it.id);
      setState(() {});
    }
  }

  Future<void> _openItemEditor({GroceryListItem? existing}) async {
    final l = _openList;
    if (l == null) return;

    final result = await showModalBottomSheet<_GroceryEditorResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _GroceryItemEditorSheet(
        ingredientStore: widget.ingredientStore,
        measurementStore: widget.measurementStore,
        existing: existing,
      ),
    );

    if (!mounted || result == null) return;

    if (result.delete == true && existing != null) {
      widget.store.deleteItem(l.id, existing.id);
      setState(() {});
      return;
    }

    final item = result.item;
    if (item == null) return;

    widget.store.upsertItem(l.id, item);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final open = _openList;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: open == null ? _buildListOverview() : _buildListDetail(open),
      ),
    );
  }
}

class _GroceryEditorResult {
  final GroceryListItem? item;
  final bool? delete;
  const _GroceryEditorResult({this.item, this.delete});
}

class _GroceryItemEditorSheet extends StatefulWidget {
  const _GroceryItemEditorSheet({
    required this.ingredientStore,
    required this.measurementStore,
    this.existing,
  });

  final IngredientStore ingredientStore;
  final MeasurementStore measurementStore;
  final GroceryListItem? existing;

  @override
  State<_GroceryItemEditorSheet> createState() => _GroceryItemEditorSheetState();
}

class _GroceryItemEditorSheetState extends State<_GroceryItemEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _unitCtrl;
  IngredientTag? _tag;

  String? _store;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtrl = TextEditingController(text: ex?.ingredientName ?? '');
    _qtyCtrl = TextEditingController(text: ex?.quantity ?? '');
    _unitCtrl = TextEditingController(text: ex?.unit ?? '');
    _checked = ex?.checked ?? false;

    if (ex != null) {
      if (ex.tagName.isNotEmpty) {
        _tag = IngredientTag(
          name: ex.tagName,
          emoji: ex.tagEmoji,
          isCustom: ex.tagIsCustom,
        );
      }
      if (ex.store.isNotEmpty) {
        _store = ex.store;
      } else {
        final ing = _findIngredient(ex.ingredientName);
        if (ing != null && ing.storeTag.trim().isNotEmpty) _store = ing.storeTag.trim();
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  Ingredient? _findIngredient(String name) {
    final t = name.trim().toLowerCase();
    for (final ing in widget.ingredientStore.ingredients) {
      if (ing.name.trim().toLowerCase() == t) return ing;
    }
    return null;
  }

  List<String> _ingredientNamesSorted() {
    return widget.ingredientStore.ingredients
        .map((i) => i.name)
        .where((s) => s.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  List<String> _unitsSorted() {
    return widget.measurementStore.measurements
        .map((m) => m.unit)
        .where((s) => s.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  Future<void> _pickStore() async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => _StorePickerSheet(store: widget.ingredientStore),
    );
    if (!mounted) return;
    setState(() => _store = picked);
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final id = widget.existing?.id ?? GroceryIds.uid();
    final item = GroceryListItem(
      id: id,
      ingredientName: name,
      quantity: _qtyCtrl.text.trim(),
      unit: _unitCtrl.text.trim(),
      store: (_store ?? '').trim(),
      checked: _checked,
      tagName: _tag?.name ?? '',
      tagEmoji: _tag?.emoji ?? '',
      tagIsCustom: _tag?.isCustom ?? false,
    );

    Navigator.of(context).pop(_GroceryEditorResult(item: item));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final canSave = _nameCtrl.text.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.existing == null ? 'Add Item' : 'Edit Item',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.existing != null)
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => Navigator.of(context).pop(const _GroceryEditorResult(delete: true)),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            Autocomplete<String>(
              initialValue: TextEditingValue(text: _nameCtrl.text),
              optionsBuilder: (TextEditingValue tev) {
                final q = tev.text.trim();
                final all = _ingredientNamesSorted(); // Fix: use ingredients, not units
                if (all.isEmpty) return const Iterable<String>.empty();
                if (q.isEmpty) return all.take(10);
                return fuzzySearch<String>(all, q, 10, 0.25, stringify: (s) => s);
              },
              onSelected: (String selection) {
                _nameCtrl.text = selection;
                final match = _findIngredient(selection) ?? Ingredient(
                  name: selection, unit: '', tagName: '', tagEmoji: '', tagIsCustom: false, storeTag: '',
                );

                setState(() {
                  if (_unitCtrl.text.trim().isEmpty) _unitCtrl.text = match.unit;
                  if ((_store == null || _store!.isEmpty) && match.hasStore) _store = match.storeTag;
                  if (_tag == null && match.hasTag) _tag = match.tagOrNull;
                });
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                if (controller.text != _nameCtrl.text) {
                  controller.text = _nameCtrl.text;
                }
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (v) => setState(() => _nameCtrl.text = v),
                  decoration: const InputDecoration(
                    labelText: 'Ingredient Name',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _qtyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Qty',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Autocomplete<String>(
                    initialValue: TextEditingValue(text: _unitCtrl.text),
                    optionsBuilder: (TextEditingValue tev) {
                      final q = tev.text.trim();
                      final all = _unitsSorted();
                      if (all.isEmpty) return const Iterable<String>.empty();
                      if (q.isEmpty) return all.take(10);
                      return fuzzySearch<String>(all, q, 10, 0.25, stringify: (s) => s);
                    },
                    onSelected: (sel) => setState(() => _unitCtrl.text = sel),
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      if (controller.text != _unitCtrl.text) controller.text = _unitCtrl.text;
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        onChanged: (v) => setState(() => _unitCtrl.text = v),
                        decoration: const InputDecoration(
                          labelText: 'Unit',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _tag == null
                      ? const Text('Tag: None', style: TextStyle(color: Colors.black54))
                      : Row(
                    children: [
                      const Text('Tag: ', style: TextStyle(color: Colors.black54)),
                      _TagPill(tag: _tag!),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final picked = await showModalBottomSheet<IngredientTag?>(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: true,
                      builder: (ctx) => _TagPickerSheet(store: widget.ingredientStore),
                    );
                    if (picked != null) setState(() => _tag = picked);
                  },
                  icon: const Icon(Icons.label_outline),
                  label: const Text('Choose'),
                ),
                if (_tag != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _tag = null),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: (_store == null || _store!.trim().isEmpty)
                      ? const Text('Store: None', style: TextStyle(color: Colors.black54))
                      : Row(
                    children: [
                      const Text('Store: ', style: TextStyle(color: Colors.black54)),
                      _StorePill(text: _store!),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickStore,
                  icon: const Icon(Icons.store_outlined),
                  label: const Text('Choose'),
                ),
                if (_store != null && _store!.trim().isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _store = null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSave ? _save : null,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeQuickPickSheet extends StatefulWidget {
  const _RecipeQuickPickSheet({required this.store});

  final RecipeStore store;

  @override
  State<_RecipeQuickPickSheet> createState() => _RecipeQuickPickSheetState();
}

class _RecipeQuickPickSheetState extends State<_RecipeQuickPickSheet> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Recipe> _filtered() {
    final q = _searchCtrl.text.trim();

    var items = widget.store.recipes.toList()
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    if (q.isEmpty) return items;

    final hits = fuzzySearch<Recipe>(
      items,
      q,
      250,
      0.18,
      stringify: (r) => '${r.title} ${r.description}',
    );
    return hits.toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pick a recipe',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Search recipes',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: _searchCtrl.text.trim().isEmpty
                    ? null
                    : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: list.isEmpty
                  ? const Center(child: Text('No recipes found'))
                  : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final r = list[i];
                  final desc = r.description.trim();
                  return ListTile(
                    title: Text(r.title),
                    subtitle: desc.isEmpty
                        ? null
                        : Text(desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                    onTap: () => Navigator.of(context).pop(r),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeIngredientChecklistSheet extends StatefulWidget {
  const _RecipeIngredientChecklistSheet({required this.recipe});

  final Recipe recipe;

  @override
  State<_RecipeIngredientChecklistSheet> createState() => _RecipeIngredientChecklistSheetState();
}

class _RecipeIngredientChecklistSheetState extends State<_RecipeIngredientChecklistSheet> {
  late final List<RecipeIngredient> _flat;
  late final List<bool> _checked;

  @override
  void initState() {
    super.initState();

    final out = <RecipeIngredient>[];
    for (final sec in widget.recipe.ingredientSections) {
      out.addAll(sec.ingredients);
    }

    _flat = out;
    _checked = List<bool>.filled(_flat.length, true);
  }

  String _fmtLine(RecipeIngredient i) {
    final qty = i.quantity.trim();
    final unit = i.unit.trim();
    if (qty.isEmpty && unit.isEmpty) return '';
    if (qty.isEmpty) return unit;
    if (unit.isEmpty) return qty;
    return '$qty $unit';
  }

  @override
  Widget build(BuildContext context) {
    final canAdd = _checked.any((v) => v);

    final sections = widget.recipe.ingredientSections;

    int runningIndex = 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.checklist),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Add ingredients: ${widget.recipe.title}',
                    style: Theme.of(context).textTheme.titleLarge,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _flat.isEmpty
                  ? const Center(child: Text('This recipe has no ingredients.'))
                  : ListView(
                children: [
                  for (final sec in sections) ...[
                    if (sec.sectionTitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        sec.sectionTitle.trim(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                    ],
                    for (final ing in sec.ingredients) ...[
                      Builder(builder: (_) {
                        final idx = runningIndex++;
                        final sub = _fmtLine(ing);
                        return CheckboxListTile(
                          value: _checked[idx],
                          onChanged: (v) => setState(() => _checked[idx] = v ?? false),
                          title: Text(ing.name),
                          subtitle: sub.isEmpty ? null : Text(sub),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    for (var i = 0; i < _checked.length; i++) {
                      _checked[i] = false;
                    }
                  }),
                  child: const Text('None'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() {
                    for (var i = 0; i < _checked.length; i++) {
                      _checked[i] = true;
                    }
                  }),
                  child: const Text('All'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: canAdd
                      ? () {
                    final selected = <RecipeIngredient>[];
                    for (var i = 0; i < _flat.length; i++) {
                      if (_checked[i]) selected.add(_flat[i]);
                    }
                    Navigator.of(context).pop(selected);
                  }
                      : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagInfo {
  final String key;
  final String label;
  const _TagInfo({required this.key, required this.label});
}

class _TagSection {
  final String tagKey;
  final String tagLabel;
  final List<GroceryListItem> items;
  const _TagSection({required this.tagKey, required this.tagLabel, required this.items});
}

class _RecipesPanel extends StatefulWidget {
  const _RecipesPanel({
    super.key,
    required this.store,
    required this.ingredientStore,
    required this.measurementStore,
  });

  final RecipeStore store;
  final IngredientStore ingredientStore;
  final MeasurementStore measurementStore;

  @override
  State<_RecipesPanel> createState() => _RecipesPanelState();
}

class _RecipesPanelState extends State<_RecipesPanel> {
  final TextEditingController _searchCtrl = TextEditingController();

  final Set<String> _filterTagKeys = <String>{}; // multi-select by RecipeTag.key
  _RecipeSortMode _sortMode = _RecipeSortMode.alpha;

  bool _favOnly = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void openAddRecipe() {
    _openRecipeViewerEditor();
  }

  Recipe? _findCurrentByTitle(String title) {
    final t = title.trim().toLowerCase();
    for (final r in widget.store.recipes) {
      if (r.title.trim().toLowerCase() == t) return r;
    }
    return null;
  }

  List<String> _ingredientNamesSorted() {
    final names = widget.ingredientStore.ingredients
        .map((i) => i.name)
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  List<String> _unitsSorted() {
    final units = widget.measurementStore.measurements
        .map((m) => m.unit)
        .where((s) => s.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return units;
  }

  List<Recipe> _filteredRecipes() {
    final query = _searchCtrl.text.trim();

    var items = widget.store.recipes.toList();

    if (_favOnly) {
      items = items.where((r) => r.isFavorite).toList();
    }

    if (_filterTagKeys.isNotEmpty) {
      items = items.where((r) {
        final keys = r.tags.map((t) => t.key).toSet();
        for (final k in _filterTagKeys) {
          if (!keys.contains(k)) return false;
        }
        return true;
      }).toList();
    }

    if (query.isNotEmpty) {
      final hits = fuzzySearch<Recipe>(
        items,
        query,
        250,
        0.18,
        stringify: (r) => '${r.title} ${r.description}',
      );
      items = hits.toList();
    }

    switch (_sortMode) {
      case _RecipeSortMode.alpha:
        items.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case _RecipeSortMode.scoreHigh:
        items.sort((a, b) {
          final s = b.score10.compareTo(a.score10);
          if (s != 0) return s;
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
        break;
    }

    return items;
  }

  Future<void> _openRecipeViewerEditor({Recipe? existing}) async {
    final prevTitle = existing?.title ?? '';

    final result = await showModalBottomSheet<_RecipeEditorResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: _RecipeViewerEditorSheet(
            existing: existing,
            store: widget.store,
            ingredientNames: _ingredientNamesSorted(),
            unitSuggestions: _unitsSorted(),
          ),
        );
      },
    );

    if (!mounted || result == null) return;

    if (result.delete == true && existing != null) {
      widget.store.deleteRecipeByTitle(existing.title);
      setState(() {});
      return;
    }

    final r = result.recipe;
    if (r == null) return;

    if (result.previousTitle != null &&
        result.previousTitle!.trim().isNotEmpty &&
        result.previousTitle!.trim().toLowerCase() != r.title.trim().toLowerCase()) {
      widget.store.deleteRecipeByTitle(result.previousTitle!);
    }

    if (!result.favoriteTouched) {
      final current =
          _findCurrentByTitle(result.previousTitle ?? prevTitle) ?? _findCurrentByTitle(r.title);
      if (current != null) {
        r.isFavorite = current.isFavorite;
      }
    }

    widget.store.upsertRecipe(r);
    setState(() {});
  }

  Future<void> _confirmDeleteRecipe(Recipe r) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete recipe?'),
        content: Text('Delete "${r.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (shouldDelete == true) {
      widget.store.deleteRecipeByTitle(r.title);
      if (mounted) setState(() {});
    }
  }

  void _toggleFavorite(Recipe r) {
    final current = _findCurrentByTitle(r.title) ?? r;
    current.isFavorite = !current.isFavorite;
    widget.store.upsertRecipe(current);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredRecipes();
    final allTags = widget.store.allTagsSorted();
    final selectedTags = allTags.where((t) => _filterTagKeys.contains(t.key)).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: Card(
          elevation: 0,
          color: const Color(0xFFF3F5F7),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x1F000000)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recipes',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black87),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: openAddRecipe,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Recipe'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Search recipes',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchCtrl.text.trim().isEmpty
                        ? null
                        : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _FilterDropdownButton(
                        label: 'Tag filter',
                        valueWidget: _filterTagKeys.isEmpty
                            ? const Text(
                          'All tags',
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                        )
                            : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...selectedTags.take(1).map((t) => _RecipeTagPill(tag: t)),
                            if (selectedTags.length > 1)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE7EAEE),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: const Color(0x1F000000)),
                                ),
                                child: Text(
                                  '+${selectedTags.length - 1}',
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onPressed: () async {
                          final pickedKeys = await showModalBottomSheet<Set<String>?>(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            builder: (ctx) => _RecipeTagMultiFilterPickerSheet(
                              store: widget.store,
                              selectedKeys: _filterTagKeys,
                            ),
                          );
                          if (!mounted) return;
                          if (pickedKeys != null) {
                            setState(() {
                              _filterTagKeys
                                ..clear()
                                ..addAll(pickedKeys);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _FilterDropdownButton(
                        label: 'Sort',
                        valueWidget: Text(
                          _sortMode == _RecipeSortMode.alpha ? 'A-Z' : 'Score',
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                        ),
                        onPressed: () async {
                          final picked = await showModalBottomSheet<_RecipeSortMode?>(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            builder: (ctx) => _RecipeSortPickerSheet(selected: _sortMode),
                          );
                          if (!mounted) return;
                          if (picked != null) setState(() => _sortMode = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    IconButton(
                      tooltip: _favOnly ? 'Showing favorites only' : 'Show favorites only',
                      icon: Icon(
                        _favOnly ? Icons.star : Icons.star_border,
                        color: const Color(0xFFFFB300),
                      ),
                      onPressed: () => setState(() => _favOnly = !_favOnly),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0x1F000000)),
                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 6,
                        child: Text('Recipe', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                      ),
                      Expanded(
                        flex: 6,
                        child: Text('Rating', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                      ),

                      SizedBox(width: 44),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                Expanded(
                  child: list.isEmpty
                      ? Center(
                    child: Text(
                      widget.store.recipes.isEmpty ? 'No recipes yet. Tap + to add one.' : 'No matches.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                  )
                      : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x1F000000)),
                    itemBuilder: (context, i) {
                      final r = list[i];

                      return InkWell(
                        onTap: () => _openRecipeViewerEditor(existing: r),
                        onLongPress: () => _confirmDeleteRecipe(r),
                        onSecondaryTap: () => _confirmDeleteRecipe(r),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.title.trim().isEmpty ? 'Untitled' : r.title,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (r.description.trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        r.description.trim(),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: Colors.black54),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _StarDisplay(score10: r.score10),
                                ),
                              ),
                              SizedBox(
                                width: 44,
                                child: IconButton(
                                  tooltip: r.isFavorite ? 'Unfavorite' : 'Favorite',
                                  icon: Icon(
                                    r.isFavorite ? Icons.star : Icons.star_border,
                                    color: const Color(0xFFFFB300),
                                  ),
                                  onPressed: () => _toggleFavorite(r),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipeSortPickerSheet extends StatelessWidget {
  const _RecipeSortPickerSheet({required this.selected});
  final _RecipeSortMode selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sort Recipes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.sort_by_alpha, color: Colors.black54),
              title: const Text('Alphabetical', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
              trailing: selected == _RecipeSortMode.alpha ? const Icon(Icons.check, color: Colors.black87) : null,
              onTap: () => Navigator.of(context).pop(_RecipeSortMode.alpha),
            ),
            const Divider(height: 1, color: Color(0x1F000000)),
            ListTile(
              leading: const Icon(Icons.leaderboard_outlined, color: Colors.black54),
              title: const Text('By score', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
              subtitle: const Text('Highest first', style: TextStyle(color: Colors.black54)),
              trailing: selected == _RecipeSortMode.scoreHigh ? const Icon(Icons.check, color: Colors.black87) : null,
              onTap: () => Navigator.of(context).pop(_RecipeSortMode.scoreHigh),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecipeTagPill extends StatelessWidget {
  const _RecipeTagPill({required this.tag});
  final RecipeTag tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EAEE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x1F000000)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tag.emoji.isEmpty ? '🏷️' : tag.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              tag.name,
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StarDisplay extends StatelessWidget {
  const _StarDisplay({required this.score10});
  final int score10;

  @override
  Widget build(BuildContext context) {
    final s = score10.clamp(0, 10);
    final full = s ~/ 2;
    final half = (s % 2) == 1;

    final icons = <Widget>[];
    for (int i = 0; i < 5; i++) {
      IconData data;
      if (i < full) {
        data = Icons.star;
      } else if (i == full && half) {
        data = Icons.star_half;
      } else {
        data = Icons.star_border;
      }
      icons.add(Icon(data, size: 18, color: const Color(0xFFFFB300)));
    }

    return Row(mainAxisSize: MainAxisSize.min, children: icons);
  }
}

class _RecipeEditorResult {
  final Recipe? recipe;
  final bool? delete;
  final String? previousTitle;

  final bool favoriteTouched;

  const _RecipeEditorResult({
    this.recipe,
    this.delete,
    this.previousTitle,
    this.favoriteTouched = false,
  });
}

class _RecipeViewerEditorSheet extends StatefulWidget {
  const _RecipeViewerEditorSheet({
    required this.store,
    required this.ingredientNames,
    required this.unitSuggestions,
    this.existing,
  });

  final RecipeStore store;
  final Recipe? existing;
  final List<String> ingredientNames;
  final List<String> unitSuggestions;

  @override
  State<_RecipeViewerEditorSheet> createState() => _RecipeViewerEditorSheetState();
}

class _RecipeViewerEditorSheetState extends State<_RecipeViewerEditorSheet> {
  bool _editing = false;

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  late List<RecipeTag> _tags;
  late bool _favorite;
  late int _score10;

  late List<IngredientSection> _sections;
  late List<RecipeStep> _steps;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _titleCtrl = TextEditingController(text: ex?.title ?? '');
    _descCtrl = TextEditingController(text: ex?.description ?? '');

    _tags = List<RecipeTag>.from(ex?.tags ?? const []);
    _favorite = ex?.isFavorite ?? false;
    _score10 = (ex?.score10 ?? 0).clamp(0, 10);

    _sections = (ex?.ingredientSections ?? const [])
        .map((s) => IngredientSection(sectionTitle: s.sectionTitle, ingredients: s.ingredients.map((i) {
      return RecipeIngredient(name: i.name, quantity: i.quantity, unit: i.unit);
    }).toList()))
        .toList();

    _steps = (ex?.stepTitles ?? const [])
        .map((s) => RecipeStep(stepTitle: s.stepTitle, description: s.description))
        .toList();

    if (ex == null) {
      _editing = true;
      _sections = [
        IngredientSection(sectionTitle: 'Ingredients', ingredients: []),
      ];
      _steps = [
        RecipeStep(stepTitle: 'Step 1', description: ''),
      ];
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;
  bool get _canSave => _titleCtrl.text.trim().isNotEmpty;

  void _delete() {
    Navigator.of(context).pop(const _RecipeEditorResult(delete: true));
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    final cleanTags = <RecipeTag>[];
    final seen = <String>{};
    for (final t in _tags) {
      if (t.name.trim().isEmpty) continue;
      if (seen.add(t.key)) cleanTags.add(t);
    }

    final cleanSections = _sections.map((s) {
      final secTitle = s.sectionTitle.trim();
      final ings = s.ingredients
          .map((i) => RecipeIngredient(
        name: i.name.trim(),
        quantity: i.quantity.trim(),
        unit: i.unit.trim(),
      ))
          .where((i) => i.name.trim().isNotEmpty)
          .toList();
      return IngredientSection(sectionTitle: secTitle, ingredients: ings);
    }).where((s) {
      return s.sectionTitle.trim().isNotEmpty || s.ingredients.isNotEmpty;
    }).toList();

    final cleanSteps = _steps
        .map((s) => RecipeStep(stepTitle: s.stepTitle.trim(), description: s.description.trim()))
        .where((s) => s.stepTitle.trim().isNotEmpty || s.description.trim().isNotEmpty)
        .toList();

    final r = Recipe(
      title: title,
      description: desc,
      ingredientSections: cleanSections,
      stepTitles: cleanSteps,
      tags: cleanTags,
      isFavorite: _favorite,
      score10: _score10.clamp(0, 10),
    );

    Navigator.of(context).pop(
      _RecipeEditorResult(
        recipe: r,
        previousTitle: widget.existing?.title,
      ),
    );
  }

  Future<void> _pickTags() async {
    final selectedKeys = _tags.map((t) => t.key).toSet();
    final picked = await showModalBottomSheet<Set<String>?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _RecipeTagMultiPickerSheet(
        store: widget.store,
        selectedKeys: selectedKeys,
      ),
    );

    if (!mounted || picked == null) return;

    final all = widget.store.allTagsSorted();
    final newTags = <RecipeTag>[];
    for (final t in all) {
      if (picked.contains(t.key)) newTags.add(t);
    }

    final missingKeys = picked.difference(all.map((t) => t.key).toSet());
    if (missingKeys.isNotEmpty) {
      for (final old in _tags) {
        if (missingKeys.contains(old.key)) newTags.add(old);
      }
    }

    setState(() => _tags = newTags);
  }

  void _addSection() {
    setState(() {
      _sections.add(IngredientSection(sectionTitle: 'Section ${_sections.length + 1}', ingredients: []));
    });
  }

  void _deleteSection(int idx) {
    setState(() {
      _sections.removeAt(idx);
      if (_sections.isEmpty) {
        _sections.add(IngredientSection(sectionTitle: 'Ingredients', ingredients: []));
      }
    });
  }

  void _addIngredientLine(int sectionIndex) {
    setState(() {
      _sections[sectionIndex].ingredients.add(RecipeIngredient(name: '', quantity: '', unit: ''));
    });
  }

  void _deleteIngredientLine(int sectionIndex, int ingIndex) {
    setState(() {
      _sections[sectionIndex].ingredients.removeAt(ingIndex);
    });
  }

  void _addStep() {
    setState(() {
      _steps.add(RecipeStep(stepTitle: 'Step ${_steps.length + 1}', description: ''));
    });
  }

  void _deleteStep(int idx) {
    setState(() {
      _steps.removeAt(idx);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final title = _titleCtrl.text.trim().isEmpty ? 'Untitled' : _titleCtrl.text.trim();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _editing ? (_isEdit ? 'Edit Recipe' : 'New Recipe') : 'Recipe',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                IconButton(
                  tooltip: _editing ? 'Preview' : 'Edit',
                  icon: Icon(_editing ? Icons.visibility_outlined : Icons.edit_outlined),
                  onPressed: () => setState(() => _editing = !_editing),
                ),
                if (_isEdit)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (!_editing)
              Expanded(
                child: _RecipeFormattedView(
                  title: title,
                  description: _descCtrl.text.trim(),
                  tags: _tags,
                  score10: _score10,
                  sections: _sections,
                  steps: _steps,
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      TextField(
                        controller: _titleCtrl,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _descCtrl,
                        minLines: 2,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Rating',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _StarPicker(
                            score10: _score10,
                            onChanged: (v) => setState(() => _score10 = v.clamp(0, 10)),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${(_score10 / 2).toStringAsFixed((_score10 % 2 == 0) ? 0 : 1)} / 5',
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        min: 0,
                        max: 10,
                        divisions: 10,
                        value: _score10.toDouble(),
                        onChanged: (v) => setState(() => _score10 = v.round().clamp(0, 10)),
                      ),

                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Expanded(
                            child: _tags.isEmpty
                                ? const Text('Tags: None', style: TextStyle(color: Colors.black54))
                                : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _tags.map((t) => _RecipeTagPill(tag: t)).toList(),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _pickTags,
                            icon: const Icon(Icons.label_outline),
                            label: const Text('Edit tags'),
                          ),
                          if (_tags.isNotEmpty)
                            TextButton(
                              onPressed: () => setState(() => _tags.clear()),
                              child: const Text('Clear'),
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      const Divider(height: 1, color: Color(0x1F000000)),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Ingredients',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.black87,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _addSection,
                            icon: const Icon(Icons.add),
                            label: const Text('Add section'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(_sections.length, (secIdx) {
                        final sec = _sections[secIdx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0x1F000000)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: TextEditingController(text: sec.sectionTitle)
                                          ..selection = TextSelection.collapsed(offset: sec.sectionTitle.length),
                                        onChanged: (v) => sec.sectionTitle = v,
                                        decoration: const InputDecoration(
                                          labelText: 'Section title',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      tooltip: 'Delete section',
                                      onPressed: () => _deleteSection(secIdx),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),

                                if (sec.ingredients.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 6),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('No ingredients yet.', style: TextStyle(color: Colors.black54)),
                                    ),
                                  )
                                else
                                  Column(
                                    children: List.generate(sec.ingredients.length, (ingIdx) {
                                      final ing = sec.ingredients[ingIdx];

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 4,
                                              child: Autocomplete<String>(
                                                initialValue: TextEditingValue(text: ing.name),
                                                optionsBuilder: (TextEditingValue tev) {
                                                  final q = tev.text.trim();
                                                  final all = widget.ingredientNames;
                                                  if (all.isEmpty) return const Iterable<String>.empty();
                                                  if (q.isEmpty) return all.take(10);
                                                  return fuzzySearch<String>(
                                                    all,
                                                    q,
                                                    10,
                                                    0.22,
                                                    stringify: (s) => s,
                                                  );
                                                },
                                                onSelected: (sel) => setState(() => ing.name = sel),
                                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                                  controller.text = ing.name;
                                                  controller.addListener(() => ing.name = controller.text);
                                                  return TextField(
                                                    controller: controller,
                                                    focusNode: focusNode,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Ingredient',
                                                      border: OutlineInputBorder(),
                                                      isDense: true,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              flex: 2,
                                              child: TextField(
                                                controller: TextEditingController(text: ing.quantity)
                                                  ..selection = TextSelection.collapsed(offset: ing.quantity.length),
                                                onChanged: (v) => ing.quantity = v,
                                                decoration: const InputDecoration(
                                                  labelText: 'Qty',
                                                  border: OutlineInputBorder(),
                                                  isDense: true,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              flex: 3,
                                              child: Autocomplete<String>(
                                                initialValue: TextEditingValue(text: ing.unit),
                                                optionsBuilder: (TextEditingValue tev) {
                                                  final q = tev.text.trim();
                                                  final all = widget.unitSuggestions;
                                                  if (all.isEmpty) return const Iterable<String>.empty();
                                                  if (q.isEmpty) return all.take(10);
                                                  return fuzzySearch<String>(
                                                    all,
                                                    q,
                                                    10,
                                                    0.25,
                                                    stringify: (s) => s,
                                                  );
                                                },
                                                onSelected: (sel) => setState(() => ing.unit = sel),
                                                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                                  controller.text = ing.unit;
                                                  controller.addListener(() => ing.unit = controller.text);
                                                  return TextField(
                                                    controller: controller,
                                                    focusNode: focusNode,
                                                    decoration: const InputDecoration(
                                                      labelText: 'Unit',
                                                      border: OutlineInputBorder(),
                                                      isDense: true,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            IconButton(
                                              tooltip: 'Delete ingredient',
                                              onPressed: () => _deleteIngredientLine(secIdx, ingIdx),
                                              icon: const Icon(Icons.close),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ),

                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => _addIngredientLine(secIdx),
                                    icon: const Icon(Icons.add),
                                    label: const Text('Add ingredient'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const Divider(height: 1, color: Color(0x1F000000)),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Steps',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.black87,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _addStep,
                            icon: const Icon(Icons.add),
                            label: const Text('Add step'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(_steps.length, (idx) {
                        final step = _steps[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0x1F000000)),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: TextEditingController(text: step.stepTitle)
                                          ..selection = TextSelection.collapsed(offset: step.stepTitle.length),
                                        onChanged: (v) => step.stepTitle = v,
                                        decoration: const InputDecoration(
                                          labelText: 'Step title',
                                          border: OutlineInputBorder(),
                                          isDense: true,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      tooltip: 'Delete step',
                                      onPressed: () => _deleteStep(idx),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: TextEditingController(text: step.description)
                                    ..selection = TextSelection.collapsed(offset: step.description.length),
                                  onChanged: (v) => step.description = v,
                                  minLines: 2,
                                  maxLines: 6,
                                  decoration: const InputDecoration(
                                    labelText: 'Description',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _canSave ? _save : null,
                          child: Text(_isEdit ? 'Save' : 'Create'),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecipeFormattedView extends StatelessWidget {
  const _RecipeFormattedView({
    required this.title,
    required this.description,
    required this.tags,
    required this.score10,
    required this.sections,
    required this.steps,
  });

  final String title;
  final String description;
  final List<RecipeTag> tags;
  final int score10;
  final List<IngredientSection> sections;
  final List<RecipeStep> steps;

  @override
  Widget build(BuildContext context) {
    final hasIngredients = sections.any((s) => s.ingredients.isNotEmpty);
    final hasSteps = steps.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.trim().isEmpty ? 'Untitled' : title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _StarDisplay(score10: score10),
              const SizedBox(width: 10),
              Text(
                '${(score10 / 2).toStringAsFixed((score10 % 2 == 0) ? 0 : 1)} / 5',
                style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (tags.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tags.map((t) => _RecipeTagPill(tag: t)).toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (description.trim().isNotEmpty) ...[
            Text(
              description.trim(),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87, height: 1.3),
            ),
            const SizedBox(height: 14),
          ],
          const Divider(height: 1, color: Color(0x1F000000)),
          const SizedBox(height: 12),

          Text(
            'Ingredients',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (!hasIngredients)
            Text(
              'No ingredients yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
            )
          else
            ...sections.where((s) => s.ingredients.isNotEmpty).map((s) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (s.sectionTitle.trim().isNotEmpty) ...[
                      Text(
                        s.sectionTitle.trim(),
                        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                    ],
                    ...s.ingredients.map((i) {
                      final qty = i.quantity.trim();
                      final unit = i.unit.trim();
                      final left = [
                        if (qty.isNotEmpty) qty,
                        if (unit.isNotEmpty) unit,
                      ].join(' ');
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('•  ', style: TextStyle(color: Colors.black54)),
                            Expanded(
                              child: Text(
                                left.isEmpty ? i.name : '$left  ${i.name}',
                                style: const TextStyle(color: Colors.black87),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),

          const Divider(height: 1, color: Color(0x1F000000)),
          const SizedBox(height: 12),

          Text(
            'Steps',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.black87,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (!hasSteps)
            Text(
              'No steps yet.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
            )
          else
            ...List.generate(steps.length, (idx) {
              final s = steps[idx];
              final title = s.stepTitle.trim().isEmpty ? 'Step ${idx + 1}' : s.stepTitle.trim();
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${idx + 1}. $title',
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
                    ),
                    if (s.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        s.description.trim(),
                        style: const TextStyle(color: Colors.black87, height: 1.3),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _StarPicker extends StatelessWidget {
  const _StarPicker({required this.score10, required this.onChanged});
  final int score10;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = score10.clamp(0, 10);

    Widget buildStar(int index) {
      final leftValue = (index * 2) + 1; // half
      final rightValue = (index * 2) + 2; // full

      final full = s >= rightValue;
      final half = !full && s == leftValue;

      final icon = full
          ? Icons.star
          : (half ? Icons.star_half : Icons.star_border);

      return SizedBox(
        width: 28,
        height: 28,
        child: Stack(
          children: [
            Center(child: Icon(icon, color: const Color(0xFFFFB300), size: 24)),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(leftValue),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(rightValue),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, buildStar),
    );
  }
}

class _RecipeTagMultiFilterPickerSheet extends StatefulWidget {
  const _RecipeTagMultiFilterPickerSheet({
    required this.store,
    required this.selectedKeys,
  });

  final RecipeStore store;
  final Set<String> selectedKeys;

  @override
  State<_RecipeTagMultiFilterPickerSheet> createState() => _RecipeTagMultiFilterPickerSheetState();
}

class _RecipeTagMultiFilterPickerSheetState extends State<_RecipeTagMultiFilterPickerSheet> {
  late final Set<String> _picked;

  @override
  void initState() {
    super.initState();
    _picked = {...widget.selectedKeys};
  }

  void _toggle(RecipeTag t) {
    setState(() {
      if (_picked.contains(t.key)) {
        _picked.remove(t.key);
      } else {
        _picked.add(t.key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final builtIns = widget.store.builtInTagsSorted();
    final customs = widget.store.customTagsSorted();

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Filter by Tags',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const TabBar(
                tabs: [
                  Tab(text: 'Built-in'),
                  Tab(text: 'Custom'),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 420,
                child: TabBarView(
                  children: [
                    _RecipeTagMultiList(tags: builtIns, pickedKeys: _picked, onToggle: _toggle),
                    _RecipeTagMultiList(tags: customs, pickedKeys: _picked, onToggle: _toggle),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _picked.clear()),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_picked),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeTagMultiPickerSheet extends StatefulWidget {
  const _RecipeTagMultiPickerSheet({
    required this.store,
    required this.selectedKeys,
  });

  final RecipeStore store;
  final Set<String> selectedKeys;

  @override
  State<_RecipeTagMultiPickerSheet> createState() => _RecipeTagMultiPickerSheetState();
}

class _RecipeTagMultiPickerSheetState extends State<_RecipeTagMultiPickerSheet> {
  late final Set<String> _picked;

  @override
  void initState() {
    super.initState();
    _picked = {...widget.selectedKeys};
  }

  void _toggle(RecipeTag t) {
    setState(() {
      if (_picked.contains(t.key)) {
        _picked.remove(t.key);
      } else {
        _picked.add(t.key);
      }
    });
  }

  Future<void> _createCustomTag() async {
    final created = await showModalBottomSheet<RecipeTag?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _CreateCustomRecipeTagSheet(),
    );

    if (!mounted || created == null) return;

    widget.store.upsertCustomTag(created);
    setState(() {});
  }

  Future<void> _confirmDeleteCustomTag(RecipeTag tag) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete custom tag?'),
        content: Text('Delete "${tag.emoji} ${tag.name}"? Recipes using it will lose that tag.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (shouldDelete == true) {
      widget.store.deleteCustomTag(tag);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final builtIns = widget.store.builtInTagsSorted();
    final customs = widget.store.customTagsSorted();

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Tags',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const TabBar(
                tabs: [
                  Tab(text: 'Tags'),
                  Tab(text: 'Custom Tags'),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 420,
                child: TabBarView(
                  children: [
                    _RecipeTagMultiList(tags: builtIns, pickedKeys: _picked, onToggle: _toggle),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: _createCustomTag,
                            icon: const Icon(Icons.add),
                            label: const Text('New custom tag'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: customs.isEmpty
                              ? Center(
                            child: Text(
                              'No custom tags yet.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                            ),
                          )
                              : _RecipeTagMultiList(
                            tags: customs,
                            pickedKeys: _picked,
                            onToggle: _toggle,
                            onLongPress: (t) => _confirmDeleteCustomTag(t),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _picked.clear()),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(_picked),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipeTagMultiList extends StatelessWidget {
  const _RecipeTagMultiList({
    required this.tags,
    required this.pickedKeys,
    required this.onToggle,
    this.onLongPress,
  });

  final List<RecipeTag> tags;
  final Set<String> pickedKeys;
  final void Function(RecipeTag) onToggle;
  final void Function(RecipeTag)? onLongPress;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return Center(
        child: Text(
          'None',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      );
    }

    return ListView.separated(
      itemCount: tags.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x1F000000)),
      itemBuilder: (context, i) {
        final t = tags[i];
        final sel = pickedKeys.contains(t.key);

        return InkWell(
          onTap: () => onToggle(t),
          onLongPress: onLongPress == null ? null : () => onLongPress!(t),
          onSecondaryTap: onLongPress == null ? null : () => onLongPress!(t),
          child: ListTile(
            leading: Text(t.emoji.isEmpty ? '🏷️' : t.emoji, style: const TextStyle(fontSize: 26)),
            title: Text(t.name, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
            subtitle: Text(t.isCustom ? 'Custom' : 'Built-in', style: const TextStyle(color: Colors.black54)),
            trailing: sel ? const Icon(Icons.check, color: Colors.black87) : null,
          ),
        );
      },
    );
  }
}

class _CreateCustomRecipeTagSheet extends StatefulWidget {
  const _CreateCustomRecipeTagSheet();

  @override
  State<_CreateCustomRecipeTagSheet> createState() => _CreateCustomRecipeTagSheetState();
}

class _CreateCustomRecipeTagSheetState extends State<_CreateCustomRecipeTagSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  String _emoji = '🏷️';

  static const List<String> _emojiChoices = [
    '🏷️', '✅', '⭐️', '❗️', '🛒',
    '🥬', '🍅', '🧅', '🥕', '🍎', '🍌',
    '🥩', '🍗', '🐟', '🥚',
    '🧀', '🥛', '🍞', '🥫',
    '🥤', '☕️', '🧊',
    '🔥', '🌶️',

    '🍳', '🥪', '🍽️', '🍿', '🍰', '🥗', '💪', '🌱', '🚫🌾', '🍲',
    '🍝', '🍛', '🍣', '🥘', '🍜', '🥞',
    '🫐', '🍋', '🧄', '🫒',

    '♨️',

    '🧃', '🧋', '🍵', '🫖',

    '🍫', '🍪', '🍬', '🍩', '🧁',

    '🧂', '🍯', '🍚',

    '🥖', '🥯', '🥐', '🫓', '🥨',

    '🥦', '🥒', '🌽', '🥔', '🍠', '🫑', '🍄', '🥑',
    '🍊', '🍐', '🍓', '🍇', '🍉', '🍍', '🥭', '🍒', '🥝',

    '🦐', '🦀', '🫘', '🥜',

    '🧈',

    '🧻', '🧼', '🧽', '🧴', '🧺', '🧹', '🪣', '🧤', '🧯',

    '💊', '🩹', '🪥',

    '🍼', '🧷', '🐶', '🐱', '🦴',

    '🔋', '💡', '🕯️', '🧰', '🪛', '🔧', '🔌', '🪫',

    '🎉', '🎈',

    '📦', '🧾', '🎁', '📌',
  ];


  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty;

  void _save() {
    Navigator.of(context).pop(
      RecipeTag(name: _nameCtrl.text.trim(), emoji: _emoji, isCustom: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: bottomInset),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            children: [
              Text(
                'New Custom Tag',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Tag name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Emoji',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _emojiChoices.map((e) {
                          final selected = e == _emoji;
                          return InkWell(
                            onTap: () => setState(() => _emoji = e),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFE1E6ED)
                                    : const Color(0xFFF3F5F7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected ? Colors.black26 : const Color(0x1F000000),
                                ),
                              ),
                              child: Text(e, style: const TextStyle(fontSize: 28)),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _canSave ? _save : null,
                    child: const Text('Save Tag'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}


class _IngredientsPanel extends StatefulWidget {
  const _IngredientsPanel({
    super.key,
    required this.store,
    required this.measurementStore,
  });

  final IngredientStore store;
  final MeasurementStore measurementStore;

  @override
  State<_IngredientsPanel> createState() => _IngredientsPanelState();
}

class _IngredientsPanelState extends State<_IngredientsPanel> {
  final TextEditingController _searchCtrl = TextEditingController();

  IngredientTag? _filterTag;
  String? _filterStore; // null => All

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void openAddIngredient() {
    _openIngredientEditor();
  }

  List<String> _unitsSorted() {
    final units = widget.measurementStore.measurements.map((m) => m.unit).toList()..sort();
    return units;
  }

  List<Ingredient> _filteredIngredients() {
    final query = _searchCtrl.text.trim();

    var items = widget.store.ingredients.toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final ft = _filterTag;
    if (ft != null) {
      items = items.where((i) {
        return i.hasTag &&
            i.tagName.trim().toLowerCase() == ft.name.trim().toLowerCase() &&
            i.tagIsCustom == ft.isCustom;
      }).toList();
    }

    final fs = _filterStore;
    if (fs != null) {
      items = items
          .where((i) => i.hasStore && i.storeTag.trim().toLowerCase() == fs.trim().toLowerCase())
          .toList();
    }

    if (query.isNotEmpty) {
      final hits = fuzzySearch<Ingredient>(
        items,
        query,
        200,
        0.20,
        stringify: (i) => i.name,
      );
      return hits.toList();
    }

    return items;
  }

  Future<void> _openIngredientEditor({Ingredient? existing}) async {
    final result = await showModalBottomSheet<_IngredientEditorResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return _IngredientEditorSheet(
          existing: existing,
          store: widget.store,
          availableUnits: _unitsSorted(),
        );
      },
    );

    if (!mounted || result == null) return;

    if (result.delete == true && existing != null) {
      widget.store.deleteIngredientByName(existing.name);
      setState(() {});
      return;
    }

    if (result.ingredient != null) {
      widget.store.upsertIngredient(result.ingredient!);
      setState(() {});
    }
  }

  Future<void> _confirmDeleteIngredient(Ingredient ing) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete ingredient?'),
        content: Text('Delete "${ing.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (shouldDelete == true) {
      widget.store.deleteIngredientByName(ing.name);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filteredIngredients();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Card(
          elevation: 0,
          color: const Color(0xFFF3F5F7),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x1F000000)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ingredients',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black87),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: openAddIngredient,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Ingredient'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Search ingredients',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    suffixIcon: _searchCtrl.text.trim().isEmpty
                        ? null
                        : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _FilterDropdownButton(
                        label: 'Tag filter',
                        valueWidget: _filterTag == null
                            ? const Text(
                          'All tags',
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                        )
                            : _TagPill(tag: _filterTag!),
                        onPressed: () async {
                          final picked = await showModalBottomSheet<IngredientTag?>(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            builder: (ctx) => _TagFilterPickerSheet(
                              store: widget.store,
                              selected: _filterTag,
                            ),
                          );
                          if (!mounted) return;
                          setState(() => _filterTag = picked); // null => all
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FilterDropdownButton(
                        label: 'Store filter',
                        valueWidget: (_filterStore == null)
                            ? const Text(
                          'All stores',
                          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                        )
                            : _StorePill(text: _filterStore!),
                        onPressed: () async {
                          final picked = await showModalBottomSheet<String?>(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            builder: (ctx) => _StoreFilterPickerSheet(
                              store: widget.store,
                              selected: _filterStore,
                            ),
                          );
                          if (!mounted) return;
                          setState(() => _filterStore = picked); // null => all
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0x1F000000)),
                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 3,
                        child: Text('Name', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                      ),

                      Expanded(
                        flex: 2,
                        child: Text('Tag', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black87)),
                      ),

                    ],
                  ),
                ),

                const SizedBox(height: 6),

                Expanded(
                  child: list.isEmpty
                      ? Center(
                    child: Text(
                      widget.store.ingredients.isEmpty ? 'No ingredients yet. Tap + to add one.' : 'No matches.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                    ),
                  )
                      : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x1F000000)),
                    itemBuilder: (context, i) {
                      final ing = list[i];
                      final tag = ing.tagOrNull;

                      return InkWell(
                        onTap: () => _openIngredientEditor(existing: ing),
                        onLongPress: () => _confirmDeleteIngredient(ing),
                        onSecondaryTap: () => _confirmDeleteIngredient(ing),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  ing.name,
                                  style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                                ),
                              ),

                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: tag == null
                                      ? const Text('—', style: TextStyle(color: Colors.black54))
                                      : _TagPill(tag: tag),
                                ),
                              ),

                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterDropdownButton extends StatelessWidget {
  const _FilterDropdownButton({
    required this.label,
    required this.valueWidget,
    required this.onPressed,
  });

  final String label;
  final Widget valueWidget;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        side: const BorderSide(color: Color(0x1F000000)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                const SizedBox(height: 6),
                valueWidget,
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_drop_down, color: Colors.black54),
        ],
      ),
    );
  }
}

class _TagFilterPickerSheet extends StatelessWidget {
  const _TagFilterPickerSheet({
    required this.store,
    required this.selected,
  });

  final IngredientStore store;
  final IngredientTag? selected;

  bool _isSelected(IngredientTag a, IngredientTag? b) {
    if (b == null) return false;
    return a.name.trim().toLowerCase() == b.name.trim().toLowerCase() && a.isCustom == b.isCustom;
  }

  @override
  Widget build(BuildContext context) {
    final builtIns = store.builtInTagsSorted();
    final customs = store.customTagsSorted();

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Filter by Tag',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const TabBar(
                tabs: [
                  Tab(text: 'Built-in'),
                  Tab(text: 'Custom'),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 420,
                child: TabBarView(
                  children: [
                    _TagFilterList(
                      tags: builtIns,
                      selected: selected,
                      isSelected: _isSelected,
                    ),
                    _TagFilterList(
                      tags: customs,
                      selected: selected,
                      isSelected: _isSelected,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('All tags'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagFilterList extends StatelessWidget {
  const _TagFilterList({
    required this.tags,
    required this.selected,
    required this.isSelected,
  });

  final List<IngredientTag> tags;
  final IngredientTag? selected;
  final bool Function(IngredientTag, IngredientTag?) isSelected;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return Center(
        child: Text(
          'None',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      );
    }

    return ListView.separated(
      itemCount: tags.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x1F000000)),
      itemBuilder: (context, i) {
        final t = tags[i];
        final sel = isSelected(t, selected);

        return ListTile(
          leading: Text(t.emoji, style: const TextStyle(fontSize: 26)),
          title: Text(t.name, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
          trailing: sel ? const Icon(Icons.check, color: Colors.black87) : null,
          onTap: () => Navigator.of(context).pop(t),
        );
      },
    );
  }
}

class _StoreFilterPickerSheet extends StatelessWidget {
  const _StoreFilterPickerSheet({
    required this.store,
    required this.selected,
  });

  final IngredientStore store;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final builtIns = store.builtInStoresSorted();
    final customs = store.customStoresSorted();

    bool isSel(String s) => selected != null && selected!.trim().toLowerCase() == s.trim().toLowerCase();

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Filter by Store',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const TabBar(
                tabs: [
                  Tab(text: 'Stores'),
                  Tab(text: 'Custom Stores'),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 420,
                child: TabBarView(
                  children: [
                    _StoreFilterList(
                      stores: builtIns,
                      isSelected: isSel,
                      onPick: (s) => Navigator.of(context).pop(s),
                    ),
                    _StoreFilterList(
                      stores: customs,
                      isSelected: isSel,
                      onPick: (s) => Navigator.of(context).pop(s),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('All stores'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreFilterList extends StatelessWidget {
  const _StoreFilterList({
    required this.stores,
    required this.isSelected,
    required this.onPick,
  });

  final List<String> stores;
  final bool Function(String) isSelected;
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty) {
      return Center(
        child: Text(
          'None',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      );
    }

    return ListView.separated(
      itemCount: stores.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x1F000000)),
      itemBuilder: (context, i) {
        final s = stores[i];
        final sel = isSelected(s);
        return ListTile(
          leading: const Icon(Icons.store_outlined, color: Colors.black54),
          title: Text(s, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
          trailing: sel ? const Icon(Icons.check, color: Colors.black87) : null,
          onTap: () => onPick(s),
        );
      },
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag});
  final IngredientTag tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EAEE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x1F000000)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(tag.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              tag.name,
              style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _StorePill extends StatelessWidget {
  const _StorePill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EAEE),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x1F000000)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _IngredientEditorResult {
  final Ingredient? ingredient;
  final bool? delete;
  const _IngredientEditorResult({this.ingredient, this.delete});
}

class _IngredientEditorSheet extends StatefulWidget {
  const _IngredientEditorSheet({
    required this.store,
    required this.availableUnits,
    this.existing,
  });

  final IngredientStore store;
  final List<String> availableUnits;
  final Ingredient? existing;

  @override
  State<_IngredientEditorSheet> createState() => _IngredientEditorSheetState();
}

class _IngredientEditorSheetState extends State<_IngredientEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _unitCtrl;

  IngredientTag? _tag;
  String? _storeTag;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _unitCtrl = TextEditingController(text: widget.existing?.unit ?? '');
    _tag = widget.existing?.tagOrNull;
    _storeTag = (widget.existing?.storeTag.trim().isNotEmpty ?? false) ? widget.existing!.storeTag : null;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.existing != null;
  bool get _canSave => _nameCtrl.text.trim().isNotEmpty;

  Future<void> _pickTag() async {
    final picked = await showModalBottomSheet<IngredientTag?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _TagPickerSheet(store: widget.store),
    );

    if (!mounted) return;
    setState(() => _tag = picked);
  }

  Future<void> _pickStore() async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _StorePickerSheet(store: widget.store),
    );

    if (!mounted) return;
    setState(() => _storeTag = picked);
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    final unit = _unitCtrl.text.trim();

    final ing = Ingredient(
      name: name,
      unit: unit,
      tagName: _tag?.name ?? '',
      tagEmoji: _tag?.emoji ?? '',
      tagIsCustom: _tag?.isCustom ?? false,
      storeTag: _storeTag ?? '',
    );

    Navigator.of(context).pop(_IngredientEditorResult(ingredient: ing));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isEdit ? 'Edit Ingredient' : 'Add Ingredient',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_isEdit)
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => Navigator.of(context).pop(const _IngredientEditorResult(delete: true)),
                  icon: const Icon(Icons.delete_outline),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _nameCtrl,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),

          Autocomplete<String>(
            initialValue: TextEditingValue(text: _unitCtrl.text),
            optionsBuilder: (TextEditingValue textEditingValue) {
              final q = textEditingValue.text.trim();
              final allUnits = widget.availableUnits;
              if (allUnits.isEmpty) return const Iterable<String>.empty();
              if (q.isEmpty) return allUnits.take(10);

              return fuzzySearch<String>(
                allUnits,
                q,
                10,
                0.25,
                stringify: (s) => s,
              );
            },
            onSelected: (String selection) => setState(() => _unitCtrl.text = selection),
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              controller.text = _unitCtrl.text;
              controller.addListener(() {
                _unitCtrl.text = controller.text;
              });

              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Common Unit',
                  border: const OutlineInputBorder(),
                  helperText: widget.availableUnits.isEmpty
                      ? 'No units found. Add units in Measurements first.'
                      : 'Choose from your Measurements units.',
                ),
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              final opts = options.toList();
              if (opts.isEmpty) return const SizedBox.shrink();

              const double tileH = 48.0;
              const int maxVisible = 6;
              const double maxH = 260.0;

              final visibleCount = opts.length > maxVisible ? maxVisible : opts.length;
              final desiredH = (visibleCount * tileH).clamp(tileH, maxH).toDouble();
              final scrolls = opts.length > maxVisible;

              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SizedBox(
                      height: desiredH,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: opts.length,
                        shrinkWrap: true,
                        physics: scrolls ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
                        itemBuilder: (context, index) {
                          final opt = opts[index];
                          return ListTile(
                            dense: true,
                            title: Text(opt),
                            onTap: () => onSelected(opt),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _tag == null
                    ? const Text('Tag: None', style: TextStyle(color: Colors.black54))
                    : Row(
                  children: [
                    const Text('Tag: ', style: TextStyle(color: Colors.black54)),
                    _TagPill(tag: _tag!),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _pickTag,
                icon: const Icon(Icons.label_outline),
                label: const Text('Choose'),
              ),
              if (_tag != null)
                TextButton(
                  onPressed: () => setState(() => _tag = null),
                  child: const Text('Clear'),
                ),
            ],
          ),

          Row(
            children: [
              Expanded(
                child: (_storeTag == null || _storeTag!.trim().isEmpty)
                    ? const Text('Store: None', style: TextStyle(color: Colors.black54))
                    : Row(
                  children: [
                    const Text('Store: ', style: TextStyle(color: Colors.black54)),
                    _StorePill(text: _storeTag!),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _pickStore,
                icon: const Icon(Icons.store_outlined),
                label: const Text('Choose'),
              ),
              if (_storeTag != null && _storeTag!.trim().isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _storeTag = null),
                  child: const Text('Clear'),
                ),
            ],
          ),

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _canSave ? _save : null,
              child: Text(_isEdit ? 'Save' : 'Add'),
            ),
          ),
        ],
      ),
    );
  }
}


class _TagPickerSheet extends StatefulWidget {
  const _TagPickerSheet({required this.store});

  final IngredientStore store;

  @override
  State<_TagPickerSheet> createState() => _TagPickerSheetState();
}

class _TagPickerSheetState extends State<_TagPickerSheet> {
  Future<void> _createCustomTag() async {
    final created = await showModalBottomSheet<IngredientTag?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _CreateCustomTagSheet(),
    );

    if (!mounted || created == null) return;

    widget.store.upsertCustomTag(created);
    setState(() {});
  }

  Future<void> _confirmDeleteCustomTag(IngredientTag tag) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete custom tag?'),
        content: Text('Delete "${tag.emoji} ${tag.name}"? Ingredients using it will become untagged.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (shouldDelete == true) {
      widget.store.deleteCustomTag(tag);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final builtIns = widget.store.builtInTagsSorted();
    final customs = widget.store.customTagsSorted();

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose a Tag',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const TabBar(
                tabs: [
                  Tab(text: 'Tags'),
                  Tab(text: 'Custom Tags'),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 420,
                child: TabBarView(
                  children: [
                    _TagList(
                      tags: builtIns,
                      onPick: (t) => Navigator.of(context).pop(t),
                      onLongPress: null,
                    ),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: _createCustomTag,
                            icon: const Icon(Icons.add),
                            label: const Text('New custom tag'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: customs.isEmpty
                              ? Center(
                            child: Text(
                              'No custom tags yet.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                            ),
                          )
                              : _TagList(
                            tags: customs,
                            onPick: (t) => Navigator.of(context).pop(t),
                            onLongPress: (t) => _confirmDeleteCustomTag(t),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('No tag'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagList extends StatelessWidget {
  const _TagList({
    required this.tags,
    required this.onPick,
    required this.onLongPress,
  });

  final List<IngredientTag> tags;
  final void Function(IngredientTag) onPick;
  final void Function(IngredientTag)? onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: tags.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x1F000000)),
      itemBuilder: (context, i) {
        final t = tags[i];

        return InkWell(
          onTap: () => onPick(t),
          onLongPress: onLongPress == null ? null : () => onLongPress!(t),
          onSecondaryTap: onLongPress == null ? null : () => onLongPress!(t),
          child: ListTile(
            leading: Text(t.emoji, style: const TextStyle(fontSize: 26)),
            title: Text(t.name, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
            subtitle: Text(t.isCustom ? 'Custom' : 'Built-in', style: const TextStyle(color: Colors.black54)),
          ),
        );
      },
    );
  }
}

class _CreateCustomTagSheet extends StatefulWidget {
  const _CreateCustomTagSheet();

  @override
  State<_CreateCustomTagSheet> createState() => _CreateCustomTagSheetState();
}

class _CreateCustomTagSheetState extends State<_CreateCustomTagSheet> {
  final TextEditingController _nameCtrl = TextEditingController();
  String _emoji = '🏷️';


  static const List<String> _emojiChoices = [
    '🏷️', '✅', '⭐️', '❗️', '🛒',
    '🥬', '🍅', '🧅', '🥕', '🍎', '🍌',
    '🥩', '🍗', '🐟', '🥚',
    '🧀', '🥛', '🍞', '🥫',
    '🥤', '☕️', '🧊',
    '🔥', '🌶️',

    '🍳', '🥪', '🍽️', '🍿', '🍰', '🥗', '💪', '🌱', '🚫🌾', '🍲',
    '🍝', '🍛', '🍣', '🥘', '🍜', '🥞',
    '🫐', '🍋', '🧄', '🫒',

    '♨️',

    '🧃', '🧋', '🍵', '🫖',

    '🍫', '🍪', '🍬', '🍩', '🧁',

    '🧂', '🍯', '🍚',

    '🥖', '🥯', '🥐', '🫓', '🥨',

    '🥦', '🥒', '🌽', '🥔', '🍠', '🫑', '🍄', '🥑',
    '🍊', '🍐', '🍓', '🍇', '🍉', '🍍', '🥭', '🍒', '🥝',

    '🦐', '🦀', '🫘', '🥜',

    '🧈',

    '🧻', '🧼', '🧽', '🧴', '🧺', '🧹', '🪣', '🧤', '🧯',

    '💊', '🩹', '🪥',

    '🍼', '🧷', '🐶', '🐱', '🦴',

    '🔋', '💡', '🕯️', '🧰', '🪛', '🔧', '🔌', '🪫',

    '🎉', '🎈',

    '📦', '🧾', '🎁', '📌',
  ];





  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty;

  void _save() {
    Navigator.of(context).pop(
      IngredientTag(name: _nameCtrl.text.trim(), emoji: _emoji, isCustom: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenH = MediaQuery.of(context).size.height;

    final sheetHeight = screenH * 0.85;

    return SafeArea(
      child: SizedBox(
        height: sheetHeight,
        child: Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 10),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'New Custom Tag',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Tag name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Emoji',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _emojiChoices.map((e) {
                          final selected = e == _emoji;
                          return InkWell(
                            onTap: () => setState(() => _emoji = e),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: selected ? const Color(0xFFE1E6ED) : const Color(0xFFF3F5F7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: selected ? Colors.black26 : const Color(0x1F000000)),
                              ),
                              child: Text(e, style: const TextStyle(fontSize: 28)),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              AnimatedPadding(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: 16 + bottomInset),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _canSave ? _save : null,
                    child: const Text('Save Tag'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }



}


class _StorePickerSheet extends StatefulWidget {
  const _StorePickerSheet({required this.store});
  final IngredientStore store;

  @override
  State<_StorePickerSheet> createState() => _StorePickerSheetState();
}

class _StorePickerSheetState extends State<_StorePickerSheet> {
  Future<void> _createCustomStore() async {
    final name = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => const _CreateCustomStoreSheet(),
    );

    if (!mounted || name == null || name.trim().isEmpty) return;
    widget.store.upsertCustomStore(name);
    setState(() {});
  }

  Future<void> _confirmDeleteCustomStore(String store) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete custom store?'),
        content: Text('Delete "$store"? Ingredients using it will become unassigned.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (shouldDelete == true) {
      widget.store.deleteCustomStore(store);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final builtIns = widget.store.builtInStoresSorted();
    final customs = widget.store.customStoresSorted();

    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose a Store',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const TabBar(
                tabs: [
                  Tab(text: 'Stores'),
                  Tab(text: 'Custom Stores'),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 420,
                child: TabBarView(
                  children: [
                    _StoreList(
                      stores: builtIns,
                      onPick: (s) => Navigator.of(context).pop(s),
                      onLongPress: null,
                    ),
                    Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: _createCustomStore,
                            icon: const Icon(Icons.add),
                            label: const Text('New custom store'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: customs.isEmpty
                              ? Center(
                            child: Text(
                              'No custom stores yet.',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                            ),
                          )
                              : _StoreList(
                            stores: customs,
                            onPick: (s) => Navigator.of(context).pop(s),
                            onLongPress: (s) => _confirmDeleteCustomStore(s),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('No store'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreList extends StatelessWidget {
  const _StoreList({
    required this.stores,
    required this.onPick,
    required this.onLongPress,
  });

  final List<String> stores;
  final void Function(String) onPick;
  final void Function(String)? onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: stores.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x1F000000)),
      itemBuilder: (context, i) {
        final s = stores[i];

        return InkWell(
          onTap: () => onPick(s),
          onLongPress: onLongPress == null ? null : () => onLongPress!(s),
          onSecondaryTap: onLongPress == null ? null : () => onLongPress!(s),
          child: ListTile(
            title: Text(s, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
            leading: const Icon(Icons.store_outlined, color: Colors.black54),
          ),
        );
      },
    );
  }
}

class _CreateCustomStoreSheet extends StatefulWidget {
  const _CreateCustomStoreSheet();

  @override
  State<_CreateCustomStoreSheet> createState() => _CreateCustomStoreSheetState();
}

class _CreateCustomStoreSheetState extends State<_CreateCustomStoreSheet> {
  final TextEditingController _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _canSave => _nameCtrl.text.trim().isNotEmpty;

  void _save() => Navigator.of(context).pop(_nameCtrl.text.trim());

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 16 + bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'New Custom Store',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'Store name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.store_outlined),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                child: const Text('Save Store'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _CalculatorPanel extends StatefulWidget {
  const _CalculatorPanel({super.key, required this.store});
  final MeasurementStore store;

  @override
  State<_CalculatorPanel> createState() => _CalculatorPanelState();
}

class _CalculatorPanelState extends State<_CalculatorPanel> {
  String? _selectedUnit;
  final TextEditingController _valueCtrl = TextEditingController(text: '1');
  bool _showFractions = false;

  @override
  void dispose() {
    _valueCtrl.dispose();
    super.dispose();
  }

  List<String> _allUnitsSorted() {
    final units = widget.store.measurements.map((m) => m.unit).toList()..sort();
    return units;
  }

  double _valueA() => double.tryParse(_valueCtrl.text.trim()) ?? 0.0;

  @override
  Widget build(BuildContext context) {
    final allUnits = _allUnitsSorted();

    if (_selectedUnit == null && allUnits.isNotEmpty) {
      _selectedUnit = allUnits.first;
    }
    if (_selectedUnit != null && !allUnits.contains(_selectedUnit)) {
      _selectedUnit = allUnits.isEmpty ? null : allUnits.first;
    }

    final m = (_selectedUnit == null) ? null : widget.store.getOrCreate(_selectedUnit!);
    final rels = (m == null) ? <dynamic>[] : (m.relations.toList()..sort((a, b) => a.m.unit.compareTo(b.m.unit)));

    final valueA = _valueA();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Card(
          elevation: 0,
          color: const Color(0xFFF3F5F7),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x1F000000)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Calculator',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black87),
                      ),
                    ),
                    IconButton(
                      tooltip: _showFractions ? 'Show decimals' : 'Show fractions',
                      onPressed: () => setState(() => _showFractions = !_showFractions),
                      icon: Icon(_showFractions ? Icons.calculate_outlined : Icons.functions),
                      color: Colors.black87,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Pick a unit, enter a value, and see conversions using your saved relationships.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Autocomplete<String>(
                        initialValue: TextEditingValue(text: _selectedUnit ?? ''),
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          final q = textEditingValue.text;
                          if (allUnits.isEmpty) return const Iterable<String>.empty();
                          if (q.trim().isEmpty) return allUnits.take(10);

                          return fuzzySearch<String>(
                            allUnits,
                            q,
                            10,
                            0.25,
                            stringify: (s) => s,
                          );
                        },
                        onSelected: (String selection) => setState(() => _selectedUnit = selection),
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: (_) => onFieldSubmitted(),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          final opts = options.toList();
                          if (opts.isEmpty) return const SizedBox.shrink();

                          const double tileH = 48.0;
                          const int maxVisible = 6;
                          const double maxH = 260.0;

                          final visibleCount = opts.length > maxVisible ? maxVisible : opts.length;
                          final desiredH = (visibleCount * tileH).clamp(tileH, maxH).toDouble();
                          final scrolls = opts.length > maxVisible;

                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 520),
                                child: SizedBox(
                                  height: desiredH,
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: opts.length,
                                    shrinkWrap: true,
                                    physics: scrolls ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
                                    itemBuilder: (context, index) {
                                      final opt = opts[index];
                                      return ListTile(
                                        dense: true,
                                        title: Text(opt),
                                        onTap: () => onSelected(opt),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _valueCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                        decoration: InputDecoration(
                          labelText: 'Value (A)',
                          border: const OutlineInputBorder(),
                          suffixIcon: _selectedUnit == null
                              ? null
                              : Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Center(
                              widthFactor: 0,
                              child: Text(_selectedUnit!, style: const TextStyle(color: Colors.black54)),
                            ),
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0x1F000000)),
                const SizedBox(height: 12),
                Expanded(
                  child: _selectedUnit == null
                      ? const _EmptyState(text: 'Add some units in Measurements first.')
                      : (rels.isEmpty
                      ? _EmptyState(text: 'No relationships found for "$_selectedUnit". Add conversions in Measurements.')
                      : ListView.separated(
                    itemCount: rels.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x1F000000)),
                    itemBuilder: (context, i) {
                      final r = rels[i];
                      final toUnit = r.m.unit as String;
                      final ratio = r.ratio as double;
                      final valueB = valueA * ratio;

                      final ratioLabel = _showFractions ? _fmtFraction(ratio) : _fmtDecimal(ratio);
                      final valueBLabel = _showFractions ? _fmtFraction(valueB) : _fmtDecimal(valueB);

                      return ListTile(
                        title: Text(
                          toUnit,
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '1 ${_selectedUnit!} = $ratioLabel $toUnit',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(valueBLabel,
                                style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                            Text(toUnit, style: const TextStyle(color: Colors.black45)),
                          ],
                        ),
                      );
                    },
                  )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDecimal(double v) {
    if (v == 0) return '0';
    final abs = v.abs();
    if (abs >= 1000) return v.toStringAsFixed(0);
    if (abs >= 100) return v.toStringAsFixed(2);
    if (abs >= 10) return v.toStringAsFixed(3);
    if (abs >= 1) return v.toStringAsFixed(4);
    return v.toStringAsPrecision(4);
  }

  String _fmtFraction(double v) {
    if (v.isNaN || v.isInfinite) return v.toString();
    final sign = v < 0 ? '-' : '';
    final x = v.abs();

    final nearestInt = x.roundToDouble();
    if ((x - nearestInt).abs() < 1e-10) return '$sign${nearestInt.toInt()}';

    final frac = _approxFraction(x, maxDen: 2000);
    if (frac == null) return '$sign${_fmtDecimal(x)}';

    final n = frac.$1;
    final d = frac.$2;

    if (d == 1) return '$sign$n';
    return '$sign$n/$d';
  }

  (int, int)? _approxFraction(double x, {required int maxDen}) {
    int a0 = x.floor();
    int p0 = 1, q0 = 0;
    int p1 = a0, q1 = 1;

    double r = x - a0;
    int iter = 0;

    while (iter < 32 && q1 <= maxDen && r.abs() > 1e-12) {
      iter++;
      r = 1.0 / r;
      final a = r.floor();

      final p2 = a * p1 + p0;
      final q2 = a * q1 + q0;

      if (q2 > maxDen) break;

      p0 = p1;
      q0 = q1;
      p1 = p2;
      q1 = q2;

      r = r - a;
    }

    if (q1 == 0) return null;

    final g = _gcd(p1, q1);
    final pn = p1 ~/ g;
    final qn = q1 ~/ g;

    final approx = pn / qn;
    if ((approx - x).abs() > 1e-6) return null;

    return (pn, qn);
  }

  int _gcd(int a, int b) {
    a = a.abs();
    b = b.abs();
    while (b != 0) {
      final t = a % b;
      a = b;
      b = t;
    }
    return a == 0 ? 1 : a;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
        textAlign: TextAlign.center,
      ),
    );
  }
}


class _MeasurementsPanel extends StatefulWidget {
  const _MeasurementsPanel({super.key, required this.store});
  final MeasurementStore store;

  @override
  State<_MeasurementsPanel> createState() => _MeasurementsPanelState();
}

class _MeasurementsPanelState extends State<_MeasurementsPanel> {
  final TextEditingController _newUnitCtrl = TextEditingController();

  final TextEditingController _aQtyCtrl = TextEditingController(text: '1');
  final TextEditingController _bQtyCtrl = TextEditingController(text: '1');

  final TextEditingController _filterCtrl = TextEditingController();

  String? _unitA;
  String? _unitB;

  @override
  void dispose() {
    _newUnitCtrl.dispose();
    _aQtyCtrl.dispose();
    _bQtyCtrl.dispose();
    _filterCtrl.dispose();
    super.dispose();
  }

  List<String> _sortedUnits() {
    final units = widget.store.measurements.map((m) => m.unit).toList()..sort();
    return units;
  }

  void _ensureUnitSelections() {
    final units = _sortedUnits();
    if (units.isEmpty) {
      _unitA = null;
      _unitB = null;
      return;
    }
    _unitA ??= units.first;
    _unitB ??= (units.length >= 2 ? units[1] : units.first);
    if (!units.contains(_unitA)) _unitA = units.first;
    if (!units.contains(_unitB)) _unitB = (units.length >= 2 ? units[1] : units.first);
  }

  void _addUnit() {
    final raw = _newUnitCtrl.text.trim();
    if (raw.isEmpty) return;

    final unit = raw.replaceAll(RegExp(r'\s+'), ' ');
    widget.store.getOrCreate(unit);
    _newUnitCtrl.clear();

    setState(() => _ensureUnitSelections());
  }

  void _addRelation() {
    _ensureUnitSelections();
    final aUnit = _unitA;
    final bUnit = _unitB;
    if (aUnit == null || bUnit == null) return;

    if (aUnit == bUnit) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pick two different units.')));
      return;
    }

    final aQty = double.tryParse(_aQtyCtrl.text.trim());
    final bQty = double.tryParse(_bQtyCtrl.text.trim());

    if (aQty == null || bQty == null || aQty <= 0 || bQty <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter A and B amounts greater than 0.')));
      return;
    }

    final ratio = bQty / aQty;
    widget.store.addRelation(aUnit, bUnit, ratio);
    setState(() {});
  }

  Future<void> _confirmDeleteUnit(String unit) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete unit?'),
        content: Text('Delete "$unit" and remove its relationships? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
        ],
      ),
    );

    if (shouldDelete == true) {
      widget.store.deleteMeasurement(unit);
      setState(() => _ensureUnitSelections());
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureUnitSelections();

    final allUnits = _sortedUnits();
    final filter = _filterCtrl.text.trim().toLowerCase();
    final units = filter.isEmpty ? allUnits : allUnits.where((u) => u.toLowerCase().contains(filter)).toList();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Card(
          elevation: 0,
          color: const Color(0xFFF3F5F7),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x1F000000)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;

                final unitEntry = Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newUnitCtrl,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _addUnit(),
                        decoration: const InputDecoration(
                          labelText: 'Add a unit',
                          hintText: 'e.g., tsp, tbsp, cup, g, kg',
                          prefixIcon: Icon(Icons.add),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(onPressed: _addUnit, icon: const Icon(Icons.check), label: const Text('Add')),
                  ],
                );

                final relationEntry = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Add a relationship (A : B)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black87),
                    ),
                    const SizedBox(height: 10),
                    if (allUnits.length < 2)
                      Text(
                        'Add at least two units to create conversions.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                      )
                    else
                      Wrap(
                        runSpacing: 12,
                        spacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: wide ? 160 : double.infinity,
                            child: TextField(
                              controller: _aQtyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                              decoration: const InputDecoration(labelText: 'A amount', border: OutlineInputBorder()),
                            ),
                          ),
                          SizedBox(
                            width: wide ? 220 : double.infinity,
                            child: DropdownButtonFormField<String>(
                              value: _unitA,
                              decoration: const InputDecoration(labelText: 'Unit A', border: OutlineInputBorder()),
                              items: allUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (v) => setState(() => _unitA = v),
                            ),
                          ),
                          Text(':', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.black54)),
                          SizedBox(
                            width: wide ? 160 : double.infinity,
                            child: TextField(
                              controller: _bQtyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: false),
                              decoration: const InputDecoration(labelText: 'B amount', border: OutlineInputBorder()),
                            ),
                          ),
                          SizedBox(
                            width: wide ? 220 : double.infinity,
                            child: DropdownButtonFormField<String>(
                              value: _unitB,
                              decoration: const InputDecoration(labelText: 'Unit B', border: OutlineInputBorder()),
                              items: allUnits.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                              onChanged: (v) => setState(() => _unitB = v),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _addRelation,
                            icon: const Icon(Icons.swap_horiz),
                            label: const Text('Save'),
                          ),
                        ],
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Tip: For 7:13, enter A=7 and B=13. We store it as “1 A = 13/7 B”.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black45),
                    ),
                  ],
                );

                final unitListHeader = Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Units',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black87),
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _filterCtrl,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Filter',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                );

                final unitList = units.isEmpty
                    ? Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    allUnits.isEmpty ? 'No units yet.' : 'No matches.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                  ),
                )
                    : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: units.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0x1F000000)),
                  itemBuilder: (context, i) {
                    final unit = units[i];
                    final m = widget.store.getOrCreate(unit);
                    final rels = m.relations.toList()..sort((a, b) => a.m.unit.compareTo(b.m.unit));

                    return InkWell(
                      onLongPress: () => _confirmDeleteUnit(unit),
                      onSecondaryTap: () => _confirmDeleteUnit(unit),
                      child: ExpansionTile(
                        iconColor: Colors.black54,
                        collapsedIconColor: Colors.black54,
                        textColor: Colors.black87,
                        collapsedTextColor: Colors.black87,
                        title: Text(unit, style: const TextStyle(color: Colors.black87)),
                        subtitle: Text(
                          rels.isEmpty ? 'No conversions yet' : '${rels.length} conversion${rels.length == 1 ? '' : 's'}',
                          style: const TextStyle(color: Colors.black54),
                        ),
                        children: [
                          if (rels.isEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Text(
                                'Add a relationship above (e.g., 7:13).',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Column(
                                children: rels
                                    .take(18)
                                    .map(
                                      (r) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '1 $unit = ${_fmt(r.ratio)} ${r.m.unit}',
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black87),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                    .toList(),
                              ),
                            ),
                          if (rels.length > 18)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Text(
                                'Showing 18 of ${rels.length} conversions.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black45),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                );

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Measurements', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.black87)),
                      const SizedBox(height: 6),
                      Text(
                        'Add units and define ratios. Long-press (or right-click) a unit to delete it.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black54),
                      ),
                      const SizedBox(height: 16),
                      unitEntry,
                      const SizedBox(height: 18),
                      relationEntry,
                      const SizedBox(height: 18),
                      unitListHeader,
                      const SizedBox(height: 12),
                      unitList,
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v == 0) return '0';
    final abs = v.abs();
    if (abs >= 1000) return v.toStringAsFixed(0);
    if (abs >= 100) return v.toStringAsFixed(2);
    if (abs >= 10) return v.toStringAsFixed(3);
    if (abs >= 1) return v.toStringAsFixed(4);
    return v.toStringAsPrecision(4);
  }
}

enum _GroceryDest { active, archived, templates }

class _GroceryGroupKey {
  final _GroceryDest dest;
  final String listName;
  const _GroceryGroupKey({required this.dest, required this.listName});

  @override
  bool operator ==(Object other) =>
      other is _GroceryGroupKey && other.dest == dest && other.listName == listName;

  @override
  int get hashCode => Object.hash(dest, listName);
}

class _CsvIngredientRow {
  final String name;
  final String quantity;
  final String unit;
  final String tagName;
  final String tagEmoji;
  final String store;
  const _CsvIngredientRow({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.tagName,
    required this.tagEmoji,
    required this.store,
  });
}
