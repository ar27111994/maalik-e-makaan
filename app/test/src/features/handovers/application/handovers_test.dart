import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/features/handovers/application/handovers.dart';
import 'package:maalik_e_makaan/src/features/handovers/data/handover.dart';
import 'package:maalik_e_makaan/src/features/ledger/application/ledger.dart';
import 'package:maalik_e_makaan/src/features/reminders/application/reminders.dart';
import 'package:maalik_e_makaan/src/features/reminders/data/reminder.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/container.dart';
import '../../../../support/harness.dart';

int _count(List<Call> calls, String name) =>
    calls.where((c) => c.$1 == name).length;

void main() {
  test(
    'each handover command shows the cash book as the server holds it',
    () async {
      final app = TestApp();
      final container = containerFor(app);
      final provider = cashBookProvider(gulberg.id);
      listen(container, provider);
      await pumpEventQueue();
      final controller = container.read(provider.notifier);

      Future<void> expectReread(Future<void> Function() command) async {
        final reads = _count(app.handovers.calls, 'cashBook');
        await command();
        expect(_count(app.handovers.calls, 'cashBook'), reads + 1);
      }

      await expectReread(
        () => controller.record(
          'ho-new',
          HandoverDraft(
            fromUserId: caretakerId,
            toUserId: testUserId,
            amount: const Money.fromRupees(5000),
            handedOverOn: CalendarDate(2026, 11, 7),
          ),
        ),
      );
      expect(
        container.read(provider).value!.value.handovers.items.first.id,
        'ho-new',
      );
      await expectReread(() => controller.confirm('ho-new'));
      expect(
        container.read(provider).value!.value.handovers.items.first.confirmed,
        isTrue,
      );
      await expectReread(
        () => controller.voidHandover('ho-new', 'Typed twice'),
      );
      expect(
        container.read(provider).value!.value.handovers.items.first.voided,
        isTrue,
      );
    },
  );

  test('a reminder logged reads the who-owes-what list again', () async {
    final app = TestApp();
    final container = containerFor(app);
    listen(container, receivablesProvider(gulberg));
    final reminders = remindersProvider(aliLease.id);
    listen(container, reminders);
    await pumpEventQueue();
    final reads = _count(app.ledger.calls, 'receivables');
    await container
        .read(reminders.notifier)
        .log(
          id: 'rem-9',
          portfolioId: gulberg.id,
          template: ReminderTemplate.overdue,
          language: ReminderLanguage.urdu,
          message: 'x',
        );
    await pumpEventQueue();
    expect(_count(app.ledger.calls, 'receivables'), greaterThan(reads));
  });
}
