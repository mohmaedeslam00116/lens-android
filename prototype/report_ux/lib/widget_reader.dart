/// Option A — widget-based reader: a mini block parser renders the markdown
/// as native Flutter widgets; citation pills are inline tappable widgets.
library;

import 'package:flutter/material.dart';

import 'data.dart';

/// Minimal block parser good enough for the sample: headings, paragraphs,
/// blockquote callouts, tables, ordered list. No inline markdown except
/// citation pills + bold markers (throwaway fidelity).
List<Block> parseBlocks(String md) {
  final lines = md.split('\n');
  final blocks = <Block>[];
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    if (line.trim().isEmpty) {
      i++;
      continue;
    }
    if (line.startsWith('# ')) {
      blocks.add(Block(type: BlockType.h1, text: line.substring(2)));
      i++;
    } else if (line.startsWith('## ')) {
      blocks.add(Block(type: BlockType.h2, text: line.substring(3)));
      i++;
    } else if (line.startsWith('> ')) {
      final buf = <String>[];
      while (i < lines.length && lines[i].startsWith('> ')) {
        buf.add(lines[i].substring(2));
        i++;
      }
      blocks.add(Block(type: BlockType.callout, text: buf.join(' ')));
    } else if (line.startsWith('|')) {
      final rows = <List<String>>[];
      while (i < lines.length && lines[i].startsWith('|')) {
        final cells =
            lines[i].split('|').map((c) => c.trim()).where((c) => c.isNotEmpty && c != '---').toList();
        if (cells.length >= 2) rows.add(cells);
        i++;
      }
      blocks.add(Block(type: BlockType.table, cells: rows));
    } else if (RegExp(r'^\d+\. ').hasMatch(line)) {
      final buf = <String>[];
      while (i < lines.length && RegExp(r'^\d+\. ').hasMatch(lines[i])) {
        buf.add(lines[i].replaceFirst(RegExp(r'^\d+\. '), ''));
        i++;
      }
      blocks.add(Block(type: BlockType.sources, items: buf));
    } else {
      final buf = <String>[];
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !lines[i].startsWith('#') &&
          !lines[i].startsWith('>') &&
          !lines[i].startsWith('|') &&
          !RegExp(r'^\d+\. ').hasMatch(lines[i])) {
        buf.add(lines[i]);
        i++;
      }
      blocks.add(Block(type: BlockType.para, text: buf.join(' ')));
    }
  }
  return blocks;
}

enum BlockType { h1, h2, para, callout, table, sources }

class Block {
  Block({required this.type, this.text, this.cells, this.items});

  final BlockType type;
  final String? text;
  final List<List<String>>? cells;
  final List<String>? items;
}

class WidgetReader extends StatelessWidget {
  const WidgetReader({super.key, required this.onPillTap});

  final void Function(int index) onPillTap;

  @override
  Widget build(BuildContext context) {
    final blocks = parseBlocks(sampleReportMd);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: blocks.length,
      itemBuilder: (context, i) {
        final b = blocks[i];
        switch (b.type) {
          case BlockType.h1:
            return Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 12),
              child: Text(b.text!,
                  style: Theme.of(context).textTheme.headlineMedium),
            );
          case BlockType.h2:
            return Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              child: Text(b.text!,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600)),
            );
          case BlockType.para:
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: RichText(
                text: _spans(context, b.text!),
              ),
            );
          case BlockType.callout:
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: RichText(text: _spans(context, b.text!)),
            );
          case BlockType.table:
            final rows = b.cells!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Table(
                  defaultColumnWidth: const IntrinsicColumnWidth(),
                  border: TableBorder.all(color: Colors.grey.shade400),
                  children: [
                    for (var r = 0; r < rows.length; r++)
                      TableRow(
                        decoration: r == 0
                            ? BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest)
                            : null,
                        children: [
                          for (final c in rows[r])
                            Padding(
                              padding: const EdgeInsets.all(6),
                              child: RichText(text: _spans(context, c)),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            );
          case BlockType.sources:
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var s = 0; s < b.items!.length; s++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${s + 1}. ${b.items![s]}',
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                ],
              ),
            );
        }
      },
    );
  }

  /// Inline spans: citation pills `[n]` → tappable widget spans; `**bold**`.
  InlineSpan _spans(BuildContext context, String text) {
    final children = <InlineSpan>[];
    final regex = RegExp(r'\[(\d{1,2})\]|\*\*(.+?)\*\*');
    var last = 0;
    for (final m in regex.allMatches(text)) {
      if (m.start > last) {
        children.add(TextSpan(text: text.substring(last, m.start)));
      }
      if (m.group(1) != null) {
        final n = int.parse(m.group(1)!);
        children.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            onTap: () => onPillTap(n),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$n',
                  style: Theme.of(context).textTheme.labelSmall),
            ),
          ),
        ));
      } else {
        children.add(TextSpan(
            text: m.group(2),
            style: const TextStyle(fontWeight: FontWeight.w700)));
      }
      last = m.end;
    }
    if (last < text.length) {
      children.add(TextSpan(text: text.substring(last)));
    }
    return TextSpan(
      style: Theme.of(context).textTheme.bodyLarge,
      children: children,
    );
  }
}
