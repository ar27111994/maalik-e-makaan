import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maalik_e_makaan/src/auth/auth_controller.dart';
import 'package:maalik_e_makaan/src/features/account/application/residence.dart';
import 'package:maalik_e_makaan/src/features/portfolios/application/portfolios.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/owner_abroad_question.dart';
import 'package:maalik_e_makaan/src/routing/routes.dart';

/// Whether the signed-in user's residence is still being read from the
/// server, so the residence question may yet be due: it is asked before a
/// portfolio's.
final Provider<bool> _residenceReadingProvider = Provider.autoDispose<bool>((
  ref,
) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;
  final state = ref.watch(residenceProvider(userId));
  if (state.hasError) return false;
  final snapshot = state.value;
  return snapshot == null || (snapshot.fromCache && !snapshot.value.stated);
});

/// Asks the signed-in user the app's open questions, one at a time, over
/// [child] (the shell): first "Do you live in Pakistan?" while they have
/// never answered, then "Does the owner of these properties live abroad?"
/// for a current portfolio nobody has answered for (D-16).
///
/// Each is asked only from what the server just said, never from a saved
/// copy, and never blocks: "Not now", the close button and the back button
/// all set it aside. The residence question then waits seven days on this
/// device (Settings still offers it); a portfolio's question waits until
/// the app runs again, or until that portfolio is opened in another run
/// (Portfolio details still offers it). Nothing is asked while a screen,
/// sheet or dialog is open above the shell.
class ShellQuestions extends ConsumerStatefulWidget {
  const new({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ShellQuestions> createState() => _ShellQuestionsState();
}

class _ShellQuestionsState extends ConsumerState<ShellQuestions> {
  /// Whether a question is open.
  bool _asking = false;

  /// Whether a look for a question waits for the next frame.
  bool _scheduled = false;

  /// The user the residence question was asked of in this run, if any.
  String? _askedResidenceOf;

  @override
  void initState() {
    super.initState();
    ref
      ..listenManual(residenceQuestionProvider, (_, _) => _schedule())
      ..listenManual(_residenceReadingProvider, (_, _) => _schedule())
      ..listenManual(ownerAbroadQuestionProvider, (_, _) => _schedule());
    _schedule();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Depends on whether the shell is the top route, so a screen or a
    // dialog closing above it looks again.
    if (ModalRoute.isCurrentOf(context) ?? true) _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      unawaited(_maybeAsk());
    });
  }

  Future<void> _maybeAsk() async {
    if (_asking || !mounted) return;
    if (!(ModalRoute.isCurrentOf(context) ?? true)) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    if (_askedResidenceOf != userId && ref.read(residenceQuestionProvider)) {
      _asking = true;
      _askedResidenceOf = userId;
      final saved = await GoRouter.of(context).push<bool>(Routes.residence);
      if (mounted && saved != true) {
        final stored = ref.read(residenceProvider(userId)).value?.value;
        if (stored == null || !stored.stated) {
          await ref.read(residenceSnoozeProvider(userId).notifier).snooze();
        }
      }
      _done();
      return;
    }
    if (ref.read(_residenceReadingProvider)) return;
    final id = ref.read(ownerAbroadQuestionProvider);
    final membership = ref.read(currentPortfolioProvider).value;
    if (id == null ||
        membership == null ||
        membership.id != id ||
        ref.read(ownerAbroadDismissedProvider).contains(id)) {
      return;
    }
    _asking = true;
    final answered = await showOwnerAbroadQuestion(context, membership);
    if (mounted && answered != true) {
      ref.read(ownerAbroadDismissedProvider.notifier).dismiss(id);
    }
    _done();
  }

  /// A question closed: look for the next.
  void _done() {
    _asking = false;
    if (mounted) _schedule();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
