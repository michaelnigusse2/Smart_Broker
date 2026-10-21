/// Turns spoken Amharic numbers in a transcript into digits, the way a broker
/// would write them: "ዘጠኝ ሚሊዮን ብር" → "9,000,000 ብር", "አስራ አምስት ዓመት" → "15 ዓመት",
/// "ዜሮ ዘጠኝ አንድ አንድ ሃያ ሶስት …" → "0911 23…" style phone numbers as one digit run.
///
/// Deliberately cautious: a lone small number (አንድ, ሁለት … አስር) stays a word,
/// because "አንድ" is also the indefinite article and "ሁለት ሶስት ቀን" means
/// "two or three days".
library;

const _units = <String, int>{
  'ዜሮ': 0,
  'አንድ': 1,
  'ሁለት': 2,
  'ሶስት': 3,
  'አራት': 4,
  'አምስት': 5,
  'ስድስት': 6,
  'ሰባት': 7,
  'ስምንት': 8,
  'ዘጠኝ': 9,
};

const _tens = <String, int>{
  'አስር': 10,
  'ሀያ': 20,
  'ሰላሳ': 30,
  'አርባ': 40,
  'ሀምሳ': 50,
  'ስልሳ': 60,
  'ስድሳ': 60,
  'ሰባ': 70,
  'ሰማንያ': 80,
  'ዘጠና': 90,
};

const _scales = <String, int>{
  'መቶ': 100,
  'ሺ': 1000,
  'ሺህ': 1000,
  'ሚሊዮን': 1000000,
  'ሚልዮን': 1000000,
  'ሚሊየን': 1000000,
  'ቢሊዮን': 1000000000,
  'ቢልዮን': 1000000000,
  'ቢሊየን': 1000000000,
};

/// "አስራ" + unit: 11–19.
const _teen = 'አስራ';

/// "… and a half" after a scale word: "ሁለት ሚሊዮን ተኩል" = 2,500,000.
const _half = 'ተኩል';

/// Decimal point: "ሁለት ነጥብ አምስት ሚሊዮን" = 2,500,000.
const _point = 'ነጥብ';

/// Prepositions written joined to the next word ("በአምስት" = "for five").
const _prefixes = ['እስከ', 'እንደ', 'ወደ', 'ከ', 'በ', 'የ', 'ለ'];

/// Folds the letters Amharic writes interchangeably (ሀ/ሐ/ኀ/ሃ, ሰ/ሠ, አ/ዐ/ኣ, ጸ/ፀ)
/// so "ሃያ", "ሐያ" and "ሀያ" all match.
String foldAmharicSpelling(String word) {
  final out = StringBuffer();
  for (final rune in word.runes) {
    var c = rune;
    for (final (from, to) in const [
      (0x1210, 0x1200),
      (0x1280, 0x1200),
      (0x1220, 0x1230),
      (0x12D0, 0x12A0),
      (0x1340, 0x1338),
    ]) {
      if (c >= from && c < from + 8) {
        c = to + (c - from);
        break;
      }
    }
    if (c == 0x1203 || c == 0x12A3) c -= 3; // ሃ → ሀ, ኣ → አ
    out.writeCharCode(c);
  }
  return out.toString();
}

enum _Kind { unit, ten, teen, scale, half, point }

class _Token {
  final _Kind kind;
  final int value;
  const _Token(this.kind, this.value);
}

_Token? _classify(String word) {
  final w = foldAmharicSpelling(word);
  if (_units.containsKey(w)) return _Token(_Kind.unit, _units[w]!);
  if (_tens.containsKey(w)) return _Token(_Kind.ten, _tens[w]!);
  if (_scales.containsKey(w)) return _Token(_Kind.scale, _scales[w]!);
  if (w == _teen) return const _Token(_Kind.teen, 10);
  if (w == _half) return const _Token(_Kind.half, 0);
  if (w == _point) return const _Token(_Kind.point, 0);
  return null;
}

/// Splits a joined preposition off a number word: "በአምስት" → ("በ", "አምስት").
(String, String)? _splitPrefix(String word) {
  for (final p in _prefixes) {
    if (word.length > p.length && word.startsWith(p)) {
      final rest = word.substring(p.length);
      final t = _classify(rest);
      // Only words that can start a number (not ተኩል / ነጥብ on their own).
      if (t != null && t.kind != _Kind.half && t.kind != _Kind.point) return (p, rest);
    }
  }
  return null;
}

String normaliseAmharicNumbers(String text) {
  if (text.isEmpty) return text;
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  final out = <String>[];
  var i = 0;
  while (i < words.length) {
    // A run may begin with a joined preposition ("በአምስት").
    var prefix = '';
    var first = words[i];
    if (_classify(first) == null) {
      final split = _splitPrefix(first);
      if (split == null) {
        out.add(words[i]);
        i++;
        continue;
      }
      (prefix, first) = split;
    }
    final run = <String>[first];
    var j = i + 1;
    while (j < words.length && _classify(words[j]) != null) {
      run.add(words[j]);
      j++;
    }
    final converted = _convertRun(run);
    if (converted == null) {
      out.addAll(words.sublist(i, j));
    } else {
      out.add('$prefix$converted');
    }
    i = j;
  }
  return out.join(' ');
}

