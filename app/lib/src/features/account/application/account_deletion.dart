import 'package:flutter/foundation.dart';
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
///
/// Back cancels a deletion until its request is sent, and waits once it is
/// on its way (the owner's decision; `docs/architecture/app.md`, Hooks): the
/// router asks [leave] as the delete screen is left, and the screen shows
/// [sending].
final class AccountDeletionController extends AsyncNotifier<DeletionPreview> {
  /// The user the preview was built for, if anyone was signed in.
  String? _userId;

  /// The deletion that runs now, until [leave] cancels it while its
  /// password is checked; one started since replaces it.
  Object? _running;

  final _sending = ValueNotifier<bool>(false);

  /// Whether a deletion's request is on its way: from the moment it is sent
  /// until the command ends, its sign-out included. The delete screen
  /// cannot be left meanwhile ([leave]), so Cancel waits and the page
  /// cannot be popped.
  ValueListenable<bool> get sending => _sending;

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

  /// Whether the delete screen may be left now: asked by the router as it
  /// is left, whichever way (`GoRoute.onExit`: Back, Cancel, another
  /// section, a link, or the router's own redirect).
  ///
  /// While a deletion's password is checked, leaving cancels it: the check
  /// goes on, and once it answers nothing is sent and nobody is signed out.
  /// Once the request is on its way ([sending]), the screen stays until the
  /// command ends, so that leaving never looks like cancelling,
  /// unless nobody is signed in any more: the router then leaves it for the
  /// sign-in screen (or the new password), and the command ends without it.
  bool leave() {
    if (!_sending.value) {
      _running = null;
      return true;
    }
    return ref.read(authStatusProvider) is! SignedIn;
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
  /// command throws [SessionExpired]; the invitation stays, since that
  /// account's sign-in replaced the session with a plain sign-out's wipe,
  /// and the invitation may be that account's now. When nobody does (the
  /// session was signed out elsewhere, whose wipe kept the invitation) or
  /// the same account signed in again, the device is signed out as above,
  /// unless a store that does not answer holds up that earlier wipe while
  /// the same account's sign-in waits behind it: that sign-in then clears
  /// the cause, so the sign-in screen does not say the account was deleted,
  /// and the invitation may stay (app.md, Hooks).
  ///
  /// The screen left while the password is checked ([leave]: Back,
  /// Cancel), it returns once the check answers, having sent nothing and
  /// signed nobody out. From the moment the request is sent until
  /// the command ends, [sending] is true.
  ///
  /// It reads everything it uses before its first wait, and [ref] not
  /// after: the delete screen is this autoDispose provider's only listener,
  /// and leaving it disposes the provider. While the password is checked
  /// that cancels the command; once the request is on its way, only the
  /// router at a sign-out leaves the screen, and the command goes on
  /// without it.
  ///
  /// Throws [AppFailure] when the account was certainly not deleted:
  /// `invalid_credentials` for a wrong password, `does_not_match_account`
  /// when [confirmEmail] is not the account's.
  Future<void> deleteAccount({
    required String password,
    required String confirmEmail,
  }) async {
    final auth = ref.read(authStatusProvider.notifier);
    final device = ref.read(authRepositoryProvider);
    final accounts = ref.read(accountRepositoryProvider);
    final session = ref.read(sessionProvider);
    final cache = ref.read(swrCacheProvider)
      ..require(session?.userId, session?.epoch ?? 0);
    final (:userId, :epoch) = session!;
    final running = _running = Object();
    await auth.reauthenticate(password);
    // Left while the password was checked: nothing is sent.
    if (!identical(_running, running)) return;
    cache.require(userId, epoch);
    _sending.value = true;
    try {
      await _delete(accounts, device, auth, userId, confirmEmail);
    } finally {
      _sending.value = false;
    }
  }

  /// Deletes the account with [confirmEmail], then signs [userId] out of
  /// this device through [auth] as the answer says ([_signOutDeleted]).
  /// Static, so that it cannot reach [ref], which may be disposed by now.
  static Future<void> _delete(
    AccountRepository accounts,
    AuthRepository device,
    AuthController auth,
    String userId,
    String confirmEmail,
  ) async {
    try {
      await accounts.deleteAccount(confirmEmail: confirmEmail);
    } on AppFailure catch (failure) {
      if (!mayHaveDeleted(failure)) rethrow;
      await _signOutDeleted(
        device,
        auth,
        userId,
        SignOutCause.deletionUnconfirmed,
      );
      return;
    }
    await _signOutDeleted(device, auth, userId, SignOutCause.accountDeleted);
  }

  /// Signs the device out through [auth] with [cause] after [userId]'s
  /// account was deleted, or may have been, unless another account holds
  /// the device now: then it throws [SessionExpired] and signs nobody out.
  /// Static, so that it cannot reach [ref], which may be disposed by now.
  ///
  /// Decided from the session the device holds ([device]'s
  /// [AuthRepository.status]) as it signs out, with nothing awaited in
  /// between: gotrue changes that session before it announces the change,
  /// and the status the app shows ([authStatusProvider]) follows only once
  /// the wipe for the change has run, so until then it, and maybe the
  /// cache, still name the deleting account. Whether the cache serves the
  /// session that asked does not decide either: its epoch moves at any
  /// sign-out, also one after which nobody, or the same account, holds the
  /// device.
  ///
  /// gotrue drops the session before its first await, and on the web its
  /// one wait before it tells the other tabs ends in microtasks, so no
  /// message of theirs comes in between. A sign-in in another tab whose
  /// message has not arrived yet is not seen: it crosses this sign-out, as
  /// it would any, and that tab drops the account it signed in.
  static Future<void> _signOutDeleted(
    AuthRepository device,
    AuthController auth,
    String userId,
    SignOutCause cause,
  ) async {
    final holder = switch (device.status) {
      SignedIn(userId: final held) ||
      RecoveringPassword(userId: final held) => held,
      SignedOut() => null,
    };
    if (holder != null && holder != userId) throw const SessionExpired();
    await auth.signOut(cause: cause);
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
