import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'measurements.dart';

class GroceryIds {
  static final Random _rng = Random();
  static String uid() => '${DateTime.now().microsecondsSinceEpoch}_${_rng.nextInt(1 << 30)}';
}

class GroceryListItem {
  final String id;

  String ingredientName;

  String quantity;
  String unit;
  String store;

  bool checked;
  String tagName;
  String tagEmoji;
  bool tagIsCustom;

  GroceryListItem({
    String? id,
    required this.ingredientName,
    this.quantity = '',
    this.unit = '',
    this.store = '',
    this.checked = false,
    this.tagName = '',
    this.tagEmoji = '',
    this.tagIsCustom = false,
  }) : id = id ?? GroceryIds.uid();

  GroceryListItem copy({String? newId}) => GroceryListItem(
    id: newId ?? GroceryIds.uid(),
    ingredientName: ingredientName,
    quantity: quantity,
    unit: unit,
    store: store,
    checked: checked,
    tagName: tagName,
    tagEmoji: tagEmoji,
    tagIsCustom: tagIsCustom,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'ingredientName': ingredientName,
    'quantity': quantity,
    'unit': unit,
    'store': store,
    'checked': checked,
    'tagName': tagName,
    'tagEmoji': tagEmoji,
    'tagIsCustom': tagIsCustom,
  };

  static GroceryListItem fromJson(Map<String, dynamic> j) => GroceryListItem(
    id: j['id'] as String?,
    ingredientName: j['ingredientName'] as String? ??
        (j['name'] as String? ?? ''), // legacy fallback
    quantity: j['quantity'] as String? ?? '',
    unit: j['unit'] as String? ?? '',
    store: j['store'] as String? ?? '',
    checked: j['checked'] as bool? ?? false,
    tagName: j['tagName'] as String? ?? '',
    tagEmoji: j['tagEmoji'] as String? ?? '',
    tagIsCustom: j['tagIsCustom'] as bool? ?? false,
  );
}

class GroceryList {
  final String id;

  String name;
  final DateTime createdAt;
  DateTime? completedAt;

  final List<GroceryListItem> items;

  GroceryList({
    String? id,
    required this.name,
    DateTime? createdAt,
    this.completedAt,
    List<GroceryListItem>? items,
  })  : id = id ?? GroceryIds.uid(),
        createdAt = createdAt ?? DateTime.now(),
        items = items ?? <GroceryListItem>[];

