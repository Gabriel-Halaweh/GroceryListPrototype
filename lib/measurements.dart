import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MeasurementStore {
  final Map<String, Measurement> _byUnit = {};


  static const String _dataFolderName = 'Data';
  static const String _fileName = 'measurement_store.json';

  Timer? _saveDebounce;
  bool _loaded = false;

  late final Future<void> ready;

  MeasurementStore() {
    _seedPrefabs();
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

      _applyJson(decoded);

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


  Set<Measurement> get measurements => _byUnit.values.toSet();

  Measurement getOrCreate(String unit) {
    return _byUnit.putIfAbsent(unit, () {
      final m = Measurement(unit: unit);
      _markDirty();
      return m;
    });
  }

  void addRelation(String unitA, String unitB, double ratio) {
    if (ratio == 0) return;

    final a = _byUnit.containsKey(unitA) ? _byUnit[unitA]! : getOrCreate(unitA);
    final b = _byUnit.containsKey(unitB) ? _byUnit[unitB]! : getOrCreate(unitB);

    _upsertRelation(from: a, to: b, ratio: ratio);
    _upsertRelation(from: b, to: a, ratio: 1.0 / ratio);

    _rebuildAllClosures();
    _markDirty();
  }

  void deleteMeasurement(String unit) {
    final removed = _byUnit.remove(unit);
    if (removed == null) return;

    for (final m in _byUnit.values) {
      m.relations.removeWhere((rel) => rel.m == removed);
    }

    removed.relations.clear();
    _rebuildAllClosures();
    _markDirty();
  }


  Map<String, dynamic> toJSON() {
    return {
      'measurements': _byUnit.values.map((m) => m.toJSON()).toList(),
    };
  }

  static MeasurementStore fromJSON(Map<String, dynamic> json) {
    final store = MeasurementStore();

    store._loaded = false;
    store._applyJson(json);
    store._rebuildAllClosures();

    store._loaded = true;

    return store;
  }

  void _applyJson(Map<String, dynamic> json) {
    final list = (json['measurements'] as List? ?? []);

    for (final item in list) {
      final map = Map<String, dynamic>.from(item as Map);
      final unit = map['unit'] as String? ?? '';
      if (unit.isEmpty) continue;
      _byUnit.putIfAbsent(unit, () => Measurement(unit: unit));
    }

    for (final item in list) {
      final map = Map<String, dynamic>.from(item as Map);
      final unit = map['unit'] as String? ?? '';
      if (unit.isEmpty) continue;

      final from = _byUnit[unit] ?? Measurement(unit: unit);
      _byUnit[unit] = from;

      final rels = (map['relations'] as List? ?? []);
      for (final r in rels) {
        final rMap = Map<String, dynamic>.from(r as Map);
        final toUnit = rMap['unit'] as String? ?? '';
        final ratioNum = rMap['ratio'];

        if (toUnit.isEmpty) continue;

        final ratio = (ratioNum is num) ? ratioNum.toDouble() : 0.0;
        if (ratio == 0) continue;

        final to = _byUnit.putIfAbsent(toUnit, () => Measurement(unit: toUnit));
        _upsertRelation(from: from, to: to, ratio: ratio);
      }
    }

    _rebuildAllClosures();
  }


  void _seedPrefabs() {

    const units = [
      'tsp',
      'tbsp',
      'fl oz',
      'cup',
      'pt',
      'qt',
      'gal',
      'ml',
      'l',

      'mg',
      'g',
      'kg',
      'oz',
      'lb',
    ];

    for (final u in units) {
      _byUnit.putIfAbsent(u, () => Measurement(unit: u));
    }

    final rels = <_BaseRel>[
      _BaseRel('tbsp', 'tsp', 3.0), // 1 tbsp = 3 tsp
      _BaseRel('fl oz', 'tbsp', 2.0), // 1 fl oz = 2 tbsp
      _BaseRel('cup', 'fl oz', 8.0), // 1 cup = 8 fl oz
      _BaseRel('pt', 'cup', 2.0), // 1 pt = 2 cups
      _BaseRel('qt', 'pt', 2.0), // 1 qt = 2 pt
      _BaseRel('gal', 'qt', 4.0), // 1 gal = 4 qt

      _BaseRel('l', 'ml', 1000.0), // 1 l = 1000 ml

      _BaseRel('fl oz', 'ml', 29.5735295625),

      _BaseRel('g', 'mg', 1000.0), // 1 g = 1000 mg
      _BaseRel('kg', 'g', 1000.0), // 1 kg = 1000 g

      _BaseRel('lb', 'oz', 16.0), // 1 lb = 16 oz

      _BaseRel('oz', 'g', 28.349523125),
    ];

    _addRelationsBulk(rels);
  }

  void _addRelationsBulk(List<_BaseRel> rels) {
    for (final r in rels) {
      if (r.ratio == 0) continue;

      final a = _byUnit.putIfAbsent(r.unitA, () => Measurement(unit: r.unitA));
      final b = _byUnit.putIfAbsent(r.unitB, () => Measurement(unit: r.unitB));

      _upsertRelation(from: a, to: b, ratio: r.ratio);
      _upsertRelation(from: b, to: a, ratio: 1.0 / r.ratio);
    }

    _rebuildAllClosures();
  }


  void _upsertRelation({
    required Measurement from,
    required Measurement to,
    required double ratio,
  }) {
    from.relations.removeWhere((r) => r.m == to);
    from.relations.add(RatioRelation(m: to, ratio: ratio));
  }

  void _rebuildAllClosures() {
    for (final source in _byUnit.values) {
      final factors = _computeFactorsFrom(source);

      final newRelations = <RatioRelation>{};
      for (final entry in factors.entries) {
        final target = entry.key;
        final factor = entry.value;
        if (target == source) continue;
        newRelations.add(RatioRelation(m: target, ratio: factor));
      }
      source.relations = newRelations;
    }
  }

  Future<void> resetToDefault({bool deleteFile = false}) async {
    await ready;

    _saveDebounce?.cancel();

    _byUnit.clear();
    _seedPrefabs();

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

  Map<Measurement, double> _computeFactorsFrom(Measurement source) {
    final factors = <Measurement, double>{};
    final q = Queue<Measurement>();

    factors[source] = 1.0;
    q.add(source);

    while (q.isNotEmpty) {
      final current = q.removeFirst();
      final factorToCurrent = factors[current]!;

      for (final rel in current.relations) {
        final next = rel.m;
        final factorToNext = factorToCurrent * rel.ratio;

        if (!factors.containsKey(next)) {
          factors[next] = factorToNext;
          q.add(next);
        }
      }
    }

    return factors;
  }
}

class Measurement {
  String unit;
  Set<RatioRelation> relations;

  Measurement({
    required this.unit,
    Set<RatioRelation>? relations,
  }) : relations = relations ?? {};

  Map<String, dynamic> toJSON() => {
    'unit': unit,
    'relations': relations.map((r) => r.toJSON()).toList(),
  };


  @override
  bool operator ==(Object other) => identical(this, other) || (other is Measurement && other.unit == unit);

  @override
  int get hashCode => unit.hashCode;
}

class RatioRelation {
  Measurement m;
  double ratio;

  RatioRelation({
    required this.m,
    required this.ratio,
  });

  Map<String, dynamic> toJSON() => {
    'unit': m.unit,
    'ratio': ratio,
  };

  @override
  bool operator ==(Object other) => identical(this, other) || (other is RatioRelation && other.m == m);

  @override
  int get hashCode => m.hashCode;
}

class _BaseRel {
  final String unitA;
  final String unitB;
  final double ratio;

  const _BaseRel(this.unitA, this.unitB, this.ratio);
}
