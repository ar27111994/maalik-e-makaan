import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/data/paging.dart';
import 'package:maalik_e_makaan/src/features/notifications/data/notification.dart';
import 'package:maalik_e_makaan/src/features/notifications/data/notification_repository.dart';

import '../../../../support/fakes.dart';
import '../../../../support/supabase.dart';

final Map<String, Object?> _row = {
  'id': 'n-1',
  'kind': 'rent_overdue',
  'params': {'lease_id': aliLease.id, 'amount': 25000, 'tenant_name': 'Ali'},
  'entity_type': 'charge',
  'entity_id': 'ch-rent-10',
  'read_at': null,
  'created_at': '2026-11-07T01:00:00+00:00',
};

void main() {
  late MockSupabase supabase;
  late SupabaseNotificationRepository repository;

  setUp(() {
    supabase = MockSupabase((request) async {
      if (request.method == 'HEAD' ||
          request.headers['prefer']?.contains('count=exact') == true) {
        return jsonResponse([
          {'id': 'n-1'},
        ], status: 206)..headers['content-range'] = '0-0/3';
      }
      return jsonResponse([_row]);
    });
    repository = SupabaseNotificationRepository(supabase.client);
  });

  test('a notification reads its kind and details', () {
    final n = AppNotification.fromRow(_row);
    expect(n.kind, NotificationKind.rentOverdue);
    expect(n.unread, isTrue);
    expect(n.text('lease_id'), aliLease.id);
    expect(n.text('amount'), isNull);
    expect(n.created, DateTime.utc(2026, 11, 7, 1));
    expect(AppNotification.fromRow(n.toRow()), n);
    expect(AppNotification.fromRow(n.toRow()).hashCode, n.hashCode);
    final read = n.read(DateTime.utc(2026, 11, 7, 2));
    expect(read.unread, isFalse);
    final future = AppNotification.fromRow({..._row, 'kind': 'new_kind'});
    expect(future.kind, NotificationKind.unknown);
    expect(
      AppNotification.fromRow(future.toRow()).kind,
      NotificationKind.unknown,
    );
    for (final kind in NotificationKind.values) {
      if (kind != NotificationKind.unknown) {
        expect(NotificationKind.parse(kind.db), kind);
      }
    }
    expect(
      () => AppNotification.fromRow({..._row, 'params': null}),
      throwsFormatException,
    );
  });

  test('a page of the portfolio, newest first', () async {
    final page = await repository.notifications(
      gulberg.id,
      before: const PageCursor(createdAt: 'x', id: 'y'),
    );
    expect(page.items.single.id, 'n-1');
    final query = supabase.request.url.queryParameters;
    expect(query['portfolio_id'], 'eq.${gulberg.id}');
    expect(query['order'], 'created_at.desc.nullslast,id.desc.nullslast');
    expect(query['or'], isNotNull);
  });

  test('the unread count asks for a count', () async {
    expect(await repository.unreadCount(gulberg.id), 3);
    expect(supabase.request.url.queryParameters['read_at'], 'is.null');
  });

  test('marking read, all read and deleting', () async {
    await repository.markRead(const []);
    expect(supabase.requests, isEmpty);
    await repository.markRead(const ['n-1']);
    expect(bodyOf(supabase.request), {
      'p_ids': ['n-1'],
    });
    await repository.markAllRead(gulberg.id);
    final [_, unread, mark] = supabase.requests;
    expect(unread.url.queryParameters['limit'], '1000');
    expect(bodyOf(mark), {
      'p_ids': ['n-1'],
    });
    await repository.delete('n-1');
    expect(supabase.requests.last.method, 'DELETE');
    expect(supabase.requests.last.url.queryParameters['id'], 'eq.n-1');
    supabase.respond = (_) async => postgrestError('42501', status: 403);
    await expectLater(repository.delete('n-1'), throwsA(isA<Forbidden>()));
  });
}
