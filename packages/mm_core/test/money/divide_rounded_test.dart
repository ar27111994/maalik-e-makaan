import 'package:mm_core/src/money/money.dart';
import 'package:test/test.dart';

void main() {
  test('divideRounded rejects a zero denominator', () {
    expect(
      () => divideRounded(BigInt.one, BigInt.zero, RoundingMode.halfUp),
      throwsArgumentError,
    );
  });

  test('divideRounded normalises negative denominators for every mode', () {
    final seven = BigInt.from(7);
    final minusTwo = BigInt.from(-2);
    expect(
      divideRounded(seven, minusTwo, RoundingMode.halfUp),
      BigInt.from(-4),
    );
    expect(divideRounded(seven, minusTwo, RoundingMode.down), BigInt.from(-3));
    expect(divideRounded(seven, minusTwo, RoundingMode.floor), BigInt.from(-4));
    expect(
      divideRounded(seven, minusTwo, RoundingMode.ceiling),
      BigInt.from(-3),
    );
  });
}
