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
  /// (`WipeReason.accountDeleted`). When the deletion's answer is lost on
  /// the way (the connection dropped after the server deleted it), the
  /// device is wiped when the session is refused, at its next refresh.
  ///
  /// Throws [AppFailure]: `invalid_credentials` for a wrong password,
  /// `does_not_match_account` when [confirmEmail] is not the account's.
  Future<void> deleteAccount({
    required String password,
    required String confirmEmail,
  }) async {
    final auth = ref.read(authStatusProvider.notifier);
    await auth.reauthenticate(password);
    await ref
        .read(accountRepositoryProvider)
        .deleteAccount(confirmEmail: confirmEmail);
    await auth.signOut(cause: SignOutCause.accountDeleted);
  }
}
