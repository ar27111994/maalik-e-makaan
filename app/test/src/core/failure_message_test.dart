import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/failure_message.dart';

void main() {
  final failures = <AppFailure>[
    const NetworkFailure(),
    const SessionExpired(),
    const ReauthenticationRequired(),
    const Forbidden(),
    const NotFoundFailure(),
    const ConflictFailure(),
    const RateLimited(null),
    const RateLimited(Duration(seconds: 30)),
    const TemporarilyUnavailable(),
    const ServerFailure('XX000'),
    UnexpectedFailure(StateError('bug')),
    for (final reason in [
      'invalid_credentials',
      'email_not_confirmed',
      'email_taken',
      'weak_password',
      'same_password',
      'last_owner',
      'confirmation_mismatch',
      'account_deleted',
      'portfolio_limit_reached',
      'already_member',
      'member_not_found',
      'invalid_role',
      'invalid_email',
      'already_voided',
      'amount_exceeds_outstanding',
      'charge_has_payments',
      'charge_not_editable',
      'charge_voided',
      'deposit_already_used',
      'deposit_below_received',
      'insufficient_deposit',
      'document_entity_not_found',
      'document_file_missing',
      'document_file_pending_deletion',
      'idempotency_key_reused',
      'invalid_amount',
      'invalid_charge_selection',
      'invalid_date',
      'invalid_tax_withheld',
      'invalid_tax_year',
      'invalid_method',
      'invalid_reason',
      'reason_required',
      'lease_has_records',
      'lease_not_active',
      'lease_not_on_this_connection',
      'tenant_archived',
      'unit_archived',
      'constraint_violation',
      'link_expired',
      'link_invalid',
      'link_other_device',
      'signup_disabled',
      'mfa_required',
      'does_not_match_account',
      'something_new',
    ])
      RejectedFailure(reason),
  ];

  for (final locale in AppLocalizations.supportedLocales) {
    test('every failure has a sentence in ${locale.languageCode}', () async {
      final l10n = await AppLocalizations.delegate.load(locale);
      final messages = failures.map((f) => failureMessage(l10n, f)).toList();
      expect(messages.every((m) => m.trim().isNotEmpty), isTrue);
      // Distinct failures read differently, except the unknown refusal.
      expect(messages.toSet().length, messages.length);
    });
  }

  test('a known wait is spelled out, with plural forms', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      failureMessage(l10n, const RateLimited(Duration(seconds: 1))),
      contains('1 second.'),
    );
    expect(
      failureMessage(l10n, const RateLimited(Duration(seconds: 30))),
      contains('30 seconds'),
    );
  });
}
