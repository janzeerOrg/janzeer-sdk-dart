/// Lossless JSON. The node serializes coin amounts (`BigDecimal`, 8 decimals) and token amounts (`BigInteger`)
/// as bare JSON numbers; `jsonDecode` would turn them into doubles / overflow 64-bit ints. This parser keeps every
/// number as its exact source text ([JsonNumber]); the model mappers convert each field to the type it documents.
library;

/// A JSON number kept as its exact source text.
class JsonNumber {
  /// the source text (`1.50000000`, `1e3`, `-0`)
  final String raw;

  /// Wrap.
  const JsonNumber(this.raw);

  /// Exact decimal string with exponent expanded and redundant zeros stripped (`'1000'`, `'1.5'`, `'0'`).
  String toDecimalString() => normalizeNumberText(raw);

  /// Integer as [BigInt] (throws [FormatException] if the number has a fractional part).
  BigInt toBigInt() {
    final s = toDecimalString();
    if (s.contains('.')) throw FormatException('not an integer: $raw');
    return BigInt.parse(s);
  }

  /// As a 64-bit [int] (throws on fraction / overflow).
  int toInt() {
    final b = toBigInt();
    if (!b.isValidInt) throw FormatException('integer exceeds 64 bits: $raw');
    return b.toInt();
  }

  /// As a [double] (lossy — only for values known to be small).
  double toDouble() => double.parse(raw);

  @override
  String toString() => toDecimalString();

  @override
  bool operator ==(Object other) =>
      other is JsonNumber && other.toDecimalString() == toDecimalString();

  @override
  int get hashCode => toDecimalString().hashCode;
}

/// Parse JSON text; numbers become [JsonNumber]. Objects are `Map<String, Object?>`, arrays `List<Object?>`.
Object? parseJson(String text) {
  final p = _Parser(text);
  p.ws();
  final v = p.value();
  p.ws();
  if (p.i != text.length) p.fail('trailing characters');
  return v;
}

class _Parser {
  final String s;
  int i = 0;
  _Parser(this.s);

  Never fail(String msg) =>
      throw FormatException('JSON parse error at $i: $msg');

  void ws() {
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      if (c == 0x20 || c == 0x0a || c == 0x0d || c == 0x09) {
        i++;
      } else {
        break;
      }
    }
  }

  Object? value() {
    if (i >= s.length) fail('unexpected end');
    final c = s[i];
    switch (c) {
      case '{':
        return object();
      case '[':
        return array();
      case '"':
        return string();
      case 't':
        return literal('true', true);
      case 'f':
        return literal('false', false);
      case 'n':
        return literal('null', null);
      default:
        if (c == '-' || (c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39)) {
          return number();
        }
        fail('unexpected $c');
    }
  }

  T literal<T>(String word, T v) {
    if (s.startsWith(word, i)) {
      i += word.length;
      return v;
    }
    fail('expected $word');
  }

  static final _numRe = RegExp(r'^-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?');

  JsonNumber number() {
    final m = _numRe.firstMatch(s.substring(i));
    if (m == null) fail('bad number');
    i += m[0]!.length;
    return JsonNumber(m[0]!);
  }

  String string() {
    i++;
    final out = StringBuffer();
    while (i < s.length) {
      final c = s[i++];
      if (c == '"') return out.toString();
      if (c == r'\') {
        final e = s[i++];
        switch (e) {
          case '"':
            out.write('"');
          case r'\':
            out.write(r'\');
          case '/':
            out.write('/');
          case 'b':
            out.write('\b');
          case 'f':
            out.write('\f');
          case 'n':
            out.write('\n');
          case 'r':
            out.write('\r');
          case 't':
            out.write('\t');
          case 'u':
            final hex = s.substring(i, i + 4);
            if (!RegExp(r'^[0-9a-fA-F]{4}$').hasMatch(hex)) {
              fail('bad \\u escape');
            }
            out.writeCharCode(int.parse(hex, radix: 16));
            i += 4;
          default:
            fail('bad escape');
        }
      } else {
        out.write(c);
      }
    }
    fail('unterminated string');
  }

  List<Object?> array() {
    i++;
    final out = <Object?>[];
    ws();
    if (s[i] == ']') {
      i++;
      return out;
    }
    while (true) {
      ws();
      out.add(value());
      ws();
      final c = s[i++];
      if (c == ']') return out;
      if (c != ',') fail('expected , or ]');
    }
  }

  Map<String, Object?> object() {
    i++;
    final out = <String, Object?>{};
    ws();
    if (s[i] == '}') {
      i++;
      return out;
    }
    while (true) {
      ws();
      if (s[i] != '"') fail('expected key');
      final k = string();
      ws();
      if (s[i++] != ':') fail('expected :');
      ws();
      out[k] = value();
      ws();
      final c = s[i++];
      if (c == '}') return out;
      if (c != ',') fail('expected , or }');
    }
  }
}

