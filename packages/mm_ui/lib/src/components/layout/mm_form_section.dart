import 'package:flutter/material.dart';
import 'package:mm_ui/src/theme/mm_semantics.dart';
import 'package:mm_ui/src/tokens/mm_tokens.g.dart';

/// A titled group of fields in a form ("Tenant details", "Rent"), with an
/// optional line explaining it.
///
/// The title is set in the theme's `titleMedium` style (the design's
/// `titleSmall` role) and is a heading for screen readers, so they can jump
/// between a form's sections; the description is muted ink under it; the
/// fields follow 16 dp apart. Keyboard focus moves through
/// the section's fields before leaving it. Place sections one after the
/// other with 32 dp between them.
///
/// Don't use it for read-only details (use `MmSectionHeader` and
/// `MmDetailRow`) or for a form with a single field.
///
/// ```dart
/// MmFormSection(
///   title: 'Tenant details',
///   description: 'As written on the CNIC.',
///   children: [
///     MmTextField(label: 'Full name', controller: name),
///     MmCnicField(label: 'CNIC', controller: cnic),
///   ],
/// )
/// ```
class MmFormSection extends StatelessWidget {
  /// Creates a section titled [title] around [children].
  const new({
    required this.title,
    required this.children,
    this.description,
    super.key,
  });

  /// The section's heading.
  final String title;

  /// One or two sentences under the heading saying what the section is for
  /// or where to find the answers, or null.
  final String? description;

  /// The section's fields, in order.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final description = this.description;
    return FocusTraversalGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: MmSpace.s4,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: MmSpace.s1,
            children: [
              Semantics(
                container: true,
                header: true,
                child: Text(title, style: text.titleMedium),
              ),
              if (description != null)
                Text(
                  description,
                  style: text.bodyMedium?.copyWith(
                    color: context.mm.colors.inkMuted,
                  ),
                ),
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}
