import 'package:maalik_e_makaan/src/core/failure.dart';

/// How long a failed provider waits before Riverpod runs it again, or null
/// to stop retrying.
///
/// Only failures that can pass by themselves are retried: no connection and
/// a busy service, with the wait doubling from 1 s up to 30 s, at most 6
/// times (about a minute and a half in all). A refusal, a missing
/// permission or an ended session would fail the same way again, so the
/// screen shows it at once with its own retry button.
Duration? retryTransientFailures(int retryCount, Object error) {
  if (retryCount >= maxRetries) return null;
  final transient = error is NetworkFailure || error is TemporarilyUnavailable;
  if (!transient) return null;
  final seconds = 1 << retryCount;
  return Duration(
    seconds: seconds > maxDelaySeconds ? maxDelaySeconds : seconds,
  );
}

/// The most times a provider is retried after a transient failure.
const maxRetries = 6;

/// The longest wait between two retries, in seconds.
const maxDelaySeconds = 30;
