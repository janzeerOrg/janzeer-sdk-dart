import 'package:janzeer_sdk/janzeer_sdk.dart';
import 'package:test/test.dart';

void main() {
  test('toScaledLong matches BigDecimal.setScale(8, HALF_UP)', () {
    expect(toScaledLong('0.01'), BigInt.from(1000000));
    expect(toScaledLong('1.5'), BigInt.from(150000000));
    expect(toScaledLong(0.1), BigInt.from(10000000));
    expect(toScaledLong('0.123456785'), BigInt.from(12345679));
    expect(toScaledLong('0.123456784'), BigInt.from(12345678));
    expect(toScaledLong('-2'), BigInt.from(-200000000));
    expect(toScaledLong(1e-7), BigInt.from(10));
    expect(toScaledLong(BigInt.parse('123456789012345')),
        BigInt.parse('12345678901234500000000'));
  });
  test('fromScaledLong / format / parse / arithmetic', () {
    expect(fromScaledLong(BigInt.from(150000000)), '1.50000000');
    expect(fromScaledLong(BigInt.from(-1)), '-0.00000001');
    expect(formatJnz('1.50000000'), '1.5 JNZ');
    expect(formatJnz('1234.5', group: true, ticker: false), '1,234.5');
    expect(formatJnz('2', trim: false, decimals: 2), '2.00 JNZ');
    expect(parseJnz('1,234.5 JNZ'), '1234.5');
    expect(() => parseJnz('abc'), throwsFormatException);
    expect(isValidAmount('0.00000001'), isTrue);
    expect(isValidAmount('0.000000001'), isFalse);
    expect(compareAmounts('1.10', '1.1'), 0);
    expect(addAmounts('1.25', '0.01'), '1.26000000');
    expect(subAmounts('100', '1.26'), '98.74000000');
  });
}
