import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/auth/auth_repository.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/providers.dart';
import 'package:maalik_e_makaan/src/features/account/data/account_repository.dart';

/// What deleting the account would remove, and the command that does it.
final AsyncNotifierProvider<AccountDeletionController, DeletionPreview>
accountDeletionProvider =
    AsyncNotifierProvider.autoDispose<
      AccountDeletionController,
      DeletionPreview
    >(AccountDeletionController.new);

/// Loads the [DeletionPreview] and deletes the account.
///
/// It is built again whenever the session changes ([sessionProvider]):
/// built for another user than the build before, or for nobody, it drops
/// the preview on show ([sessionChanged]), since it names the earlier
/// account's portfolios; with nobody signed in it asks for nothing.
final class AccountDeletionController extends AsyncNotifier<DeletionPreview> {
  /// The user the preview was built for, if anyone was signed in.
  String? _userId;

  @override
  Future<DeletionPreview> build() async {
    final userId = ref.watch(sessionProvider)?.userId;
    final repository = ref.watch(accountRepositoryProvider);
    if (!ref.isFirstBuild && userId != _userId) {
      state = sessionChanged();
    }
    _userId = userId;
    if (userId == null) throw const SessionExpired();
    return await repository.deletionPreview();
  }

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
  /// Nothing is asked with no session ([sessionProvider], read before the
  /// request), nor once the device is wiped for its end, and no deletion
  /// once it ends while it signs in again. Once the deletion was answered
  /// as one that deleted or may have, either sign-out is the deleting
  /// account's alone: when another account holds the device by then
  /// (signed in from another tab), that account is not signed out and the
  /// command throws [SessionExpired]. When nobody does (the session was
  /// signed out elsewhere, whose wipe kept the invitation) or the same
  /// account signed in again, the device is signed out as above.
  ///
  /// Throws [AppFailure] when the account was certainly not deleted:
  /// `invalid_credentials` for a wrong password, `does_not_match_account`
  /// when [confirmEmail] is not the account's.
  Future<void> deleteAccount({
    required String password,
    required String confirmEmail,
  }) async {
    final auth = ref.read(authStatusProvider.notifier);
    final session = ref.read(sessionProvider);
    final cache = ref.read(swrCacheProvider)
      ..require(session?.userId, session?.epoch ?? 0);
    final (:userId, :epoch) = session!;
    await auth.reauthenticate(password);
    cache.require(userId, epoch);
    try {
      await ref
          .read(accountRepositoryProvider)
          .deleteAccount(confirmEmail: confirmEmail);
    } on AppFailure catch (failure) {
      if (!mayHaveDeleted(failure)) rethrow;
      await _signOutDeleted(userId, SignOutCause.deletionUnconfirmed);
      return;
    }
    await _signOutDeleted(userId, SignOutCause.accountDeleted);
  }

  /// Signs the device out with [cause] after [userId]'s account was
  /// deleted, or may have been, unless another account holds the device
  /// now: then it throws [SessionExpired] and signs nobody out.
  ///
  /// Decided from the session the device holds ([AuthRepository.status])
  /// as it signs out, with nothing awaited in between: gotrue changes that
  /// session before it announces the change, and the status the app shows
  /// ([authStatusProvider]) follows only once the wipe for the change has
  /// run, so until then it, and maybe the cache, still name the deleting
  /// account. Whether the cache serves the session that asked does not
  /// decide either: its epoch moves at any sign-out, also one after which
  /// nobody, or the same account, holds the device.
  ///
  /// gotrue drops the session before its first await, and on the web its
  /// one wait before it tells the other tabs ends in microtasks, so no
  /// message of theirs comes in between. A sign-in in another tab whose
  /// message has not arrived yet is not seen: it crosses this sign-out, as
  /// it would any, and that tab drops the account it signed in.
  Future<void> _signOutDeleted(String userId, SignOutCause cause) async {
    final holder = switch (ref.read(authRepositoryProvider).status) {
      SignedIn(userId: final held) ||
      RecoveringPassword(userId: final held) => held,
      SignedOut() => null,
    };
    if (holder != null && holder != userId) throw const SessionExpired();
    await ref.read(authStatusProvider.notifier).signOut(cause: cause);
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
