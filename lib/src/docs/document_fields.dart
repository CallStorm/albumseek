/// Structured fields from a Chinese identity document or a similar form.
class ParsedDocument {
  const ParsedDocument({required this.kind, required this.fields});

  /// `id_card`, `household`, or `form`.
  final String kind;
  final Map<String, String> fields;

  String get searchableText {
    final parts = <String>[kindLabel(kind)];
    fields.forEach((key, value) {
      parts.add(key);
      parts.add(value);
    });
    return parts.join(' ');
  }
}

String kindLabel(String kind) {
  switch (kind) {
    case 'id_card':
      return '身份证';
    case 'household':
      return '户口本';
    default:
      return '证件';
  }
}

/// Pulls mainland ID card and household-register fields out of OCR text.
///
/// A form that is neither of those, but has several `label: value` lines,
/// is kept as `form` so similar cards stay searchable.
ParsedDocument? parseChineseDocument(String raw) {
  final text = raw.replaceAll('\r', '\n');
  final flat = text.replaceAll(RegExp(r'\s+'), '');
  final household = _household(text, flat);
  if (household != null) {
    return household;
  }
  final idCard = _idCard(text, flat);
  if (idCard != null) {
    return idCard;
  }
  final form = _form(text);
  if (form != null) {
    return form;
  }
  return null;
}

/// Whether PaddleOCR-VL should read this OCR text.
///
/// A parsed ID card, household register, or labeled form qualifies, as do
/// the document titles themselves. A single 证, 户, or 表 does not.
bool needsDocumentVision(String raw) {
  if (parseChineseDocument(raw) != null) {
    return true;
  }
  final flat = raw.replaceAll(RegExp(r'\s+'), '');
  const phrases = ['公民身份号码', '身份证', '居民户口簿', '户口簿', '户口本'];
  for (final phrase in phrases) {
    if (flat.contains(phrase)) {
      return true;
    }
  }
  return false;
}

ParsedDocument? _idCard(String text, String flat) {
  final id =
      _first(r'(?:公民身份号码|身份证号|身份号码)?[:：]?\s*(\d{17}[\dXx])', text) ??
      _first(r'(\d{17}[\dXx])', flat);
  final looksLikeId =
      flat.contains('公民身份号码') ||
      flat.contains('身份证') ||
      (id != null && (flat.contains('姓名') || flat.contains('住址')));
  if (!looksLikeId || id == null) {
    return null;
  }
  final name = _name(text, flat);
  final gender = _first(r'性别[:：\s]*([男女])', text);
  final nation = _first(r'民族[:：\s]*([\u4e00-\u9fff]{1,6})', text);
  final birth = _birth(text);
  final address = _address(text);
  return ParsedDocument(
    kind: 'id_card',
    fields: {
      '姓名': ?name,
      '性别': ?gender,
      '民族': ?nation,
      '出生': ?birth,
      '住址': ?address,
      '公民身份号码': id.toUpperCase(),
    },
  );
}

ParsedDocument? _household(String text, String flat) {
  final looks =
      flat.contains('户主') || flat.contains('户号') || flat.contains('户口');
  if (!looks) {
    return null;
  }
  final householder = _first(r'户主姓名[:：\s]*([\u4e00-\u9fff]{2,6})', text);
  final householdNumber = _first(r'户号[:：\s]*([0-9A-Za-z]{3,20})', text);
  final relation = _first(r'与户主关系[:：\s]*([\u4e00-\u9fff]{1,8})', text);
  final name = _name(text, flat);
  final address = _address(text);
  final idNumber = _first(r'(\d{17}[\dXx])', flat);
  final fields = <String, String>{
    '户主姓名': ?householder,
    '户号': ?householdNumber,
    '与户主关系': ?relation,
    '姓名': ?name,
    '住址': ?address,
    '公民身份号码': ?idNumber?.toUpperCase(),
  };
  if (fields.isEmpty) {
    return null;
  }
  return ParsedDocument(kind: 'household', fields: fields);
}

ParsedDocument? _form(String text) {
  final fields = <String, String>{};
  final pattern = RegExp(r'([\u4e00-\u9fffA-Za-z]{2,12})[:：]\s*([^\n]{1,40})');
  for (final match in pattern.allMatches(text)) {
    final key = match.group(1)!.trim();
    final value = match.group(2)!.trim();
    if (value.isEmpty) {
      continue;
    }
    fields[key] = value;
  }
  if (fields.length < 2) {
    return null;
  }
  return ParsedDocument(kind: 'form', fields: fields);
}

String? _name(String text, String flat) {
  return _first(r'姓名[:：\s]*([\u4e00-\u9fff]{2,6})', text) ??
      _first(r'姓名([\u4e00-\u9fff]{2,4})', flat);
}

String? _birth(String text) {
  return _first(r'出生[:：\s]*(\d{4}\s*年\s*\d{1,2}\s*月\s*\d{1,2}\s*日)', text) ??
      _first(r'(\d{4}年\d{1,2}月\d{1,2}日)', text);
}

String? _address(String text) {
  final match = RegExp(r'住址[:：\s]*([^\n]{4,40})').firstMatch(text);
  return match?.group(1)?.trim();
}

String? _first(String pattern, String text) {
  return RegExp(pattern).firstMatch(text)?.group(1)?.trim();
}
