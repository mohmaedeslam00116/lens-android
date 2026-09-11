/// Citation grounding kernel — mirrors the desktop CitationGroundingContract:
/// pre-allocated 1-based citation indices over admitted sources, then
/// post-synthesis verification that strips or remaps unmapped brackets.
library;

import 'dart:convert';

class CitedSource {
  CitedSource(this.id, this.snippet);

  final String id;
  final String snippet;
}

class CitationAssignment {
  CitationAssignment(this.sourceId, this.index);

  final String sourceId;
  final int index;
}

class CitationGroundingContract {
  /// Deterministic 1-based index pre-allocation in admission order.
  List<CitationAssignment> preallocate(List<CitedSource> sources) {
    return [for (var i = 0; i < sources.length; i++) CitationAssignment(sources[i].id, i + 1)];
  }

  /// Post-synthesis verification: keep only brackets whose number maps to a
  /// pre-allocated index; strip the rest. Mirrors the desktop's regex sweep.
  String verifyAndClean(String synthesizedText, int maxIndex) {
    return synthesizedText.replaceAllMapped(RegExp(r'\[(\d{1,3})\]'), (m) {
      final n = int.parse(m.group(1)!);
      return (n >= 1 && n <= maxIndex) ? m.group(0)! : '';
    });
  }
}

/// SSE frame model + deterministic parser mirroring the desktop's
/// stream parsing contract (event / data lines, [DONE] sentinel).
class SseEvent {
  SseEvent(this.event, this.data);

  final String event;
  final String data;
}

class SseParser {
  final _buffer = StringBuffer();
  final List<SseEvent> events = [];
  final List<int> eventIds = [];

  void feed(String chunk) {
    _buffer.write(chunk);
    final text = _buffer.toString();
    final frames = text.split('\n\n');
    // Keep the trailing (possibly incomplete) frame in the buffer.
    final complete = frames.length > 1 ? frames.sublist(0, frames.length - 1) : <String>[];
    _buffer
      ..clear()
      ..write(frames.isEmpty ? '' : frames.last);
    for (final frame in complete) {
      var event = '';
      final dataLines = <String>[];
      for (final rawLine in frame.split('\n')) {
        if (rawLine.startsWith('event:')) {
          event = rawLine.substring(6).trim();
        } else if (rawLine.startsWith('data:')) {
          dataLines.add(rawLine.substring(5).trim());
        }
      }
      final data = dataLines.join('\n');
      if (data == '[DONE]') continue;
      final e = SseEvent(event, data);
      events.add(e);
      eventIds.add(events.length);
    }
  }
}

/// Ring buffer of the last [capacity] telemetry events with monotonic ids —
/// the EventRingBuffer parity surface (reconnect replay via `?since=` id).
class EventRingBuffer<T> {
  EventRingBuffer(this.capacity);

  final int capacity;
  final _items = <T>[];
  int _nextId = 0;

  int get lastEventId => _nextId - 1;

  void push(T item) {
    if (_items.length == capacity) {
      _items.removeAt(0);
    }
    _items.add(item);
    _nextId++;
  }

  List<T> replaySince(int sinceId) {
    final start = sinceId + 1; // events after sinceId
    final firstAvailable = _nextId - _items.length;
    if (start < firstAvailable) return List<T>.unmodifiable(_items);
    final offset = (start - firstAvailable).clamp(0, _items.length);
    return List<T>.unmodifiable(_items.sublist(offset));
  }
}

/// Illustrative typed event used by the harness.
String encodeRingEvent(Map<String, Object?> event) => jsonEncode(event);
