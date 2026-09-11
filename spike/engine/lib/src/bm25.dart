/// Okapi BM25 lexical index — kernel under parity test.
///
/// Parameters mirror the desktop BM25Index: k1 = 1.2, b = 0.75, and the
/// Robertson–Spärck Jones IDF variant. The exact IDF formula is pinned by
/// the gold vectors generated from the desktop TypeScript engine.
library;

import 'dart:math' as math;

import 'tokenization.dart';

class Bm25Document {
  Bm25Document(this.id, this.text);

  final String id;
  final String text;
}

class Bm25Result {
  Bm25Result(this.docId, this.score);

  final String docId;
  final double score;
}

class Bm25Index {
  Bm25Index({this.k1 = 1.2, this.b = 0.75});

  final double k1;
  final double b;

  final Map<String, List<String>> _docTerms = {};
  final Map<String, Map<String, int>> _docTermFreqs = {};
  final Map<String, int> _docLengths = {};
  final Map<String, int> _documentFrequency = {};
  double _avgDocLength = 0;

  int get documentCount => _docTerms.length;
  double get avgDocLength => _avgDocLength;

  void addDocument(Bm25Document doc) {
    final terms = analyze(doc.text);
    _docTerms[doc.id] = terms;
    _docLengths[doc.id] = terms.length;
    final freqs = <String, int>{};
    for (final t in terms) {
      freqs[t] = (freqs[t] ?? 0) + 1;
    }
    _docTermFreqs[doc.id] = freqs;
    for (final term in freqs.keys) {
      _documentFrequency[term] = (_documentFrequency[term] ?? 0) + 1;
    }
  }

  void addDocuments(Iterable<Bm25Document> docs) {
    for (final d in docs) {
      addDocument(d);
    }
  }

  void build() {
    if (_docLengths.isEmpty) {
      _avgDocLength = 0;
      return;
    }
    var total = 0;
    for (final l in _docLengths.values) {
      total += l;
    }
    _avgDocLength = total / _docLengths.length;
  }

  /// Robertson–Spärck Jones IDF with the desktop's +1 floor guard.
  double idf(String term) {
    final n = _docTerms.length;
    final df = _documentFrequency[term] ?? 0;
    if (n == 0 || df == 0) return 0;
    final raw = math.log((n - df + 0.5) / (df + 0.5) + 1);
    return raw;
  }

  List<Bm25Result> search(String query, {int topK = 10}) {
    final queryTerms = analyze(query);
    if (queryTerms.isEmpty || _docTermFreqs.isEmpty) return const [];

    final scores = <String, double>{};
    for (final entry in _docTermFreqs.entries) {
      final docId = entry.key;
      final freqs = entry.value;
      final docLen = _docLengths[docId] ?? 0;
      if (docLen == 0) continue;
      var score = 0.0;
      for (final term in queryTerms) {
        final tf = freqs[term];
        if (tf == null || tf == 0) continue;
        final tfNorm =
            (tf * (k1 + 1)) / (tf + k1 * (1 - b + b * (docLen / _avgDocLength)));
        score += idf(term) * tfNorm;
      }
      if (score > 0) scores[docId] = score;
    }

    final results =
        scores.entries.map((e) => Bm25Result(e.key, e.value)).toList()
          ..sort((a, b2) {
            final cmp = b2.score.compareTo(a.score);
            if (cmp != 0) return cmp;
            return a.docId.compareTo(b2.docId);
          });
    if (results.length > topK) {
      return results.sublist(0, topK);
    }
    return results;
  }
}
