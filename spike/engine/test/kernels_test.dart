import 'package:flutter_test/flutter_test.dart';
import 'package:lens_engine_spike/src/bm25.dart';
import 'package:lens_engine_spike/src/citation_sse.dart';
import 'package:lens_engine_spike/src/corpus.dart';
import 'package:lens_engine_spike/src/dedup.dart';
import 'package:lens_engine_spike/src/tokenization.dart';

void main() {
  group('tokenization (parity surface — exact output pinned)', () {
    test('arabic pipeline: diacritic strip → normalize → clitic stem', () {
      // الذكاءُ → strip diacritics → الذكاء → strip ال (length>4 kept) → ذكاء
      // الاصطناعيّ → الاصطناعي → strip ال → اصطناعي
      // الأسواق → الاسواق (أ→ا) → strip ال → اسواق
      expect(analyze('الذكاءُ الاصطناعيّ في الأسواق'),
          ['ذكاء', 'اصطناعي', 'في', 'اسواق']);
    });

    test('mixed AR/EN stream splits and stems in one pass', () {
      expect(analyze('Research الذكاء research'),
          ['research', 'ذكاء', 'research']);
    });

    test('clitic stemming never leaves a stem shorter than 3 chars', () {
      // بال data: `بالبيانات` strips ال from البيانات (remainder ≥ 3).
      expect(stemArabic(normalizeToken('البيانات')), 'بيانات');
      // الذي → stripping ال would leave ذي (2 chars < 3) → blocked.
      expect(stemArabic(normalizeToken('الذي')), 'الذي');
    });
  });

  group('bm25', () {
    test('ranks the on-topic doc first and is deterministic', () {
      final docs = [
        Bm25Document('a', 'climate change impact on agriculture'),
        Bm25Document('b', 'financial markets quarterly analysis'),
        Bm25Document('c', 'climate models and climate policy for climate resilience'),
      ];
      final index = Bm25Index()..addDocuments(docs)..build();
      final res = index.search('climate change', topK: 3);
      // BM25 saturation: one hit of EACH query term (doc a) outranks three
      // hits of a single query term (doc c); doc b has no hits and is excluded.
      expect(res.map((r) => r.docId).toList(), ['a', 'c']);
      final res2 = index.search('climate change', topK: 3);
      expect(res.map((r) => r.docId).toList(), res2.map((r) => r.docId).toList());
    });
  });

  group('dedup', () {
    test('L1 URL canonicalization collapses www and trailing slash', () {
      expect(
        DeduplicationEngine.canonicalizeUrl('https://WWW.Example.org/a/'),
        DeduplicationEngine.canonicalizeUrl('https://example.org/a'),
      );
    });

    test('L2 content hash is whitespace/case invariant', () {
      expect(
        DeduplicationEngine.contentHash('Hello  World!'),
        DeduplicationEngine.contentHash('hello world'),
      );
    });

    test('identical text at a new URL is a content duplicate', () {
      final engine = DeduplicationEngine();
      final d1 = engine.decide(DedupRecord('https://a.org/x', 'same content here'));
      final d2 = engine.decide(DedupRecord('https://b.org/y', 'same content here'));
      expect(d1.verdict, DedupVerdict.unique);
      expect(d2.verdict, DedupVerdict.duplicateContent);
    });
  });

  group('citation grounding', () {
    test('preallocation is 1-based and order-deterministic', () {
      final c = CitationGroundingContract();
      final a = c.preallocate([CitedSource('s2', ''), CitedSource('s1', '')]);
      expect(a.map((x) => x.index).toList(), [1, 2]);
      expect(a.first.sourceId, 's2');
    });

    test('strips unmapped brackets, keeps mapped ones', () {
      final c = CitationGroundingContract();
      final cleaned = c.verifyAndClean('keep [1] and [2], drop [3] and [99]', 2);
      expect(cleaned.contains('[1]'), isTrue);
      expect(cleaned.contains('[2]'), isTrue);
      expect(cleaned.contains('[3]'), isFalse);
      expect(cleaned.contains('[99]'), isFalse);
    });
  });

  group('sse + ring buffer', () {
    test('parser splits frames and honors [DONE]', () {
      final p = SseParser();
      p.feed('event: a\ndata: 1\n\n');
      p.feed('data: [DONE]\n\n');
      p.feed('event: b\ndata: 2\n\n');
      expect(p.events.length, 2);
      expect(p.events.last.data, '2');
    });

    test('ring buffer replay honors since= semantics', () {
      final ring = EventRingBuffer<int>(3);
      for (var i = 0; i < 5; i++) {
        ring.push(i);
      }
      expect(ring.lastEventId, 4);
      expect(ring.replaySince(2), [3, 4]);
      expect(ring.replaySince(0), [2, 3, 4]); // gap → full snapshot
    });
  });

  group('corpus', () {
    test('generator is deterministic across runs', () {
      final a = generateCorpus().map((d) => d.text).join();
      final b = generateCorpus().map((d) => d.text).join();
      expect(a, b);
    });
  });
}
