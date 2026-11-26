String formatCount(int value) {
  final text = value.abs().toString();
  final buffer = StringBuffer();
  if (value < 0) {
    buffer.write('-');
  }
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(text[i]);
  }
  return buffer.toString();
}

/// Local calendar date for a photo. Returns null when the device stored no
/// real timestamp (the plugin reports those as the Unix epoch).
String? formatPhotoDate(DateTime date) {
  if (date.year < 1980) {
    return null;
  }
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String photoCountLabel(int count) {
  return '${formatCount(count)} ${count == 1 ? 'photo' : 'photos'}';
}
