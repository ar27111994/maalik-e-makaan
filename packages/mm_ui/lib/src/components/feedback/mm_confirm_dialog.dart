import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/feedback/mm_filled_action.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_motion.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// Asks the landlord to confirm an action before it happens, and completes
/// with true only when they confirm.
///
/// A dialog with the [title] (a heading that names the dialog), the
/// [message] saying what will happen, a "Cancel" text button (the word
/// comes from `MmLocalizations`) and a filled confirm button labelled
/// [confirmLabel], a verb that repeats the action ("Remove tenant", never
/// "OK"). Cancel, a tap outside the dialog, the back button and Escape all
/// complete with false.
///
/// A [destructive] action (removing a tenant, deleting a payment) fills the
/// confirm button in the overdue colour and puts the keyboard focus on
/// Cancel, so a stray Enter does no harm. For an action that cannot be
/// undone, give [typedConfirmation] (the property's or tenant's name): a
/// field labelled [typedConfirmationLabel] ("Type Gulberg House to
/// confirm") appears, showing the text as its hint, and the confirm button
/// stays disabled until the field holds exactly that text, ignoring
/// surrounding spaces.
///
/// Long titles, messages and labels wrap, the dialog scrolls at large text,
/// and its buttons stack when they do not fit side by side.
///
/// ```dart
/// final remove = await showMmConfirmDialog(
///   context,
///   title: l10n.removeTenantTitle(tenant.name),
///   message: l10n.removeTenantMessage,
///   confirmLabel: l10n.removeTenant,
///   destructive: true,
/// );
/// if (remove) await tenants.remove(tenant);
/// ```
Future<bool> showMmConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
  String? typedConfirmation,
  String? typedConfirmationLabel,
}) async {
  assert(
    typedConfirmation == null || typedConfirmationLabel != null,
    'A typed confirmation needs a label for its field.',
  );
  assert(
    typedConfirmation == null || typedConfirmation.trim().isNotEmpty,
    'A typed confirmation needs text to type.',
  );
  final confirmed = await showDialog<bool>(
    context: context,
    animationStyle: AnimationStyle(
      duration: MmMotion.of(context, MmDuration.standard),
      reverseDuration: MmMotion.of(context, MmDuration.quick),
    ),
    builder: (context) => MmConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
      typedConfirmation: typedConfirmation,
      typedConfirmationLabel: typedConfirmationLabel,
    ),
  );
  return confirmed ?? false;
}

/// The dialog [showMmConfirmDialog] shows: it pops its route with true
/// when confirmed and false when cancelled.
///
/// Internal to the feedback family: apps call [showMmConfirmDialog].
class MmConfirmDialog extends StatefulWidget {
  /// Creates the dialog; the parameters are [showMmConfirmDialog]'s.
  const new({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
    required this.typedConfirmation,
    required this.typedConfirmationLabel,
    super.key,
  });

  /// The question, naming the action ("Remove Ali Raza?").
  final String title;

  /// What will happen if the landlord confirms.
  final String message;

  /// The confirm button's label, a verb ("Remove tenant").
  final String confirmLabel;

  /// Whether the action removes or destroys a record.
  final bool destructive;

  /// The text the landlord must type before confirming, if any.
  final String? typedConfirmation;

  /// The label of the field [typedConfirmation] is typed into.
  final String? typedConfirmationLabel;

  @override
  State<MmConfirmDialog> createState() => _MmConfirmDialogState();
}

class _MmConfirmDialogState extends State<MmConfirmDialog> {
  final _typed = TextEditingController();

  @override
  void initState() {
    super.initState();
    _typed.addListener(_typedChanged);
  }

  @override
  void dispose() {
    _typed.dispose();
    super.dispose();
  }

  void _typedChanged() => setState(() {});

  /// Whether the landlord may confirm: always, or once the field holds the
  /// typed confirmation.
  bool get _ready {
    final expected = widget.typedConfirmation;
    return expected == null || _typed.text.trim() == expected;
  }

  void _confirm() => Navigator.of(context).pop(true);

  void _cancel() => Navigator.of(context).pop(false);

  @override
  Widget build(BuildContext context) {
    final strings = MmLocalizations.of(context);
    final expected = widget.typedConfirmation;
    return AlertDialog(
      scrollable: true,
      semanticLabel: widget.title,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: MmSpace.s4,
        vertical: MmSpace.s6,
      ),
      title: Semantics(header: true, child: Text(widget.title)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.message),
          if (expected != null) ...[
            const SizedBox(height: MmSpace.s4),
            _TypedField(
              controller: _typed,
              label: widget.typedConfirmationLabel!,
              expected: expected,
              onSubmitted: _ready ? _confirm : null,
            ),
          ],
        ],
      ),
      actionsOverflowButtonSpacing: MmSpace.s2,
      actions: [
        TextButton(
          onPressed: _cancel,
          autofocus: widget.destructive,
          child: Text(strings.cancel),
        ),
        MmFilledAction(
          label: widget.confirmLabel,
          destructive: widget.destructive,
          onPressed: _ready ? _confirm : null,
        ),
      ],
    );
  }
}

/// The field a landlord types the confirmation into, labelled above.
class _TypedField extends StatelessWidget {
  const new({
    required this.controller,
    required this.label,
    required this.expected,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String expected;
  final VoidCallback? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final text = Theme.of(context).textTheme;
    final onSubmitted = this.onSubmitted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The label is the field's accessible name, set on its node below;
        // the visible copy is hidden so it is not read twice.
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(bottom: MmSpace.s2),
            child: Text(label, style: text.labelLarge),
          ),
        ),
        Semantics(
          label: label,
          child: TextField(
            controller: controller,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            // Latin text (a name typed in English) is typed left to right
            // in both languages.
            textDirection: MmSemantics.hasArabicScript(expected)
                ? null
                : TextDirection.ltr,
            style: mm.styleFor(expected, text.bodyLarge!),
            decoration: InputDecoration(
              hintText: expected,
              hintStyle: mm.styleFor(
                expected,
                text.bodyLarge!.copyWith(color: mm.colors.inkMuted),
              ),
            ),
            onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
          ),
        ),
      ],
    );
  }
}
