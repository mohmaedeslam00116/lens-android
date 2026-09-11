/// Deterministic corpus generator for the spike — no network, no fixtures
/// needed to run the harness. 500 bilingual documents, skewed lengths,
/// Arabic and English mixed, controlled term overlap so BM25 has signal.
library;

import 'bm25.dart';

const int corpusSize = 500;

const List<String> _arabicTopics = [
  'الذكاء الاصطناعي',
  'الأسواق المالية',
  'تغير المناخ',
  'الطب الحيوي',
  'الشبكات العصبية',
  'الاقتصاد الرقمي',
];

const List<String> _englishTopics = [
  'artificial intelligence',
  'financial markets',
  'climate change',
  'biomedical research',
  'neural networks',
  'digital economy',
];

const List<String> _arabicFiller = [
  'تشير الدراسات إلى أن تطور هذه التقنية يفتح آفاقا جديدة',
  'وفي تقرير حديث ناقش الباحثون آثار هذا التطور على المجتمع',
  'ويعتمد هذا المجال على بيانات ضخمة وخوارزميات متقدمة',
  'ومن المتوقع أن تتسارع وتيرة الابتكار في السنوات القادمة',
  'وأوضح الخبراء أن التحديات القانونية والأخلاقية لا تزال قائمة',
];

const List<String> _englishFiller = [
  'recent studies suggest the technology opens new frontiers for research',
  'a detailed report discussed the societal impact of this development',
  'the field relies on large datasets and advanced algorithmic methods',
  'analysts expect the pace of innovation to accelerate in coming years',
  'experts noted that legal and ethical challenges remain unresolved',
];

String _filler(int i, int seed, bool arabic) {
  final list = arabic ? _arabicFiller : _englishFiller;
  return list[(seed + i * 7) % list.length];
}

/// Deterministic LCG so every run — and every device — sees the same corpus.
int _nextSeed(int seed) => (seed * 1103515245 + 12345) & 0x7fffffff;

List<Bm25Document> generateCorpus({int size = corpusSize, int seed = 42}) {
  var s = seed;
  final docs = <Bm25Document>[];
  for (var i = 0; i < size; i++) {
    s = _nextSeed(s);
    final topicIdx = s % _englishTopics.length;
    s = _nextSeed(s);
    final lengthSeed = s % 5; // skewed lengths
    final arabic = i.isOdd;
    final topic = arabic ? _arabicTopics[topicIdx] : _englishTopics[topicIdx];

    final parts = <String>[];
    var wordCount = 20 + lengthSeed * 45 + (i % 30);
    var j = 0;
    while (wordCount > 0) {
      final f = _filler(j, s, arabic);
      parts.add(f);
      wordCount -= f.split(' ').length;
      j++;
      if (j % 4 == 0) parts.add(topic);
    }
    parts.add(topic); // ensure the topic term exists
    docs.add(Bm25Document('doc-$i', parts.join('. ')));
  }
  return docs;
}

/// The six fixed queries (3 EN, 3 AR) the harness benchmarks.
const List<String> benchmarkQueries = [
  'artificial intelligence research',
  'climate change impact',
  'financial markets analysis',
  'الذكاء الاصطناعي والتعلم العميق',
  'تغير المناخ والبيئة',
  'الأسواق المالية والاقتصاد الرقمي',
];