  bool get isArchived => completedAt != null;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
    'items': items.map((e) => e.toJson()).toList(),
  };

  static GroceryList fromJson(Map<String, dynamic> j) => GroceryList(
    id: j['id'] as String?,
    name: j['name'] as String? ?? 'Untitled',
    createdAt: _dtOrNull(j['createdAt']) ?? DateTime.now(),
    completedAt: _dtOrNull(j['completedAt']),
    items: (j['items'] is List)
        ? (j['items'] as List)
        .map((e) => GroceryListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
        : <GroceryListItem>[],
  );

  static DateTime? _dtOrNull(dynamic v) {
    if (v is String) {
      try {
        return DateTime.parse(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

class GroceryListTemplate {
  final String id;
  final DateTime createdAt;
  String name;
  final List<GroceryListItem> items;

  GroceryListTemplate({
    String? id,
    DateTime? createdAt,
    required this.name,
    List<GroceryListItem>? items,
  })  : id = id ?? GroceryIds.uid(),
        createdAt = createdAt ?? DateTime.now(),
        items = items ?? <GroceryListItem>[];

  Map<String, dynamic> toJson() => {
    'id': id,
    'createdAt': createdAt.toIso8601String(),
    'name': name,
    'items': items.map((e) => e.toJson()).toList(),
  };

  static GroceryListTemplate fromJson(Map<String, dynamic> j) => GroceryListTemplate(
    id: j['id'] as String?,
    createdAt: GroceryList._dtOrNull(j['createdAt']) ?? DateTime.now(),
    name: j['name'] as String? ?? 'Template',
    items: (j['items'] is List)
        ? (j['items'] as List)
        .map((e) => GroceryListItem.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList()
        : <GroceryListItem>[],
  );
}

class GroceryListStore {
  final List<GroceryList> _active = <GroceryList>[];
  final List<GroceryList> _archived = <GroceryList>[];
  final List<GroceryListTemplate> _templates = <GroceryListTemplate>[];

  int _nextListNumber = 1;

  final MeasurementStore measurementStore;


  static const String _dataFolderName = 'Data';
  static const String _fileName = 'grocery_list_store.json';

  Timer? _saveDebounce;
  bool _loaded = false;

  late final Future<void> ready;

  GroceryListStore({MeasurementStore? measurementStore})
      : measurementStore = measurementStore ?? MeasurementStore() {
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

      _active
        ..clear()
        ..addAll(
          (decoded['active'] is List)
              ? (decoded['active'] as List)
              .map((e) => GroceryList.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
              : const <GroceryList>[],
        );

      _archived
        ..clear()
        ..addAll(
          (decoded['archived'] is List)
              ? (decoded['archived'] as List)
              .map((e) => GroceryList.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
              : const <GroceryList>[],
        );

      _templates
        ..clear()
        ..addAll(
          (decoded['templates'] is List)
              ? (decoded['templates'] as List)
              .map((e) => GroceryListTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
              : const <GroceryListTemplate>[],
        );

      if (decoded['nextListNumber'] is int) {
        _nextListNumber = decoded['nextListNumber'] as int;
      }

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

  List<GroceryList> get active => List.unmodifiable(_active);
  List<GroceryList> get archived => List.unmodifiable(_archived);
  List<GroceryListTemplate> get templates => List.unmodifiable(_templates);

  GroceryList? getActiveById(String id) => _active.where((l) => l.id == id).cast<GroceryList?>().firstWhere(
        (x) => x != null,
    orElse: () => null,
  );

  GroceryList? getArchivedById(String id) => _archived.where((l) => l.id == id).cast<GroceryList?>().firstWhere(
        (x) => x != null,
    orElse: () => null,
  );

  GroceryList createNewList({String? name}) {
    final n = (name == null || name.trim().isEmpty) ? 'List #${_nextListNumber++}' : name.trim();
    final list = GroceryList(name: n);
    _active.insert(0, list);
    _markDirty();
    return list;
  }

  bool renameList(String listId, String newName) {
    final n = newName.trim();
    if (n.isEmpty) return false;
    final l = getActiveById(listId) ?? getArchivedById(listId);
    if (l == null) return false;
    l.name = n;
    _markDirty();
    return true;
  }

  bool markDone(String listId) {
    final idx = _active.indexWhere((l) => l.id == listId);
    if (idx < 0) return false;
    final list = _active.removeAt(idx);
    list.completedAt = DateTime.now();
    _archived.insert(0, list);
    _markDirty();
    return true;
  }

  bool reactivate(String listId) {
    final idx = _archived.indexWhere((l) => l.id == listId);
    if (idx < 0) return false;
    final list = _archived.removeAt(idx);
    list.completedAt = null;
    _active.insert(0, list);
    _markDirty();
    return true;
  }

  bool deleteActive(String listId) {
    final idx = _active.indexWhere((l) => l.id == listId);
    if (idx < 0) return false;
    _active.removeAt(idx);
    _markDirty();
    return true;
  }

  bool deleteArchived(String listId) {
    final idx = _archived.indexWhere((l) => l.id == listId);
    if (idx < 0) return false;
    _archived.removeAt(idx);
    _markDirty();
    return true;
  }

  bool setChecked(String listId, String itemId, bool checked) {
    final l = getActiveById(listId) ?? getArchivedById(listId);
    if (l == null) return false;
    final idx = l.items.indexWhere((e) => e.id == itemId);
    if (idx < 0) return false;
    l.items[idx].checked = checked;
    _markDirty();
    return true;
  }

  void upsertItem(String listId, GroceryListItem item) {
    final l = getActiveById(listId) ?? getArchivedById(listId);
    if (l == null) return;

    final idx = l.items.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      l.items[idx] = item;
      _markDirty();
      return;
    }

    _addOrAggregate(l.items, item);
    _markDirty();
  }

  bool deleteItem(String listId, String itemId) {
    final l = getActiveById(listId) ?? getArchivedById(listId);
    if (l == null) return false;
    final idx = l.items.indexWhere((e) => e.id == itemId);
    if (idx < 0) return false;
    l.items.removeAt(idx);
    _markDirty();
    return true;
  }

  GroceryListTemplate createTemplateFromList(GroceryList list, {String? templateName}) {
    final tName = (templateName == null || templateName.trim().isEmpty) ? '${list.name} Template' : templateName.trim();
    final t = GroceryListTemplate(
      name: tName,
      items: list.items.map((e) => e.copy()).toList(),
    );
    _templates.insert(0, t);
    _markDirty();
    return t;
  }

  GroceryList createListFromTemplate(GroceryListTemplate template, {String? nameOverride}) {
    final list = createNewList(name: nameOverride ?? template.name);
    list.items
      ..clear()
      ..addAll(template.items.map((e) => e.copy()).toList());
    _markDirty(); // ensure persisted with template items, too
    return list;
  }

  bool deleteTemplate(String templateId) {
    final idx = _templates.indexWhere((t) => t.id == templateId);
    if (idx < 0) return false;
    _templates.removeAt(idx);
    _markDirty();
    return true;
  }

  Future<void> resetToDefault({bool deleteFile = false}) async {
    await ready;

    _saveDebounce?.cancel();

    _active.clear();
    _archived.clear();
    _templates.clear();
    _nextListNumber = 1;

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
  void replaceFromCloud({
    required List<GroceryList> active,
    required List<GroceryList> archived,
    required List<GroceryListTemplate> templates,
    int? nextListNumber,
    bool markDirty = false,
  }) {
    _active
      ..clear()
      ..addAll(active);

    _archived
      ..clear()
      ..addAll(archived);

    _templates
      ..clear()
      ..addAll(templates);

    if (nextListNumber != null) {
      _nextListNumber = nextListNumber;
    }

    if (markDirty) {
      _markDirty();
    }
  }

  Map<String, dynamic> toJson() => {
    'active': _active.map((e) => e.toJson()).toList(),
    'archived': _archived.map((e) => e.toJson()).toList(),
    'templates': _templates.map((e) => e.toJson()).toList(),
    'nextListNumber': _nextListNumber,
  };

  static GroceryListStore fromJson(Map<String, dynamic> j) {
    final s = GroceryListStore();
    if (j['nextListNumber'] is int) s._nextListNumber = j['nextListNumber'] as int;

    final a = j['active'];
    if (a is List) {
      for (final x in a) {
        s._active.add(GroceryList.fromJson(Map<String, dynamic>.from(x as Map)));
      }
    }

    final ar = j['archived'];
    if (ar is List) {
      for (final x in ar) {
        s._archived.add(GroceryList.fromJson(Map<String, dynamic>.from(x as Map)));
      }
    }

    final t = j['templates'];
    if (t is List) {
      for (final x in t) {
        s._templates.add(GroceryListTemplate.fromJson(Map<String, dynamic>.from(x as Map)));
      }
    }

    return s;
  }


  void _addOrAggregate(List<GroceryListItem> items, GroceryListItem incoming) {
    final inName = _norm(incoming.ingredientName);

    final matches = <GroceryListItem>[];
    for (final it in items) {
      if (_norm(it.ingredientName) != inName) continue;
      if (!_sameTag(it, incoming)) continue;

      if (_unitsMatchOrConvertible(it.unit, incoming.unit)) {
        matches.add(it);
      }
    }

    if (matches.isEmpty) {
      items.add(incoming);
      return;
    }

    final targetUnit = _chooseTargetUnit(matches, incoming.unit);

    final agg = matches.first;

    _foldInto(agg, incoming, targetUnit);

    for (final extra in matches.skip(1).toList()) {
      items.remove(extra);
      _foldInto(agg, extra, targetUnit);
    }
  }

  void _foldInto(GroceryListItem agg, GroceryListItem other, String targetUnit) {
    final aggQty = _parseQuantity(agg.quantity);
    final otherQty = _parseQuantity(other.quantity);

    final canConvertAgg = _canConvertTo(agg.unit, targetUnit);
    final canConvertOther = _canConvertTo(other.unit, targetUnit);

    final aggIsEmpty = agg.quantity.trim().isEmpty;
    final otherIsEmpty = other.quantity.trim().isEmpty;

    final canNumeric =
        (aggQty != null || aggIsEmpty) && (otherQty != null || otherIsEmpty) && canConvertAgg && canConvertOther;

    if (canNumeric) {
      final aggVal = (aggQty ?? 0.0) * _factorOrOne(agg.unit, targetUnit);
      final otherVal = (otherQty ?? 0.0) * _factorOrOne(other.unit, targetUnit);
      final sum = aggVal + otherVal;

      agg.quantity = _formatNumber(sum);
      agg.unit = targetUnit;
    } else {
      final a = agg.quantity.trim();
      final b = other.quantity.trim();

      if (a.isEmpty) {
        agg.quantity = other.quantity;
      } else if (b.isNotEmpty) {
        agg.quantity = '$a + $b';
      }

      if (agg.unit.trim().isEmpty && targetUnit.trim().isNotEmpty) {
        agg.unit = targetUnit;
      }
    }

    agg.checked = agg.checked && other.checked;

    if (agg.store.trim().isEmpty && other.store.trim().isNotEmpty) {
      agg.store = other.store.trim();
    }
  }

  String _chooseTargetUnit(List<GroceryListItem> matches, String incomingUnit) {
    final counts = <String, int>{};

    for (final it in matches) {
      final u = it.unit.trim();
      if (u.isEmpty) continue;
      counts[u] = (counts[u] ?? 0) + 1;
    }

    if (counts.isNotEmpty) {
      final common = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      final commonUnit = common.first.key;

      if (_canConvertTo(incomingUnit, commonUnit)) return commonUnit;
    }

    final units = <String>{
      ...matches.map((e) => e.unit.trim()).where((u) => u.isNotEmpty),
      incomingUnit.trim(),
    }..removeWhere((u) => u.isEmpty);

    if (units.isEmpty) return '';

    var best = units.first;
    for (final u in units.skip(1)) {
      best = _biggerUnit(best, u);
    }
    return best;
  }

  String _biggerUnit(String a, String b) {
    if (a.trim().isEmpty) return b;
    if (b.trim().isEmpty) return a;
    if (a.trim().toLowerCase() == b.trim().toLowerCase()) return a;

    final fAB = _factor(a, b); // 1 a = fAB * b
    final fBA = _factor(b, a); // 1 b = fBA * a

    if (fAB == null || fBA == null) {
      return a;
    }

    return (fAB > 1.0) ? a : b;
  }

  bool _unitsMatchOrConvertible(String unitA, String unitB) {
    final a = unitA.trim();
    final b = unitB.trim();
    if (a.isEmpty && b.isEmpty) return true;
    if (a.toLowerCase() == b.toLowerCase()) return true;
    return _factor(a, b) != null || _factor(b, a) != null;
  }

  bool _canConvertTo(String from, String to) {
    final f = from.trim();
    final t = to.trim();
    if (t.isEmpty) return f.isEmpty; // only "convert" to empty if also empty
    if (f.isEmpty) return false; // can't convert empty -> real unit
    if (f.toLowerCase() == t.toLowerCase()) return true;
    return _factor(f, t) != null;
  }

  double _factorOrOne(String from, String to) {
    final f = from.trim();
    final t = to.trim();
    if (f.isEmpty || t.isEmpty) return 1.0;
    if (f.toLowerCase() == t.toLowerCase()) return 1.0;
    return _factor(f, t) ?? 1.0;
  }

  double? _factor(String from, String to) {
    final f = from.trim();
    final t = to.trim();
    if (f.isEmpty || t.isEmpty) return null;
    if (f.toLowerCase() == t.toLowerCase()) return 1.0;

    final fromM = measurementStore.getOrCreate(f);

    for (final rel in fromM.relations) {
      if (rel.m.unit.trim().toLowerCase() == t.toLowerCase()) {
        return rel.ratio;
      }
    }
    return null;
  }

  bool _sameTag(GroceryListItem a, GroceryListItem b) {
    return a.tagIsCustom == b.tagIsCustom &&
        _norm(a.tagName) == _norm(b.tagName) &&
        a.tagEmoji.trim() == b.tagEmoji.trim();
  }

  String _norm(String s) => s.trim().toLowerCase();


  double? _parseQuantity(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    final parts = s.split(RegExp(r'\s+'));
    if (parts.length == 2 && parts[1].contains('/')) {
      final whole = double.tryParse(parts[0]);
      final frac = _parseFraction(parts[1]);
      if (whole != null && frac != null) return whole + frac;
    }

    if (s.contains('/')) {
      final frac = _parseFraction(s);
      if (frac != null) return frac;
    }

    return double.tryParse(s);
  }

  double? _parseFraction(String s) {
    final p = s.split('/');
    if (p.length != 2) return null;
    final n = double.tryParse(p[0].trim());
    final d = double.tryParse(p[1].trim());
    if (n == null || d == null || d == 0) return null;
    return n / d;
  }

  String _formatNumber(double v) {
    final asInt = v.round();
    if ((v - asInt).abs() < 1e-9) return asInt.toString();

    var s = v.toStringAsFixed(3);
    s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return s;
  }
}
