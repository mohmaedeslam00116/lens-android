/// Throwaway prototype data — one bilingual sample report + fake evidence.
/// The SAME markdown feeds both readers (widget parser and WebView HTML),
/// so the A/B comparison is honest.
library;

const sampleReportMd = '''
# Quantum Computing's Real State in 2026

## Executive Summary

Independent benchmarks disagree about fault-tolerant timelines [1] [2], while
error-correction results have broadly held up under replication [3]. The
market narrative outruns the lab evidence.

## Technical State

Superconducting transmons dominate current machines, while trapped-ion
platforms [2] hold fidelity records. Cryogenic control chips [3] cut wiring
complexity by an order of magnitude. ** Benchmarks differ fundamentally **
between vendor and independent suites [1].

## Market View

Funding concentrates in three platforms; revenue remains research-driven [1].
Talent competition is intense [2].

> [!NOTE] Strategic takeaway
> Independent benchmarks [1] are the trustworthy signal; vendor claims [2] [3] need discounting.

## الحالة الفنية (Arabic section)

تشير المعايير المستقلة إلى أن الحوسبة الكمومية ما تزال في مرحلة البحث [1]،
بينما تتفاوت الأرقام التجارية بشكل كبير [2]. التحدي الأكبر يبقى في تصحيح
الأخطاء الكمومية وقابلية التوسع [3].

## Comparison Matrix

| Platform | Qubits | Fidelity | Claim |
|---|---|---|---|
| Superconducting | 1121 | 99.5% | [1] |
| Trapped ion | 56 | 99.97% | [2] |
| Neutral atom | 200 | 99.2% | [3] |

## Sources

1. Independent benchmark consortium report — example.org/bench2026
2. Vendor fidelity disclosure — example.org/vendor
3. Cryo-control architecture paper — example.org/cryo
''';

const evidence = <int, Map<String, String>>{
  1: {
    'title': 'Independent benchmark consortium report',
    'domain': 'example.org',
    'url': 'https://example.org/bench2026',
    'tier': 'High',
    'excerpt':
        'Cross-validated benchmark suite across seven independent labs; fault-tolerant timelines spread 2029–2034.',
  },
  2: {
    'title': 'Vendor fidelity disclosure',
    'domain': 'vendor.example.com',
    'url': 'https://vendor.example.com/fidelity',
    'tier': 'Standard',
    'excerpt':
        'Vendor-reported fidelity under idealized calibration cycles; methodology not independently replicated.',
  },
  3: {
    'title': 'Cryo-control architecture paper',
    'domain': 'example.org',
    'url': 'https://example.org/cryo',
    'tier': 'High',
    'excerpt':
        'CMOS cryo-controller reduces wiring per qubit from 50 coax lines to a single digital link.',
  },
};
