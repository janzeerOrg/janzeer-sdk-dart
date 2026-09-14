import 'package:janzeer_sdk/janzeer_sdk.dart';
import 'package:test/test.dart';

void main() {
  test('keeps every digit of decimals and big integers', () {
    final v = parseJson(
            '{"balance": 123456789.12345678, "cap": 340282366920938463463374607431768211456, "n": -0, "e": 1.5e-7, "s": "x\\u0041\\n", "a": [true, null, 1]}')
        as Map<String, Object?>;
    expect(
        (v['balance'] as JsonNumber).toDecimalString(), '123456789.12345678');
    expect((v['cap'] as JsonNumber).toBigInt(),
        BigInt.parse('340282366920938463463374607431768211456'));
    expect(() => (v['cap'] as JsonNumber).toInt(), throwsFormatException);
    expect((v['n'] as JsonNumber).toDecimalString(), '0');
    expect((v['e'] as JsonNumber).toDecimalString(), '0.00000015');
    expect(v['s'], 'xA\n');
    expect(toPlain(v['a']), [true, null, 1]);
  });
  test('normalizes exponent notation and rejects invalid JSON', () {
    expect(normalizeNumberTextPublic('1e3'), '1000');
    expect(normalizeNumberTextPublic('1.2345E+2'), '123.45');
    expect(normalizeNumberTextPublic('-2.50'), '-2.5');
    expect(() => parseJson('{"a":}'), throwsFormatException);
    expect(() => parseJson('[1,]'), throwsFormatException);
    expect(() => parseJson('1 2'), throwsFormatException);
  });
  test('toPlain / toPlainNumbers', () {
    expect(toPlain(parseJson('{"a": 5, "b": 1.5, "c": 92233720368547758070}')),
        {'a': 5, 'b': '1.5', 'c': '92233720368547758070'});
    expect(toPlainNumbers(parseJson('{"a": 5, "b": 1.5}')), {'a': 5, 'b': 1.5});
  });
}

String normalizeNumberTextPublic(String s) => JsonNumber(s).toDecimalString();
