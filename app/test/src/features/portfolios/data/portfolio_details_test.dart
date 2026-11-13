import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_details.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_repository.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/fakes.dart';
import '../../../../support/supabase.dart';

/// A `portfolios` row as PostgREST returns it (numeric as a JSON number).
final Map<String, Object?> _row = {
  'id': gulberg.id,
  'name': 'Gulberg Houses',
  'default_due_day': 5,
  'default_grace_days': 5,
  'default_increment_percent': 10.0,
  'landlord_name': 'Ayesha Khan',
  'landlord_phone': '+923001234567',
  'raast_id': '+923001234567',
  'bank_account_title': 'Ayesha Khan',
  'bank_iban': 'PK36SCBL0000001123456702',
  'owner_abroad': null,
  'caretaker_user_id': null,
  'caretaker_since': null,
};

void main() {
  late MockSupabase supabase;
  late SupabasePortfolioRepository repository;

  setUp(() {
    supabase = MockSupabase((_) async => jsonResponse(_row));
    repository = SupabasePortfolioRepository(supabase.client);
  });

  group('PortfolioDetails.fromRow', () {
    test('reads every setting', () {
      final details = PortfolioDetails.fromRow(_row);
      expect(details, gulbergDetails);
      expect(details.hashCode, gulbergDetails.hashCode);
      expect(PortfolioDetails.fromRow(details.toRow()), details);
      final bare = PortfolioDetails.fromRow({
        ..._row,
        'default_increment_percent': '12.5',
        'landlord_name': null,
        'landlord_phone': null,
        'raast_id': null,
        'bank_account_title': null,
        'bank_iban': null,
      });
      expect(bare.defaultIncrementBasisPoints, 1250);
      expect(bare.bankIban, isNull);
      expect(bare, isNot(details));
    });

    test('reads the owner-abroad answer and the caretaker', () {
      final details = PortfolioDetails.fromRow({
        ..._row,
        'owner_abroad': true,
        'caretaker_user_id': bilalMember.userId,
        'caretaker_since': '2026-11-12T10:15:00.123456+00:00',
      });
      expect(details.ownerAbroad, OwnerAbroad.abroad);
      expect(
        details.caretaker,
        Caretaker(
          userId: bilalMember.userId,
          since: DateTime.utc(2026, 11, 12, 10, 15, 0, 123, 456),
        ),
      );
      expect(details.caretaker.hashCode, details.caretaker.hashCode);
      expect(PortfolioDetails.fromRow(details.toRow()), details);
      expect(details, isNot(gulbergDetails));
      expect(
        PortfolioDetails.fromRow({..._row, 'owner_abroad': false}).ownerAbroad,
        OwnerAbroad.inPakistan,
      );
    });

    test('refuses malformed rows', () {
      for (final row in <Object?>[
        null,
        {..._row}..remove('bank_iban'),
        // Saved by an app version before the question: read again.
        {..._row}..remove('owner_abroad'),
        {..._row}..remove('caretaker_since'),
        {..._row, 'owner_abroad': 'no'},
        {..._row, 'caretaker_user_id': bilalMember.userId},
        {..._row, 'caretaker_since': '2026-11-12T10:15:00Z'},
        {..._row, 'default_due_day': '5'},
        {..._row, 'default_increment_percent': 150},
        {..._row, 'landlord_phone': '0300 1234567'},
        {..._row, 'bank_iban': 'PK00SCBL0000001123456702'},
      ]) {
        expect(
          () => PortfolioDetails.fromRow(row),
          throwsFormatException,
          reason: '$row',
        );
      }
    });

    test('writes only the columns a client may update, tidied', () {
      final update = PortfolioDetails(
        id: gulberg.id,
        name: '  Gulberg   Houses ',
        defaultDueDay: 1,
        defaultGraceDays: 0,
        defaultIncrementBasisPoints: 750,
        landlordName: '   ',
        bankAccountTitle: ' Ayesha  Khan ',
        // Never written by a save: no client may (42501 for the whole row).
        ownerAbroad: OwnerAbroad.abroad,
        caretaker: Caretaker(
          userId: bilalMember.userId,
          since: DateTime.utc(2026, 11, 12),
        ),
      ).toUpdate();
      expect(update, {
        'name': 'Gulberg Houses',
        'default_due_day': 1,
        'default_grace_days': 0,
        'default_increment_percent': '7.5',
        'landlord_name': null,
        'landlord_phone': null,
        'raast_id': null,
        'bank_account_title': 'Ayesha Khan',
        'bank_iban': null,
      });
    });
  });

  group('requests', () {
    test('details reads one portfolio', () async {
      expect(await repository.details(gulberg.id), gulbergDetails);
      final request = supabase.request;
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/portfolios');
      expect(request.url.queryParameters, {
        'select': PortfolioDetails.columns,
        'id': 'eq.${gulberg.id}',
      });
      expect(request.headers['accept'], 'application/vnd.pgrst.object+json');
    });

    test('updateDetails patches and reads back', () async {
      final saved = await repository.updateDetails(gulbergDetails);
      expect(saved, gulbergDetails);
      final request = supabase.request;
      expect(request.method, 'PATCH');
      expect(request.url.queryParameters, {
        'id': 'eq.${gulberg.id}',
        'select': PortfolioDetails.columns,
      });
      expect(bodyOf(request), {
        'name': 'Gulberg Houses',
        'default_due_day': 5,
        'default_grace_days': 5,
        'default_increment_percent': '10',
        'landlord_name': 'Ayesha Khan',
        'landlord_phone': '+923001234567',
        'raast_id': '+923001234567',
        'bank_account_title': 'Ayesha Khan',
        'bank_iban': 'PK36SCBL0000001123456702',
      });
    });

    test('failures are AppFailures', () async {
      supabase.respond = (_) async => postgrestError('23514');
      await expectLater(
        repository.updateDetails(gulbergDetails),
        throwsA(
          isA<RejectedFailure>().having(
            (f) => f.reason,
            'reason',
            'constraint_violation',
          ),
        ),
      );
      supabase.respond = (_) async =>
          postgrestError('PGRST116', status: 406, message: '0 rows');
      await expectLater(
        repository.details(gulberg.id),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  test('the test IBAN is real', () {
    expect(Iban.tryParse('PK36SCBL0000001123456702'), isNotNull);
  });
}
