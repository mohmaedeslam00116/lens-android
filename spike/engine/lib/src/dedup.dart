/// 3-level deduplication kernel — mirrors the desktop DeduplicationEngine:
/// L1 canonical URL normalization, L2 exact SHA-256 content hashing
/// (whitespace/case/punctuation invariant), L3 64-bit SimHash near-duplicate
/// detection with Hamming distance ≤ 3.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'tokenization.dart';

class DedupRecord {
  DedupRecord(this.url, this.content);

  final String url;
  final String content;
}

enum DedupVerdict { unique, duplicateUrl, duplicateContent, nearDuplicate }

class DedupDecision {
  DedupDecision(this.record, this.verdict, this.simhashHex, [this.matchedUrl]);

  final DedupRecord record;
  final DedupVerdict verdict;

  /// 64-bit SimHash as 16 hex chars. Empty string exactly when [verdict] is
  /// [DedupVerdict.duplicateUrl] or [DedupVerdict.duplicateContent] — those
  /// verdicts exit before the simhash is computed. The gold-vector schema
  /// pins this: `simhashHex: ""` on early-exit verdicts, hex otherwise.
  final String simhashHex;

  /// First-seen record's URL that this record duplicates; null when unique.
  final String? matchedUrl;
}

class DeduplicationEngine {
  final _seenUrls = <String, String>{}; // canonical -> first url
  final _seenHashes = <String, String>{}; // sha256 -> first url
  final _simhashes = <String, List<int>>{}; // url -> 64-bit words

  static String canonicalizeUrl(String url) {
    var u = url.trim().toLowerCase();
    final uri = Uri.tryParse(u);
    var host = uri?.host ?? '';
    if (host.startsWith('www.')) host = host.substring(4);
    var path = uri?.path ?? u;
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    final query = uri?.query ?? '';
    return query.isEmpty ? '$host$path' : '$host$path?$query';
  }

  /// Whitespace/case/punctuation-invariant SHA-256 of the content.
  static String contentHash(String content) {
    final normalized = content
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^\w\u0600-\u06FF\s]', unicode: true), '')
        .trim();
    return sha256.convert(utf8.encode(normalized)).toString();
  }

  /// 64-bit SimHash over the token stream (hash each token to 64 bits,
  /// sum weighted by sign, threshold at zero).
  static List<int> simhash64(List<String> tokens) {
    final v = List<int>.filled(64, 0);
    for (final token in tokens) {
      final h = _fingerprint(utf8.encode(token));
      for (var b = 0; b < 64; b++) {
        if ((h >> b) & 1 == 1) {
          v[b] += 1;
        } else {
          v[b] -= 1;
        }
      }
    }
    var bits = <int>[];
    for (var b = 0; b < 64; b++) {
      bits.add(v[b] > 0 ? 1 : 0);
    }
    return _packBits(bits);
  }

  /// Deterministic 64-bit fingerprint (two 32-bit halves from xfnv1a).
  static int _fingerprint(List<int> bytes) {
    var h1 = 0x811c9dc5, h2 = 0x1000193;
    for (final byte in bytes) {
      h1 ^= byte;
      h1 = (h1 * 0x01000193) & 0xFFFFFFFF;
      h2 = (h2 ^ byte << 5) & 0xFFFFFFFF;
      h2 = (h2 * 0x85ebca6b) & 0xFFFFFFFF;
    }
    return ((h1 & 0xFFFFFFFF) << 32) | (h2 & 0xFFFFFFFF);
  }

  static List<int> _packBits(List<int> bits) {
    final words = List<int>.filled(2, 0);
    for (var b = 0; b < 64; b++) {
      if (bits[b] == 1) {
        if (b < 32) {
          words[0] |= 1 << b;
        } else {
          words[1] |= 1 << (b - 32);
        }
      }
    }
    return words;
  }

  static int hammingDistance(List<int> a, List<int> b) {
    var d = 0;
    for (var w = 0; w < 2; w++) {
      var x = a[w] ^ b[w];
      while (x != 0) {
        d += x & 1;
        x >>= 1;
      }
    }
    return d;
  }

  DedupDecision decide(DedupRecord record) {
    final canon = canonicalizeUrl(record.url);
    if (_seenUrls.containsKey(canon)) {
      return DedupDecision(record, DedupVerdict.duplicateUrl, '', _seenUrls[canon]);
    }
    final hash = contentHash(record.content);
    if (_seenHashes.containsKey(hash)) {
      return DedupDecision(
          record, DedupVerdict.duplicateContent, hash, _seenHashes[hash]);
    }
    final tokens = analyze(record.content);
    final sh = simhash64(tokens);
    for (final entry in _simhashes.entries) {
      if (hammingDistance(sh, entry.value) <= 3) {
        return DedupDecision(
            record, DedupVerdict.nearDuplicate, _toHex(sh), entry.key);
      }
    }
    _seenUrls[canon] = record.url;
    _seenHashes[hash] = record.url;
    _simhashes[record.url] = sh;
    return DedupDecision(record, DedupVerdict.unique, _toHex(sh));
  }

  static String _toHex(List<int> words) =>
      words.map((w) => w.toRadixString(16).padLeft(8, '0')).join();
}
