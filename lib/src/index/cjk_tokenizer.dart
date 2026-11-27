/// CJK bigrams plus Latin/number words.
///
/// FTS5 then indexes the space-separated tokens with `unicode61`. A Chinese
/// query such as `身份证` becomes `身份` AND `份证` instead of being split as
/// English letters.
bool isCjkRune(int rune) {
  return (rune >= 0x3400 && rune <= 0x4DBF) ||
      (rune >= 0x4E00 && rune <= 0x9FFF) ||
      (rune >= 0xF900 && rune <= 0xFAFF);
}

bool _isWordRune(int rune) {
  return (rune >= 0x30 && rune <= 0x39) ||
      (rune >= 0x41 && rune <= 0x5A) ||
      (rune >= 0x61 && rune <= 0x7A);
}

/// Tokens for both indexing and queries. A single CJK character stays whole
/// so a one-character query still matches. Longer runs become overlapping
/// bigrams.
List<String> cjkTokens(String text) {
  final tokens = <String>[];
  final word = StringBuffer();
  final cjk = <int>[];

  void flushWord() {
    if (word.isEmpty) {
      return;
    }
    tokens.add(word.toString().toLowerCase());
    word.clear();
  }

  void flushCjk() {
    if (cjk.isEmpty) {
      return;
    }
    if (cjk.length == 1) {
      tokens.add(String.fromCharCode(cjk[0]));
    } else {
      for (var i = 0; i < cjk.length - 1; i++) {
        tokens.add(String.fromCharCodes(cjk.sublist(i, i + 2)));
      }
    }
    cjk.clear();
  }

  for (final rune in text.runes) {
    if (isCjkRune(rune)) {
      flushWord();
      cjk.add(rune);
    } else if (_isWordRune(rune)) {
      flushCjk();
      word.writeCharCode(rune);
    } else {
      flushWord();
      flushCjk();
    }
  }
  flushWord();
  flushCjk();
  return tokens;
}

/// Body stored in FTS5. The tokenizer is `unicode61`, so spaces keep the
/// bigrams intact.
String cjkIndexText(String text) => cjkTokens(text).join(' ');

/// FTS5 MATCH expression. Null when the query has no searchable token.
String? cjkMatchQuery(String text, {int maxTerms = 8}) {
  final tokens = cjkTokens(text);
  if (tokens.isEmpty) {
    return null;
  }
  final limited = tokens.length <= maxTerms
      ? tokens
      : tokens.sublist(0, maxTerms);
  return limited.map(_quoteFts).join(' AND ');
}

String _quoteFts(String token) {
  return '"${token.replaceAll('"', '""')}"';
}
