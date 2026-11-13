import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/account/data/account_repository.dart';

/// What deleting the account would remove, and the command that does it.
final AsyncNotifierProvider<AccountDeletionController, DeletionPreview>
accountDeletionProvider =
    AsyncNotifierProvider.autoDispose<
      AccountDeletionController,
      DeletionPreview
    >(AccountDeletionController.new);

/// Loads the [DeletionPreview] and deletes the account.
final class AccountDeletionController extends AsyncNotifier<DeletionPreview> {
  @override
  Future<DeletionPreview> build() =>
      ref.watch(accountRepositoryProvider).deletionPreview();

  /// Deletes the account: signs in again with [password] (the server asks
  /// for a recent sign-in), deletes it with [confirmEmail] as the typed
  /// confirmation, then signs out of this device, which wipes what the
  /// device kept for the account, the invitation it held included
  /// (`WipeReason.accountDeleted`).
  ///
  /// When the deletion's answer is lost on the way, or the server failed
  /// part-way ([mayHaveDeleted]), the account may be gone: the device signs
  /// out and is wiped all the same ([SignOutCause.deletionUnconfirmed]),
  /// rather than show a deleted account's records until its session is
  /// refused. Signing in again tells whether it still exists.
  ///
  /// Throws [AppFailure] when the account was certainly not deleted:
  /// `invalid_credentials` for a wrong password, `does_not_match_account`
  /// when [confirmEmail] is not the account's.
  Future<void> deleteAccount({
    required String password,
    required String confirmEmail,
  }) async {
    final auth = ref.read(authStatusProvider.notifier);
    await auth.reauthenticate(password);
    try {
      await ref
          .read(accountRepositoryProvider)
          .deleteAccount(confirmEmail: confirmEmail);
    } on AppFailure catch (failure) {
      if (!mayHaveDeleted(failure)) rethrow;
      await auth.signOut(cause: SignOutCause.deletionUnconfirmed);
      return;
    }
    await auth.signOut(cause: SignOutCause.accountDeleted);
  }
}

/// Whether the server may have deleted the account although deleting it
/// failed with [failure]: the request was sent (the sign-in just before it
/// reached the server) and its answer was lost ([NetworkFailure]), or the
/// server failed after it may have started ([ServerFailure],
/// [UnexpectedFailure]). A refusal, a rate limit or a busy database
/// ([TemporarilyUnavailable], which rolls back) deleted nothing.
bool mayHaveDeleted(AppFailure failure) => switch (failure) {
  NetworkFailure() || ServerFailure() || UnexpectedFailure() => true,
  _ => false,
};
