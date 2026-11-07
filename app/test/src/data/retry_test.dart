import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/retry.dart';

void main() {
  test('retries a lost connection or a busy service, doubling the wait', () {
    final waits = [
      for (var count = 0; count < maxRetries; count++)
        retryTransientFailures(count, const NetworkFailure())!.inSeconds,
    ];
    expect(waits, [1, 2, 4, 8, 16, 30]);
    expect(
      retryTransientFailures(0, const TemporarilyUnavailable()),
      const Duration(seconds: 1),
    );
  });

  test('stops after the last retry', () {
    expect(retryTransientFailures(maxRetries, const NetworkFailure()), isNull);
  });

  test('never retries what would fail the same way', () {
    for (final error in <Object>[
      const RejectedFailure('portfolio_limit_reached'),
      const Forbidden(),
      const SessionExpired(),
      const ServerFailure('XX000'),
      StateError('bug'),
    ]) {
      expect(retryTransientFailures(0, error), isNull, reason: '$error');
    }
  });
}