/// Expand exponent notation and strip a leading `+` / redundant zeros, keeping every significant digit.
String normalizeNumberText(String raw) {
  var s = raw.trim();
  final neg = s.startsWith('-');
  if (neg || s.startsWith('+')) s = s.substring(1);
  final eIdx = s.indexOf(RegExp('[eE]'));
  final mant = eIdx == -1 ? s : s.substring(0, eIdx);
  final exp = eIdx == -1 ? 0 : int.parse(s.substring(eIdx + 1));
  final dot = mant.indexOf('.');
  var intPart = dot < 0 ? mant : mant.substring(0, dot);
  var frac = dot < 0 ? '' : mant.substring(dot + 1);
  if (intPart.isEmpty) intPart = '0';
  if (exp != 0) {
    final digits = intPart + frac;
    final point = intPart.length + exp;
    if (point <= 0) {
      intPart = '0';
      frac = '0' * -point + digits;
    } else if (point >= digits.length) {
      intPart = digits + '0' * (point - digits.length);
      frac = '';
    } else {
      intPart = digits.substring(0, point);
      frac = digits.substring(point);
    }
  }
  intPart = intPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  frac = frac.replaceFirst(RegExp(r'0+$'), '');
  final out = frac.isEmpty ? intPart : '$intPart.$frac';
  if (out == '0' || out.isEmpty) return '0';
  return (neg ? '-' : '') + out;
}

// ---- field converters used by the model mappers ----

/// Required string field (a number is accepted and rendered as its decimal text).
String asString(Object? v, [String field = 'value']) {
  if (v is String) return v;
  if (v is JsonNumber) return v.toDecimalString();
  throw FormatException('expected string for $field, got ${_describe(v)}');
}

/// Optional string field.
String? asOptString(Object? v) => v == null ? null : asString(v);

/// Decimal amount field → canonical string (numbers and strings both accepted).
String asDecimal(Object? v, [String field = 'value']) {
  if (v is JsonNumber) return v.toDecimalString();
  if (v is String) return normalizeNumberText(v);
  throw FormatException('expected decimal for $field, got ${_describe(v)}');
}

/// Optional decimal field.
String? asOptDecimal(Object? v) => v == null ? null : asDecimal(v);

/// Integer field that fits a 64-bit int.
int asInt(Object? v, [String field = 'value']) {
  if (v is JsonNumber) return v.toInt();
  if (v is String && RegExp(r'^-?\d+$').hasMatch(v)) return int.parse(v);
  throw FormatException('expected integer for $field, got ${_describe(v)}');
}

/// Optional int field.
int? asOptInt(Object? v) => v == null ? null : asInt(v);

/// Arbitrary-size integer field (token amounts) → [BigInt].
BigInt asBigInt(Object? v, [String field = 'value']) {
  if (v is JsonNumber) return v.toBigInt();
  if (v is String && RegExp(r'^-?\d+$').hasMatch(v)) return BigInt.parse(v);
  throw FormatException('expected integer for $field, got ${_describe(v)}');
}

/// Optional BigInt field.
BigInt? asOptBigInt(Object? v) => v == null ? null : asBigInt(v);

/// Boolean field.
bool asBool(Object? v, [String field = 'value']) {
  if (v is bool) return v;
  throw FormatException('expected boolean for $field, got ${_describe(v)}');
}

/// Object field.
Map<String, Object?> asObject(Object? v, [String field = 'value']) {
  if (v is Map<String, Object?>) return v;
  throw FormatException('expected object for $field, got ${_describe(v)}');
}

/// Array field.
List<Object?> asArray(Object? v, [String field = 'value']) {
  if (v is List<Object?>) return v;
  throw FormatException('expected array for $field, got ${_describe(v)}');
}

/// Convert a parsed tree to plain Dart (numbers → [int] when they fit, else [String]). Handy for logging / untyped access.
Object? toPlain(Object? v) {
  if (v is JsonNumber) {
    final s = v.toDecimalString();
    if (!s.contains('.')) {
      final b = BigInt.parse(s);
      return b.isValidInt ? b.toInt() : s;
    }
    return s;
  }
  if (v is List<Object?>) return v.map(toPlain).toList();
  if (v is Map<String, Object?>) {
    return v.map((k, x) => MapEntry(k, toPlain(x)));
  }
  return v;
}

/// Convert a parsed tree to what `jsonDecode` would have produced (`int` / `double` — LOSSY). Only for migrating
/// code written against `jsonDecode` output; typed code should use the model mappers.
Object? toPlainNumbers(Object? v) {
  if (v is JsonNumber) {
    final s = v.toDecimalString();
    if (!s.contains('.')) {
      final b = BigInt.parse(s);
      return b.isValidInt ? b.toInt() : b.toDouble();
    }
    return double.parse(s);
  }
  if (v is List<Object?>) return v.map(toPlainNumbers).toList();
  if (v is Map<String, Object?>) {
    return v.map((k, x) => MapEntry(k, toPlainNumbers(x)));
  }
  return v;
}

String _describe(Object? v) => v == null
    ? 'null'
    : v is JsonNumber
        ? 'number ${v.raw}'
        : v.runtimeType.toString();
