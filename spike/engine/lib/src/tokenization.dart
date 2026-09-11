/// Bilingual (AR/EN) tokenization for BM25 — the first parity surface.
///
/// Mirrors the desktop BM25Index contract: Unicode normalization, Arabic
/// diacritic stripping, letter normalization, then prefix-clitic stemming
/// (ال وال فال بال لل كال). Gold vectors are generated from the desktop
/// TypeScript engine; this implementation must match bit-for-bit.
library;

const List<String> _arabicPrefixClitics = ['ال', 'وال', 'فال', 'بال', 'لل', 'كال'];

const Map<String, String> _arabicLetterNormalization = {
  'أ': 'ا',
  'إ': 'ا',
  'آ': 'ا',
  'ٱ': 'ا',
  'ة': 'ه',
  'ى': 'ي',
  'ؤ': 'و',
  'ئ': 'ي',
};

/// Strips Arabic diacritics (tashkeel) and Quranic marks.
String stripDiacritics(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    final c = String.fromCharCode(rune);
    if (_isDiacritic(rune)) continue;
    buffer.write(c);
  }
  return buffer.toString();
}

bool _isDiacritic(int rune) {
  // U+064B–U+065F (tashkeel), U+0670 (superscript alef),
  // U+06D6–U+06ED (Quranic annotation marks), U+0640 (tatweel).
  return (rune >= 0x064B && rune <= 0x065F) ||
      rune == 0x0670 ||
      (rune >= 0x06D6 && rune <= 0x06ED) ||
      rune == 0x0640;
}

/// Normalizes a single token: diacritic strip, letter normalization,
/// lowercasing for Latin text. Does NOT stem — see [stemArabic].
String normalizeToken(String token) {
  var t = stripDiacritics(token);
  final buffer = StringBuffer();
  for (final rune in t.runes) {
    final c = String.fromCharCode(rune);
    buffer.write(_arabicLetterNormalization[c] ?? c.toLowerCase());
  }
  return buffer.toString();
}

/// Strips one Arabic prefix clitic per pass, iteratively (longest first),
/// mirroring the desktop's prefix-clitic morphological stemming.
String stemArabic(String normalizedToken) {
  var t = normalizedToken;
  var stripped = true;
  while (stripped && t.length > 4) {
    stripped = false;
    for (final clitic in _arabicPrefixClitics) {
      if (t.startsWith(clitic) && t.length - clitic.length >= 3) {
        t = t.substring(clitic.length);
        stripped = true;
        break;
      }
    }
  }
  return t;
}

/// Splits raw text into tokens on non-letter boundaries (any script).
List<String> tokenize(String text) {
  final tokens = <String>[];
  final current = StringBuffer();
  void flush() {
    if (current.isNotEmpty) {
      tokens.add(current.toString());
      current.clear();
    }
  }

  for (final rune in text.runes) {
    final category = _letterCategory(rune);
    if (category == _LetterCategory.none) {
      flush();
    } else {
      current.writeCharCode(rune);
    }
  }
  flush();
  return tokens;
}

enum _LetterCategory { none, latin, arabic, digit, otherLetter }

_LetterCategory _letterCategory(int rune) {
  if ((rune >= 0x30 && rune <= 0x39) || (rune >= 0x0660 && rune <= 0x0669)) {
    return _LetterCategory.digit;
  }
  if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A)) {
    return _LetterCategory.latin;
  }
  if (rune >= 0x0621 && rune <= 0x064A) {
    return _LetterCategory.arabic;
  }
  // Treat all other Unicode letters as letters so non-AR/EN text
  // still tokenizes as words (parity with \\p{L}-style splitting).
  if ((rune >= 0xAA && rune <= 0x2AF) ||
      (rune >= 0x370 && rune <= 0x3FF) ||
      (rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0x0400 && rune <= 0x04FF)) {
    return _LetterCategory.otherLetter;
  }
  return _LetterCategory.none;
}

/// Full pipeline: tokenize → normalize → stem (Arabic only).
List<String> analyze(String text) {
  return tokenize(text)
      .map(normalizeToken)
      .map((t) => _letterCategoryHasArabic(t) ? stemArabic(t) : t)
      .where((t) => t.isNotEmpty)
      .toList();
}

bool _letterCategoryHasArabic(String token) {
  for (final rune in token.runes) {
    if (rune >= 0x0621 && rune <= 0x064A) return true;
  }
  return false;
}
