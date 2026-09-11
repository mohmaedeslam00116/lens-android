import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_js/flutter_js.dart';

import 'src/bm25.dart';
import 'src/citation_sse.dart';
import 'src/corpus.dart';
import 'src/dedup.dart';

void main() => runApp(const SpikeApp());

class SpikeApp extends StatelessWidget {
  const SpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LENS engine spike',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HarnessPage(),
    );
  }
}

class HarnessPage extends StatefulWidget {
  const HarnessPage({super.key});

  @override
  State<HarnessPage> createState() => _HarnessPageState();
}

class _HarnessPageState extends State<HarnessPage> {
  final List<String> _log = [];

  Future<void> _runBm25() => _asyncRun('BM25 build+search', () async {
        final docs = generateCorpus();
        final index = Bm25Index();
        final sw = Stopwatch()..start();
        for (final d in docs) {
          index.addDocument(d);
        }
        index.build();
        final buildMs = sw.elapsedMilliseconds;
        var note = StringBuffer('build=${buildMs}ms');
        for (final q in benchmarkQueries) {
          final res = index.search(q, topK: 10);
          note.write(' | "${q.length > 18 ? q.substring(0, 18) : q}"→${res.length}');
        }
        return note.toString();
      });

  Future<void> _runDedup() => _asyncRun('Dedup 3-level', () async {
        final docs = generateCorpus(size: 200);
        final engine = DeduplicationEngine();
        var unique = 0, near = 0, dup = 0;
        final sw = Stopwatch()..start();
        for (var i = 0; i < docs.length; i++) {
          final d = docs[i];
          final decision = engine.decide(DedupRecord('https://example.org/$i', d.text));
          switch (decision.verdict) {
            case DedupVerdict.unique:
              unique++;
            case DedupVerdict.nearDuplicate:
              near++;
            default:
              dup++;
          }
        }
        sw.stop();
        return 'n=${docs.length} unique=$unique near=$near dup=$dup';
      });

  Future<void> _runCitation() => _asyncRun('Citation grounding', () async {
        final docs = generateCorpus(size: 50);
        final sources = [for (final d in docs) CitedSource(d.id, d.text)];
        final contract = CitationGroundingContract();
        final sw = Stopwatch()..start();
        final assignments = contract.preallocate(sources);
        const draft = '''
الخلاصة التنفيذية: النتائج تدعم الفرضية [1] وتتناقض مع [2].
Executive summary: evidence supports [1], contradicts [49], and hallucinates [51] and [999].
''';
        final cleaned = contract.verifyAndClean(draft, assignments.length);
        sw.stop();
        return 'kept=${RegExp(r'\[\d+\]').allMatches(cleaned).length} of ${RegExp(r'\[\d+\]').allMatches(draft).length}';
      });

  /// Assembles the identical workloads (same corpus bytes) for the JS twin:
  /// the QuickJS side measures the interpreter tax on matched inputs.
  String _quickJsCorpusJson() {
    final docs = generateCorpus();
    final dedupDocs = generateCorpus(size: 200);
    return jsonEncode({
      'docs': [for (final d in docs) {'id': d.id, 'text': d.text}],
      'queries': benchmarkQueries,
      'dedup': [for (var i = 0; i < dedupDocs.length; i++) {'url': 'https://example.org/$i', 'text': dedupDocs[i].text}],
    });
  }

  Future<void> _runQuickJs() => _asyncRun('QuickJS twin (same workloads)', () async {
        final rt = getJavascriptRuntime();
        final twin = await rootBundle.loadString('assets/engine_twin.js');
        rt.evaluate(twin);
        final corpusJson = _quickJsCorpusJson();
        final result = rt.evaluate('bench(${jsonEncode(corpusJson)})');
        if (result.isError) {
          return 'ERROR: ${result.stringResult}';
        }
        return result.stringResult;
      });

  Future<void> _runSse() => _asyncRun('SSE parse + ring replay', () async {
        final parser = SseParser();
        final ring = EventRingBuffer<String>(300);
        final rnd = math.Random(7);
        final sw = Stopwatch()..start();
        for (var i = 0; i < 10000; i++) {
          final frame = 'event: telemetry\ndata: ${jsonEncode({'i': i, 'x': rnd.nextDouble()})}\n\n';
          parser.feed(frame);
          ring.push(frame);
        }
        sw.stop();
        final replay = ring.replaySince(ring.lastEventId - 50);
        return 'events=${parser.events.length} ringLast=${ring.lastEventId} replayed=${replay.length}';
      });

  Future<void> _asyncRun(String name, Future<String> Function() body) async {
    final sw = Stopwatch()..start();
    final note = await body();
    sw.stop();
    if (mounted) {
      setState(() => _log.insert(0, '$name: ${sw.elapsedMilliseconds} ms — $note'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('LENS engine spike — on-device harness')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(onPressed: _runBm25, child: const Text('BM25 (500 docs)')),
                FilledButton(onPressed: _runDedup, child: const Text('Dedup (200 docs)')),
                FilledButton(onPressed: _runCitation, child: const Text('Citation (50 src)')),
                FilledButton(onPressed: _runSse, child: const Text('SSE 10k events')),
                FilledButton(onPressed: _runQuickJs, child: const Text('QuickJS twin')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _log.length,
              itemBuilder: (context, i) => Text(_log[i],
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}
