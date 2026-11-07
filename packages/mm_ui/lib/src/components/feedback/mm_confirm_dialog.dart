import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:mm_ui/src/components/feedback/mm_filled_action.dart';
import 'package:mm_ui/src/foundation/mm_script_text.dart';
import 'package:mm_ui/src/l10n/mm_localizations.dart';
import 'package:mm_ui/src/theme/mm_motion.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/theme/mm_theme.dart';
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
/// confirm", which must contain the text to type) appears, with the text to
/// type set in bold in its label, and the confirm button stays disabled
/// until the field holds exactly that text, ignoring surrounding spaces.
/// The field starts empty, and text in Latin script is typed left to right
/// in both languages.
///
/// Long titles, messages and labels wrap, the dialog scrolls at large text,
/// and its buttons stack when they do not fit side by side. Its inner
/// padding shrinks as text grows, from 24 dp to no less than 16 dp. In
/// dark and high-contrast modes it has the outline of overlays, where it
/// would otherwise melt into the dimmed page. Figures and Latin words in
/// an Urdu title, message or label are set in the Latin face.
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
  assert(
    typedConfirmation == null ||
        typedConfirmationLabel!.contains(typedConfirmation),
    'The label of a typed confirmation must show the text to type.',
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

  /// The text scale at which the dialog's inner padding has shrunk to
  /// [MmSpace.s4], from [MmSpace.s6] at 100%.
  static const double _smallestPaddingScale = 1.5;

  @override
  Widget build(BuildContext context) {
    final strings = MmLocalizations.of(context);
    final theme = Theme.of(context);
    final mm = context.mm;
    final expected = widget.typedConfirmation;
    // Material shrinks a dialog's padding to 8 dp at 200% text; this keeps
    // at least the page's 16 dp, given to the title, content and actions
    // directly so that Material's scaling does not apply.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final padding = lerpDouble(
      MmSpace.s6,
      MmSpace.s4,
      ((scale - 1) / (_smallestPaddingScale - 1)).clamp(0, 1),
    )!;
    final shape = theme.dialogTheme.shape;
    return AlertDialog(
      scrollable: true,
      semanticLabel: widget.title,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: MmSpace.s4,
        vertical: MmSpace.s6,
      ),
      shape: shape is OutlinedBorder
          ? shape.copyWith(
              side: MmTheme.overlayEdge(
                mm.colors,
                brightness: theme.brightness,
                highContrast: mm.highContrast,
              ),
            )
          : shape,
      titlePadding: EdgeInsets.zero,
      title: Padding(
        padding: EdgeInsetsDirectional.only(
          start: padding,
          top: padding,
          end: padding,
        ),
        child: Semantics(
          header: true,
          child: MmScriptText(widget.title, style: const TextStyle()),
        ),
      ),
      contentPadding: EdgeInsetsDirectional.only(
        top: MmSpace.s4,
        bottom: padding,
      ),
      content: Padding(
        padding: EdgeInsetsDirectional.symmetric(horizontal: padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MmScriptText(widget.message, style: const TextStyle()),
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
      ),
      actionsPadding: EdgeInsetsDirectional.only(
        start: padding,
        end: padding,
        bottom: padding,
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
///
/// The label is an instruction at body weight with the text to type in
/// bold, in its own script's face, so the text stands out without a hint
/// inside the field (a hint would look like a value already typed in).
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

  /// [text] as spans, each run of figures and Latin words in the Latin
  /// face when the UI is in Urdu.
  static List<InlineSpan> _runs(MmSemantics mm, String text) => [
    if (mm.script == MmScript.urdu)
      for (final run in MmScriptText.runsOf(text))
        TextSpan(
          text: run.text,
          style: run.latin ? mm.styleFor(run.text, const TextStyle()) : null,
        )
    else
      TextSpan(text: text),
  ];

  @override
  Widget build(BuildContext context) {
    final mm = context.mm;
    final text = Theme.of(context).textTheme;
    final onSubmitted = this.onSubmitted;
    final at = label.indexOf(expected);
    final labelStyle = DefaultTextStyle.of(context).style
        .merge(text.labelLarge);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The label is the field's accessible name, set on its node below;
        // the visible copy is hidden so it is not read twice.
        ExcludeSemantics(
          child: Padding(
            padding: const EdgeInsetsDirectional.only(bottom: MmSpace.s2),
            child: Text.rich(
              TextSpan(
                children: [
                  ..._runs(mm, label.substring(0, at)),
                  TextSpan(
                    text: expected,
                    style: mm.styleFor(
                      expected,
                      const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  ..._runs(mm, label.substring(at + expected.length)),
                ],
              ),
              // The instruction in the label's size at body weight, so the
              // bold text to type stands out from it.
              style: text.labelLarge!.copyWith(
                fontWeight: text.bodyMedium!.fontWeight,
              ),
              // In Urdu every line keeps the Nastaliq line's height and
              // baseline, whatever face a run is set in.
              strutStyle: mm.script == MmScript.urdu
                  ? StrutStyle.fromTextStyle(labelStyle, forceStrutHeight: true)
                  : null,
            ),
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
            onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
          ),
        ),
      ],
    );
  }
}
