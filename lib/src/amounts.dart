/// Native-coin amount handling. Amounts cross this SDK as decimal STRINGS (`'1.5'`, `'0.01'`) — never doubles —
/// and are scaled to an int64 ([BigInt]) exactly the way the node's `ByteUtils.toScaledLong` does.
library;

import 'constants.dart' as c;

final BigInt _scale = BigInt.from(10).pow(c.decimals);
final RegExp _decimalRe = RegExp(r'^-?(\d+)(?:\.(\d+))?$');

/// Canonicalize an amount given as a decimal [String], an [int]/[BigInt] of whole coins, or (discouraged) a [num].
/// Throws [FormatException] on anything that is not a plain decimal.
String normalizeAmount(Object amount) {
  final String s;
  if (amount is BigInt || amount is int) {
    s = amount.toString();
  } else if (amount is double) {
    s = _doubleToDecimal(amount);
  } else {
    s = amount.toString().trim();
  }
  if (!_decimalRe.hasMatch(s)) {
    throw FormatException('Not a decimal amount: $amount');
  }
  return s;
}

/// True when [amount] is a plain decimal with at most 8 fractional digits (what the node accepts).
bool isValidAmount(Object amount) {
  try {
    final s = normalizeAmount(amount);
    final dot = s.indexOf('.');
    return dot < 0 || s.length - dot - 1 <= c.decimals;
  } on FormatException {
    return false;
  }
}

/// `ByteUtils.toScaledLong`: `BigDecimal(amount).setScale(8, HALF_UP) × 10^8` as an integer.
/// Pinned by the `scaled` table of the conformance vectors.
BigInt toScaledLong(Object amount) {
  final s = normalizeAmount(amount);
  final neg = s.startsWith('-');
  final t = neg ? s.substring(1) : s;
  final dot = t.indexOf('.');
  final intPart = dot < 0 ? t : t.substring(0, dot);
  final fracPart = dot < 0 ? '' : t.substring(dot + 1);
  final frac8 = fracPart.length >= c.decimals
      ? fracPart.substring(0, c.decimals)
      : fracPart.padRight(c.decimals, '0');
  var scaled = BigInt.parse(intPart.isEmpty ? '0' : intPart) * _scale +
      BigInt.parse(frac8);
  if (fracPart.length > c.decimals &&
      fracPart.codeUnitAt(c.decimals) - 48 >= 5) {
    scaled += BigInt.one; // HALF_UP
  }
  return neg ? -scaled : scaled;
}

/// Inverse of [toScaledLong]: base units → decimal string with exactly 8 fractional digits (`'1.50000000'`).
String fromScaledLong(BigInt scaled) {
  final neg = scaled.isNegative;
  final abs = scaled.abs();
  final int = abs ~/ _scale;
  final frac = (abs % _scale).toString().padLeft(c.decimals, '0');
  return '${neg ? '-' : ''}$int.$frac';
}

/// Human-readable JNZ amount: `formatJnz('1.50000000')` → `'1.5 JNZ'`. Truncates (never rounds) beyond
/// [decimals]; [trim] drops trailing zeros; [group] inserts thousands separators.
String formatJnz(Object amount,
    {int decimals = c.decimals,
    bool trim = true,
    bool ticker = true,
    bool group = false}) {
  final s = normalizeAmount(amount);
  final neg = s.startsWith('-');
  final t = neg ? s.substring(1) : s;
  final dot = t.indexOf('.');
  var intPart = dot < 0 ? t : t.substring(0, dot);
  var frac = dot < 0 ? '' : t.substring(dot + 1);
  if (frac.length > decimals) frac = frac.substring(0, decimals);
  if (trim) {
    frac = frac.replaceFirst(RegExp(r'0+$'), '');
  } else if (frac.length < decimals) {
    frac = frac.padRight(decimals, '0');
  }
  if (group) {
    intPart =
        intPart.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }
  final out = '${neg ? '-' : ''}$intPart${frac.isEmpty ? '' : '.$frac'}';
  return ticker ? '$out ${c.ticker}' : out;
}

/// Parse user input like `'1,234.5 JNZ'` into a canonical amount string (`'1234.5'`). Throws [FormatException].
String parseJnz(String input) {
  final cleaned = input
      .replaceFirst(RegExp('\\s*${c.ticker}\\s*\$', caseSensitive: false), '')
      .replaceAll(',', '')
      .trim();
  return normalizeAmount(cleaned);
}

/// Exact decimal comparison: -1, 0 or 1.
int compareAmounts(Object a, Object b) =>
    (toScaledLong(a) - toScaledLong(b)).sign;

/// Exact `a + b` as a canonical 8-decimal string.
String addAmounts(Object a, Object b) =>
    fromScaledLong(toScaledLong(a) + toScaledLong(b));

/// Exact `a - b` as a canonical 8-decimal string.
String subAmounts(Object a, Object b) =>
    fromScaledLong(toScaledLong(a) - toScaledLong(b));

String _doubleToDecimal(double n) {
  if (!n.isFinite) throw FormatException('Not a finite amount: $n');
  final s = n.toString();
  if (!s.contains('e') && !s.contains('E')) return s;
  // expand exponent notation without floating arithmetic
  final parts = s.toLowerCase().split('e');
  final mant = parts[0];
  final exp = int.parse(parts[1]);
  final neg = mant.startsWith('-');
  final m = neg ? mant.substring(1) : mant;
  final dot = m.indexOf('.');
  final digits = m.replaceFirst('.', '');
  final point = (dot < 0 ? m.length : dot) + exp;
  String out;
  if (point <= 0) {
    out = '0.${'0' * -point}$digits';
  } else if (point >= digits.length) {
    out = digits + '0' * (point - digits.length);
  } else {
    out = '${digits.substring(0, point)}.${digits.substring(point)}';
  }
  out = out.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  return (neg ? '-' : '') + out;
}
