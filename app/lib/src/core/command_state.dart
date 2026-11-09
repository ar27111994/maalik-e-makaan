import 'package:flutter/widgets.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';

/// The state of a screen that runs commands (sign in, save, delete): one at
/// a time, with its progress and its last failure.
///
/// Writes are pessimistic: the button shows [busy] until the server
/// answers, and [failure] holds the refusal to show next to the field it
/// belongs to, or above the form.
mixin CommandState<T extends StatefulWidget> on State<T> {
  /// Whether a command is running.
  bool busy = false;

  /// Why the last command failed; cleared when the next one starts.
  AppFailure? failure;

  /// Runs [command] unless one is running already, and returns whether it
  /// succeeded. Any [AppFailure] it throws is kept in [failure].
  Future<bool> runCommand(Future<void> Function() command) async {
    if (busy) return false;
    setState(() {
      busy = true;
      failure = null;
    });
    try {
      await command();
      return true;
    } on AppFailure catch (error) {
      if (mounted) setState(() => failure = error);
      return false;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// The refusal reason of [failure], if it is one.
  String? get rejectedReason => switch (failure) {
    RejectedFailure(:final reason) => reason,
    _ => null,
  };
}
