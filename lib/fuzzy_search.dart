import 'dart:math';

List<T> fuzzySearch<T>(
    Iterable<T> items,
    String query,
    int nItems,
    double cutoff, {
      String Function(T item)? stringify,
    }) {
  if (nItems <= 0) return List<T>.empty(growable: false);

  String norm(String s) {
    final t = s.trim().toLowerCase();
    final sb = StringBuffer();
    for (int i = 0; i < t.length; i++) {
      final c = t.codeUnitAt(i);
      final isLower = (c >= 97 && c <= 122);
      final isDigit = (c >= 48 && c <= 57);
      if (isLower || isDigit) sb.writeCharCode(c);
    }
    return sb.toString();
  }

  Set<String> bigrams(String s) {
    if (s.isEmpty) return {};
    if (s.length < 2) return {s};
    final out = <String>{};
    for (int i = 0; i < s.length - 1; i++) {
      out.add(s.substring(i, i + 2));
    }
    return out;
  }

  double jaccard(Set<String> a, Set<String> b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final inter = a.intersection(b).length;
    final uni = a.union(b).length;
    return uni == 0 ? 0.0 : inter / uni;
  }

  int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final m = a.length, n = b.length;
    var prev = List<int>.generate(n + 1, (j) => j);
    var curr = List<int>.filled(n + 1, 0);

    for (int i = 1; i <= m; i++) {
      curr[0] = i;
      final ai = a.codeUnitAt(i - 1);
      for (int j = 1; j <= n; j++) {
        final cost = (ai == b.codeUnitAt(j - 1)) ? 0 : 1;
        final del = prev[j] + 1;
        final ins = curr[j - 1] + 1;
        final sub = prev[j - 1] + cost;
        curr[j] = min(del, min(ins, sub));
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }

  bool looksLikeAbbrevMatch(String qNorm, String candRaw) {
    if (qNorm.length < 2) return false;
    final raw = candRaw.trim().toLowerCase();
    int qi = 0;
    for (int ci = 0; ci < raw.length && qi < qNorm.length; ci++) {
      if (raw[ci] == qNorm[qi]) qi++;
    }
    return qi == qNorm.length;
  }

  double score(String queryNorm, String candidateRaw) {
    final candNorm = norm(candidateRaw);
    if (queryNorm.isEmpty || candNorm.isEmpty) return 0.0;
    if (queryNorm == candNorm) return 1.0;

    final maxLen = max(queryNorm.length, candNorm.length);
    final lev = levenshtein(queryNorm, candNorm);
    final levSim = 1.0 - (lev / maxLen);

    final jac = jaccard(bigrams(queryNorm), bigrams(candNorm));

    double bonus = 0.0;
    if (candNorm.startsWith(queryNorm) || queryNorm.startsWith(candNorm)) {
      bonus += 0.12;
    }
    if (candNorm.contains(queryNorm) || queryNorm.contains(candNorm)) {
      bonus += 0.08;
    }
    if (looksLikeAbbrevMatch(queryNorm, candidateRaw)) {
      bonus += 0.12;
    }

    var s = 0.65 * levSim + 0.35 * jac + bonus;
    if (s < 0.0) s = 0.0;
    if (s > 1.0) s = 1.0;
    return s;
  }

  final qNorm = norm(query);
  if (qNorm.isEmpty) {
    return items.take(nItems).toList(growable: false);
  }

  final toStr = stringify ?? (T item) => item.toString();

  final best = <_Hit<T>>[];

  for (final item in items) {
    final raw = toStr(item);
    final s = score(qNorm, raw);
    if (s < cutoff) continue;

    if (best.length < nItems) {
      best.add(_Hit(item, s));
      continue;
    }

    int worstIdx = 0;
    double worstScore = best[0].score;
    for (int i = 1; i < best.length; i++) {
      final bs = best[i].score;
      if (bs < worstScore) {
        worstScore = bs;
        worstIdx = i;
      }
    }

    if (s > worstScore) best[worstIdx] = _Hit(item, s);
  }

  best.sort((a, b) => b.score.compareTo(a.score));
  return best.map((h) => h.item).toList(growable: false);
}

class _Hit<T> {
  final T item;
  final double score;
  const _Hit(this.item, this.score);
}
