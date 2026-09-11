/// Option B — WebView-hosted reader: the same markdown converted to HTML with
/// GFM tables + citation pills; a JS bridge routes pill taps back to Flutter.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'data.dart';

class WebViewReader extends StatefulWidget {
  const WebViewReader({super.key, required this.onPillTap});

  final void Function(int index) onPillTap;

  @override
  State<WebViewReader> createState() => _WebViewReaderState();
}

class _WebViewReaderState extends State<WebViewReader> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }
    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'LensPills',
        onMessageReceived: (m) {
          final n = int.tryParse(m.message);
          if (n != null) widget.onPillTap(n);
        },
      )
      ..loadHtmlString(_html);
  }

  String get _html {
    final body = mdToHtml(sampleReportMd);
    return '''<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  body { font-family: -apple-system, 'Segoe UI', Tahoma, sans-serif;
         padding: 16px; color: #111; background: #fff; }
  h1 { font-size: 1.6rem; margin: 0.4em 0; }
  h2 { font-size: 1.2rem; margin: 1.2em 0 0.5em; }
  p  { line-height: 1.55; margin: 0 0 0.9em; }
  blockquote { margin: 0 0 1em; padding: 10px 14px; background: #f2f4f7;
               border-inline-start: 3px solid #888; border-radius: 6px; }
  table { border-collapse: collapse; width: 100%; margin-bottom: 1em;
          font-size: 0.9rem; display: block; overflow-x: auto; }
  th, td { border: 1px solid #ccc; padding: 6px 10px; text-align: start; }
  th { background: #f2f4f7; }
  ol { padding-inline-start: 1.4em; font-size: 0.85rem; color: #444; }
  .pill { display: inline-block; min-width: 1.5em; text-align: center;
          padding: 0 6px; margin: 0 2px; border-radius: 10px;
          background: #e3e8ff; color: #1d3ad6; cursor: pointer;
          font-size: 0.8em; line-height: 1.6; }
  [dir=rtl] body, body[dir=rtl] { direction: rtl; }
</style>
</head>
<body>$body</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }
}

/// Markdown → HTML good enough for the sample: headings, paragraphs, GFM
/// tables, blockquotes, ordered lists, and pill-wrapped citations.
String mdToHtml(String md) {
  final out = StringBuffer();
  final lines = md.split('\n');
  var i = 0;
  String inline(String s) {
    s = s.replaceAllMapped(RegExp(r'\[(\d{1,2})\]'), (m) {
      final n = int.parse(m.group(1)!);
      return '<span class="pill" onclick="LensPills.postMessage(\'$n\')">$n</span>';
    });
    s = s.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => '<b>${m.group(1)}</b>');
    return s;
  }

  while (i < lines.length) {
    final line = lines[i];
    if (line.trim().isEmpty) {
      i++;
      continue;
    }
    if (line.startsWith('# ')) {
      out.writeln('<h1>${inline(esc(line.substring(2)))}</h1>');
      i++;
    } else if (line.startsWith('## ')) {
      out.writeln('<h2 id="${Uri.encodeComponent(line.substring(3).trim())}">${inline(esc(line.substring(3)))}</h2>');
      i++;
    } else if (line.startsWith('> ')) {
      final buf = <String>[];
      while (i < lines.length && lines[i].startsWith('> ')) {
        buf.add(esc(lines[i].substring(2)));
        i++;
      }
      out.writeln('<blockquote>${inline(buf.join(' '))}</blockquote>');
    } else if (line.startsWith('|')) {
      final rows = <List<String>>[];
      while (i < lines.length && lines[i].startsWith('|')) {
        final cells = lines[i]
            .split('|')
            .map((c) => c.trim())
            .where((c) => c.isNotEmpty && !c.startsWith('---'))
            .toList();
        if (cells.length >= 2) rows.add(cells);
        i++;
      }
      out.writeln('<table>');
      for (var r = 0; r < rows.length; r++) {
        final tag = r == 0 ? 'th' : 'td';
        out.writeln('<tr>${rows[r].map((c) => '<$tag>${inline(esc(c))}</$tag>').join()}</tr>');
      }
      out.writeln('</table>');
    } else if (RegExp(r'^\d+\. ').hasMatch(line)) {
      out.writeln('<ol>');
      while (i < lines.length && RegExp(r'^\d+\. ').hasMatch(lines[i])) {
        out.writeln('<li>${esc(lines[i].replaceFirst(RegExp(r'^\d+\. '), ''))}</li>');
        i++;
      }
      out.writeln('</ol>');
    } else {
      final buf = <String>[];
      while (i < lines.length &&
          lines[i].trim().isNotEmpty &&
          !lines[i].startsWith('#') &&
          !lines[i].startsWith('>') &&
          !lines[i].startsWith('|') &&
          !RegExp(r'^\d+\. ').hasMatch(lines[i])) {
        buf.add(esc(lines[i]));
        i++;
      }
      out.writeln('<p>${inline(buf.join(' '))}</p>');
    }
  }
  return out.toString();
}

String esc(String s) => htmlEscape.convert(s);
