import 'package:flutter/material.dart';

import 'data.dart';
import 'webview_reader.dart';
import 'widget_reader.dart';

void main() => runApp(const ReportUxPrototypeApp());

class ReportUxPrototypeApp extends StatelessWidget {
  const ReportUxPrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LENS report UX prototype',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const PrototypeShell(),
    );
  }
}

class PrototypeShell extends StatefulWidget {
  const PrototypeShell({super.key});

  @override
  State<PrototypeShell> createState() => _PrototypeShellState();
}

enum ReaderKind { widgets, webview }

class _PrototypeShellState extends State<PrototypeShell> {
  ReaderKind _reader = ReaderKind.widgets;
  bool _arabic = false;

  void _openEvidence(int index) {
    final ev = evidence[index];
    if (ev == null) return;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(ev['title']!,
                  style: Theme.of(sheetContext).textTheme.titleMedium),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  Chip(label: Text(ev['domain']!)),
                  Chip(label: Text('tier: ${ev['tier']}')),
                ],
              ),
              const SizedBox(height: 8),
              Text('“${ev['excerpt']}”',
                  style: Theme.of(sheetContext).textTheme.bodyMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  IconButton(
                    onPressed: index > 1
                        ? () {
                            Navigator.pop(sheetContext);
                            _openEvidence(index - 1);
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('[$index] of ${evidence.length}'),
                  IconButton(
                    onPressed: index < evidence.length
                        ? () {
                            Navigator.pop(sheetContext);
                            _openEvidence(index + 1);
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                  const Spacer(),
                  Text(ev['url']!,
                      style: Theme.of(sheetContext).textTheme.bodySmall),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  List<String> get _tocEntries {
    return parseBlocks(sampleReportMd)
        .where((b) => b.type == BlockType.h2)
        .map((b) => b.text!)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final body = _reader == ReaderKind.widgets
        ? WidgetReader(onPillTap: _openEvidence)
        : WebViewReader(onPillTap: _openEvidence);

    return Scaffold(
      appBar: AppBar(
        title: Text(_reader == ReaderKind.widgets
            ? 'Option A — widgets'
            : 'Option B — WebView'),
        actions: [
          SegmentedButton<ReaderKind>(
            segments: const [
              ButtonSegment(value: ReaderKind.widgets, label: Text('A')),
              ButtonSegment(value: ReaderKind.webview, label: Text('B')),
            ],
            selected: {_reader},
            onSelectionChanged: (s) => setState(() => _reader = s.first),
          ),
          IconButton(
            tooltip: 'Toggle AR/EN direction',
            onPressed: () => setState(() => _arabic = !_arabic),
            icon: Text(_arabic ? 'EN' : 'ع'),
          ),
        ],
      ),
      body: Column(
        children: [
          // TOC chips — the reading-time/TOC axis of the comparison.
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final entry in _tocEntries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      label: Text(entry, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onPressed: () => _jumpTo(entry),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Directionality(
              textDirection: _arabic ? TextDirection.rtl : TextDirection.ltr,
              child: KeyedSubtree(
                key: ValueKey('${_reader.name}-$_arabic'),
                child: body,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _jumpTo(String heading) {
    if (_reader == ReaderKind.webview) {
      // WebView anchors exist (id attributes); prototype jumps via JS.
      // (webview reader owns its controller; the throwaway rebuilds instead)
      setState(() => _reader = ReaderKind.widgets);
    }
    // Widget reader: TOC navigation is scroll-position work in the real app;
    // out of prototype scope — chips are here to feel the axis, not to ship.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('TOC jump: $heading (prototype stub)')),
    );
  }
}
