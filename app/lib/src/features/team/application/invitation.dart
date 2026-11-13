import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/device/device_data.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/team/data/team.dart';
import 'package:maalik_e_makaan/src/features/team/data/team_repository.dart';
import 'package:maalik_e_makaan/src/settings/app_settings.dart';

/// The invitation link opened on this device and not answered yet: its
/// token, or null.
///
/// It is kept on the device, so it survives signing in or creating an
/// account (whose confirmation link may open in a new tab), and signing
/// out: "sign out, then sign in with the address it was sent to" is how a
/// person signed in with another account takes it up. It is forgotten once
/// the invitation is accepted, refused or set aside, and when the account
/// is deleted (`DeviceDataWipe`). The token names nobody, and only the
/// invited address's verified account can use it.
final pendingInvitationProvider =
    NotifierProvider<PendingInvitationController, String?>(
      PendingInvitationController.new,
    );

/// Holds the pending invitation and accepts it.
final class PendingInvitationController extends Notifier<String?> {
  /// The longest token kept: an invitation id, a dot and a 43-character
  /// verifier, with room for a newer format.
  static const maxTokenLength = 200;

  @override
  String? build() {
    // Read again after a wipe, which forgets it when the account is deleted.
    ref.watch(deviceDataWipesProvider);
    return ref
        .watch(settingsStoreProvider)
        .getString(AppSettings.pendingInvitationKey);
  }

  /// Keeps [token] (from a link's `#token=…`) until it is answered. An empty
  /// or oversized token is not an invitation and is ignored.
  Future<void> hold(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty || trimmed.length > maxTokenLength) return;
    state = trimmed;
    await ref
        .read(settingsStoreProvider)
        .setString(AppSettings.pendingInvitationKey, trimmed);
  }

  /// Forgets the pending invitation.
  Future<void> clear() async {
    state = null;
    await ref
        .read(settingsStoreProvider)
        .remove(AppSettings.pendingInvitationKey);
  }

  /// Accepts the pending invitation for the signed-in user.
  ///
  /// When it is accepted, the portfolio list is read again and the
  /// portfolio becomes the current one. Accepted or refused, the invitation
  /// is then forgotten, unless it was refused because of the signed-in
  /// account (another address, or one not confirmed), which signing in
  /// with the invited address puts right. A failure to reach the server
  /// throws [AppFailure] and keeps it, to try again.
  Future<AcceptOutcome> accept() async {
    final token = state;
    if (token == null) {
      return const InvitationRefused(InvitationRefusal.invalid);
    }
    final outcome = await ref.read(teamRepositoryProvider).accept(token);
    if (outcome is InvitationAccepted) {
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        try {
          await ref.read(portfoliosProvider(userId).notifier).reload();
        } on AppFailure {
          ref.invalidate(portfoliosProvider(userId));
        }
        await ref
            .read(selectedPortfolioProvider(userId).notifier)
            .select(outcome.portfolioId);
      }
    }
    // Signed in with another address, or one not confirmed yet: kept, so
    // signing in with the invited address picks it up again.
    final retryable =
        outcome is InvitationRefused &&
        (outcome.reason == InvitationRefusal.emailMismatch ||
            outcome.reason == InvitationRefusal.emailNotVerified);
    if (!retryable) await clear();
    return outcome;
  }
}

/// The token of an invitation link's fragment (`#token=…`), or null.
String? invitationToken(Uri link) {
  if (!link.hasFragment || link.fragment.isEmpty) return null;
  final Map<String, String> parameters;
  try {
    parameters = Uri.splitQueryString(link.fragment);
  } on FormatException {
    return null;
  }
  final token = parameters['token']?.trim();
  return token == null || token.isEmpty ? null : token;
}
