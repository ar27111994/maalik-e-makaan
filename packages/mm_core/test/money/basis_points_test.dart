import 'package:mm_core/mm_core.dart';
import 'package:test/test.dart';

void main() {
  group('basisPointsFromPercent', () {
    test('accepts JSON numbers and strings', () {
      expect(basisPointsFromPercent(10), 1000);
      expect(basisPointsFromPercent(2.5), 250);
      expect(basisPointsFromPercent(12.34), 1234);
      expect(basisPointsFromPercent('7.5'), 750);
      expect(basisPointsFromPercent(' 0 '), 0);
      expect(basisPointsFromPercent('100'), 10000);
    });

    test('rejects malformed or out-of-range values', () {
      for (final bad in <Object?>[
        null,
        '',
        'ten',
        '1.234',
        '-5',
        '100.01',
        '101',
        double.nan,
        true,
      ]) {
        expect(
          () => basisPointsFromPercent(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });
  });

  group('percentFromBasisPoints', () {
    test('formats without trailing zeros', () {
      expect(percentFromBasisPoints(1000), '10');
      expect(percentFromBasisPoints(250), '2.5');
      expect(percentFromBasisPoints(1234), '12.34');
      expect(percentFromBasisPoints(5), '0.05');
      expect(percentFromBasisPoints(0), '0');
    });

    test('round-trips', () {
      for (var bp = 0; bp <= 10000; bp += 37) {
        expect(basisPointsFromPercent(percentFromBasisPoints(bp)), bp);
      }
    });

    test('rejects negatives', () {
      expect(() => percentFromBasisPoints(-1), throwsArgumentError);
    });
  });
}