/// Digits for a run of number words, or null to leave the words as they are.
String? _convertRun(List<String> run) {
  final tokens = run.map((w) => _classify(w)!).toList();
  if (tokens.first.kind == _Kind.half || tokens.first.kind == _Kind.point) return null;

  // Phone numbers and codes are read digit by digit, usually starting with 0.
  final startsWithZero = tokens.first.kind == _Kind.unit && tokens.first.value == 0;
  final allUnits = tokens.every((t) => t.kind == _Kind.unit);
  if (startsWithZero || (allUnits && tokens.length >= 3)) return _digitGroups(tokens);

  // "ሁለት ሶስት" = "two or three"; a lone ሁለት / አስር stays a word.
  if (allUnits) return null;
  if (tokens.length == 1 && tokens.first.kind == _Kind.ten && tokens.first.value == 10) return null;

  final pointAt = tokens.indexWhere((t) => t.kind == _Kind.point);
  if (pointAt >= 0) return _decimal(tokens, pointAt);

  final value = _cardinal(tokens);
  if (value == null) return null;
  return _format(value);
}

/// Reads ten/teen + unit pairs and hundreds as groups, single units as digits:
/// ዜሮ ዘጠኝ አንድ አንድ ሃያ ሶስት → "0911" + "23".
String? _digitGroups(List<_Token> tokens) {
  final out = StringBuffer();
  var i = 0;
  while (i < tokens.length) {
    final t = tokens[i];
    if (t.kind == _Kind.unit) {
      // "ሁለት መቶ" inside a phone number is 200.
      if (i + 1 < tokens.length && tokens[i + 1].kind == _Kind.scale && tokens[i + 1].value == 100) {
        var group = t.value * 100;
        i += 2;
        if (i < tokens.length && (tokens[i].kind == _Kind.ten || tokens[i].kind == _Kind.teen)) {
          group += tokens[i].value;
          i++;
          if (i < tokens.length && tokens[i].kind == _Kind.unit && tokens[i].value != 0) {
            group += tokens[i].value;
            i++;
          }
        }
        out.write(group);
        continue;
      }
      out.write(t.value);
      i++;
    } else if (t.kind == _Kind.ten || t.kind == _Kind.teen) {
      var group = t.value;
      i++;
      if (i < tokens.length && tokens[i].kind == _Kind.unit && tokens[i].value != 0) {
        group += tokens[i].value;
        i++;
      } else if (t.kind == _Kind.teen) {
        return null; // "አስራ" must be followed by a unit
      }
      out.write(group);
    } else {
      return null; // thousands/millions don't belong in a phone number
    }
  }
  return out.toString();
}

/// Ordinary cardinal: ሁለት ሚሊዮን አምስት መቶ ሺ → 2,500,000.
int? _cardinal(List<_Token> tokens) {
  var total = 0;
  var current = 0;
  var lastScale = 0;
  var lastKind = _Kind.scale;
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    switch (t.kind) {
      case _Kind.unit:
        // Two units in a row ("አምስት ስድስት") is "five or six", not a sum.
        if (i > 0 && lastKind == _Kind.unit) return null;
        current += t.value;
      case _Kind.ten:
        if (current % 100 != 0 && lastKind != _Kind.scale) return null;
        current += t.value;
      case _Kind.teen:
        if (i + 1 >= tokens.length || tokens[i + 1].kind != _Kind.unit) return null;
        current += 10;
      case _Kind.scale:
        if (t.value == 100) {
          current = (current == 0 ? 1 : current) * 100;
        } else {
          total += (current == 0 ? 1 : current) * t.value;
          current = 0;
        }
        lastScale = t.value;
      case _Kind.half:
        if (lastScale < 100 || lastKind != _Kind.scale) return null;
        if (lastScale == 100) {
          current += 50;
        } else {
          total += lastScale ~/ 2;
        }
      case _Kind.point:
        return null;
    }
    lastKind = t.kind;
  }
  return total + current;
}

/// "ሁለት ነጥብ አምስት ሚሊዮን" → 2,500,000; "ሶስት ነጥብ አምስት" → 3.5.
String? _decimal(List<_Token> tokens, int pointAt) {
  final whole = _cardinal(tokens.sublist(0, pointAt));
  if (whole == null || pointAt + 1 >= tokens.length) return null;
  final fraction = StringBuffer();
  var i = pointAt + 1;
  while (i < tokens.length && tokens[i].kind == _Kind.unit) {
    fraction.write(tokens[i].value);
    i++;
  }
  if (fraction.isEmpty) return null;
  final rest = tokens.sublist(i);
  if (rest.isEmpty) return '${_format(whole)}.$fraction';
  if (rest.length != 1 || rest.first.kind != _Kind.scale) return null;
  final digits = fraction.toString();
  final scaled = (whole * rest.first.value) + (int.parse(digits) * rest.first.value) ~/ _pow10(digits.length);
  return _format(scaled);
}

int _pow10(int n) {
  var v = 1;
  for (var i = 0; i < n; i++) {
    v *= 10;
  }
  return v;
}

/// Thousands separators from 10,000 up; years and small amounts stay plain (2017, 1500).
String _format(int value) {
  final s = value.toString();
  if (value < 10000) return s;
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}
