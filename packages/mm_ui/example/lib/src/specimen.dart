import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mm_ui/mm_ui.dart';

import 'package:mm_ui_gallery/src/copy.dart';

/// One component on a gallery page: a heading in the gallery's language,
/// the component's class name for designers and testers, an optional note,
/// and the component in its states.
class Specimen extends StatelessWidget {
  const new({
    required this.title,
    required this.component,
    required this.children,
    this.note,
    super.key,
  });

  /// What the component is, in the gallery's language ("Buttons").
  final String title;

  /// The class or function name ("MmButton").
  final String component;

  /// One sentence on when to use it, or null.
  final String? note;

  /// The component in its states, top to bottom.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = context.mm.colors.inkMuted;
    final code = text.bodySmall!.copyWith(color: muted);
    final note = this.note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text(title, style: text.titleLarge)),
        Text(component, style: context.mm.styleFor(component, code)),
        if (note != null) ...[
          const SizedBox(height: MmSpace.s1),
          Text(note, style: text.bodyMedium?.copyWith(color: muted)),
        ],
        for (final child in children) ...[
          const SizedBox(height: MmSpace.s4),
          child,
        ],
      ],
    );
  }
}

/// A state of a component, named above it ("Disabled", "Busy").
class StateLabel extends StatelessWidget {
  const new({required this.label, required this.child, super.key});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium
        ?.copyWith(color: context.mm.colors.inkMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: style),
        const SizedBox(height: MmSpace.s2),
        child,
      ],
    );
  }
}

/// A row of controls that wraps onto more lines when it runs out of room,
/// leaving room around each for a focus ring drawn outside it.
class SpecimenWrap extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: MmSpace.s3,
    runSpacing: MmSpace.s3,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: children,
  );
}

/// The specimens of a family page, spaced apart.
class SpecimenList extends StatelessWidget {
  const new({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, child) in children.indexed) ...[
        if (index > 0) ...[
          const SizedBox(height: MmSpace.s6),
          const Divider(height: MmSize.hairline, thickness: MmSize.hairline),
          const SizedBox(height: MmSpace.s6),
        ],
        child,
      ],
    ],
  );
}

/// Tells the tester that [action] ran, in a snack bar: buttons in the
/// gallery have nothing real to do.
void showPressed(BuildContext context, String action) => unawaited(
  showMmSnackbar(
    context,
    message: context.tr('“$action” pressed', 'دبایا گیا: $action'),
  ),
);
