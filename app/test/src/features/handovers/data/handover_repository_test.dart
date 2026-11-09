import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover_repository.dart';
import 'package:maalik_e_makaan/src/features/ledger/data/ledger.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/fakes.dart';
import '../../../../support/money_fakes.dart';
import '../../../../support/supabase.dart';

const Map<String, Object?> _row = {
  'id': 'ho-1',
  'from_user_id': caretakerId,
  'to_user_id': testUserId,
  'amount': 85000,
  'handed_over_on': '2026-10-07',
  'method': 'raast',
  'reference': 'RAAST 55102',
  'notes': null,
  'confirmed_at': '2026-10-07T12:00:00+00:00',
  'voided_at': null,
  'void_reason': null,
  'created_at': '2026-10-07T09:00:00+00:00',
};

const Map<String, Object?> _position = {
  'user_id': caretakerId,
  'full_name': 'Bilal Ahmed',
  'role': 'manager',
  'cash_collected': 255000,
  'handed_over': 170000,
  'cash_expenses': 4500,
  'cash_in_hand': 80500,
};

void main() {
  late MockSupabase supabase;
  late SupabaseHandoverRepository repository;

  setUp(() {
    supabase = MockSupabase((request) async {
      if (request.url.path.endsWith('/get_cash_positions')) {
        return jsonResponse([_position]);
      }
      return jsonResponse(
        request.headers['accept'] == 'application/vnd.pgrst.object+json' ||
                request.url.path.contains('/rpc/')
            ? _row
            : [_row],
      );
    });
    repository = SupabaseHandoverRepository(supabase.client);
  });

  test('models read their rows and survive the cache', () {
    final handover = CashHandover.fromRow(_row);
    expect(handover.confirmed, isTrue);
    expect(handover.voided, isFalse);
    expect(handover.method, PaymentMethod.raast);
    expect(CashHandover.fromRow(handover.toRow()), handover);
    expect(CashHandover.fromRow(handover.toRow()).hashCode, handover.hashCode);
    final position = CashPosition.fromRow(_position);
    expect(position.role, MemberRole.manager);
    expect(position.inHand, const Money.fromRupees(80500));
    expect(CashPosition.fromRow(position.toRow()).hashCode, position.hashCode);
    expect(
      CashPosition.fromRow(Map.of(_position)..['full_name'] = null).fullName,
      '',
    );
    final book = CashBook(positions: [position], handovers: Paged([handover]));
    expect(CashBook.fromJson(book.toJson()), book);
    expect(CashBook.fromJson(book.toJson()).hashCode, book.hashCode);
    expect(book.nameOf(caretakerId), 'Bilal Ahmed');
    expect(book.nameOf(testUserId), isNull);
    expect(
      () => CashHandover.fromRow(Map.of(_row)..['method'] = 'gold'),
      throwsFormatException,
    );
    final draft = HandoverDraft(
      fromUserId: caretakerId,
      toUserId: testUserId,
      amount: const Money.fromRupees(5000),
      handedOverOn: CalendarDate(2026, 11, 7),
      reference: ' ',
      notes: ' Rent of Shop 1 ',
    );
    expect(draft.toWrite(), {
      'from_user_id': caretakerId,
      'to_user_id': testUserId,
      'amount': '5000.00',
      'handed_over_on': '2026-11-07',
      'method': 'cash',
      'reference': null,
      'notes': 'Rent of Shop 1',
    });
    expect(draft.hashCode, isA<int>());
  });

  test('the cash book reads positions and the first page', () async {
    final book = await repository.cashBook(gulberg.id);
    expect(book.positions.single.fullName, 'Bilal Ahmed');
    expect(book.handovers.items.single.id, 'ho-1');
    final page = supabase.requests.firstWhere(
      (r) => r.url.path.endsWith('/cash_handovers'),
    );
    expect(page.url.queryParameters, {
      'select': CashHandover.columns,
      'portfolio_id': 'eq.${gulberg.id}',
      'order': 'created_at.desc.nullslast,id.desc.nullslast',
      'limit': '50',
    });
    await repository.handovers(
      gulberg.id,
      before: const PageCursor(createdAt: 'x', id: 'y'),
    );
    expect(supabase.requests.last.url.queryParameters['or'], isNotNull);
  });

  test('recording, a retry, confirming and voiding', () async {
    final draft = HandoverDraft(
      fromUserId: caretakerId,
      toUserId: testUserId,
      amount: const Money.fromRupees(85000),
      handedOverOn: CalendarDate(2026, 10, 7),
      method: PaymentMethod.raast,
    );
    await repository.record(id: 'ho-1', portfolioId: gulberg.id, draft: draft);
    expect(bodyOf(supabase.request), {
      'id': 'ho-1',
      'portfolio_id': gulberg.id,
      ...draft.toWrite(),
    });
    supabase.respond = (request) async => request.method == 'POST'
        ? postgrestError('23505', status: 409)
        : jsonResponse(_row);
    expect(
      (await repository.record(
        id: 'ho-1',
        portfolioId: gulberg.id,
        draft: draft,
      )).id,
      'ho-1',
    );
    supabase.respond = (_) async => jsonResponse(_row);
    await repository.confirm('ho-1');
    expect(bodyOf(supabase.requests.last), {'p_handover_id': 'ho-1'});
    await repository.voidHandover('ho-1', ' Was an expense ');
    expect(bodyOf(supabase.requests.last), {
      'p_handover_id': 'ho-1',
      'p_reason': 'Was an expense',
    });
    supabase.respond = (_) async =>
        postgrestError('22023', message: 'already_voided');
    await expectLater(
      repository.confirm('ho-1'),
      throwsA(
        isA<RejectedFailure>().having((f) => f.reason, 'r', 'already_voided'),
      ),
    );
  });
}
