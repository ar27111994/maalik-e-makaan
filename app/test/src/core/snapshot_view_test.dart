import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/core/snapshot_view.dart';
import 'package:maalik_e_makaan/src/data/cache/swr_cache.dart';

import '../../support/harness.dart';

const _failed = 'The test could not be loaded';
const _loading = 'Loading the test';
const _ended = 'Your session has ended. Please sign in again.';

Widget _view(AsyncValue<Snapshot<int>> state, {VoidCallback? onRetry}) =>
    Scaffold(
      body: SnapshotView<int>(
        state: state,
        onRetry: onRetry ?? () {},
        loadingLabel: _loading,
        failedTitle: _failed,
        builder: (value) => Text('value $value'),
      ),
    );

/// What a screen shows of a query whose state the test sets.
Future<void> _pump(WidgetTester tester, AsyncValue<Snapshot<int>> state) =>
    pumpScreen(tester, () => _view(state), settle: false);

void main() {
  testWidgets("an account's session that changed shows the skeleton and its "
      'loading label, not a failure (sessionChanged, waitsForSession)', (
    tester,
  ) async {
    await _pump(tester, sessionChanged());
    expect(find.bySemanticsLabel(_loading), findsOneWidget);
    expect(find.text(_failed), findsNothing);
    expect(find.text(_ended), findsNothing);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('a SessionExpired that failed the read shows the failure', (
    tester,
  ) async {
    await _pump(tester, AsyncError(const SessionExpired(), StackTrace.current));
    expect(find.text(_failed), findsOneWidget);
    expect(find.text(_ended), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.bySemanticsLabel(_loading), findsNothing);
  });

  testWidgets('a lost connection shows the failure', (tester) async {
    await _pump(tester, AsyncError(const NetworkFailure(), StackTrace.current));
    expect(find.text(_failed), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.bySemanticsLabel(_loading), findsNothing);
  });

  testWidgets('a SessionExpired that failed the read stays on show while '
      '"Try again" loads, then the value comes', (tester) async {
    // Riverpod keeps a provider's error while it is built again, as every
    // screen's "Try again" does: the state is then loading with that error
    // and no value, as sessionChanged's is, but its error is a real one.
    var answer = Completer<Snapshot<int>>();
    final query = FutureProvider<Snapshot<int>>((ref) => answer.future);
    await pumpScreen(
      tester,
      () => Consumer(
        builder: (context, ref, _) =>
            _view(ref.watch(query), onRetry: () => ref.invalidate(query)),
      ),
      settle: false,
    );
    answer.completeError(const SessionExpired(), StackTrace.current);
    await tester.pump();
    expect(find.text(_ended), findsOneWidget);
    answer = Completer();
    await tester.tap(find.text('Try again'));
    await tester.pump();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(SnapshotView<int>)),
    );
    final retrying = container.read(query);
    expect(retrying.isLoading, isTrue);
    expect(retrying.error, isA<SessionExpired>());
    expect(retrying.hasValue, isFalse);
    expect(waitsForSession(retrying), isFalse);
    expect(find.text(_failed), findsOneWidget);
    expect(find.text(_ended), findsOneWidget);
    answer.complete(
      Snapshot(
        7,
        savedAt: DateTime.utc(2026, 11, 7),
        source: SnapshotSource.network,
      ),
    );
    await tester.pump();
    expect(find.text('value 7'), findsOneWidget);
    expect(find.text(_failed), findsNothing);
  });
}
