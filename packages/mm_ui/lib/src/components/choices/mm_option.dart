import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// One option of an `MmSelectField` or an `MmRadioGroup`: the [value] the
/// app works with and the words the landlord sees.
///
/// Use it for choices the app knows by value (a property, a payment
/// method, a rent day). The label and description come from the app's
/// localisations or the landlord's own data (a property's name).
///
/// ```dart
/// MmOption(
///   value: PaymentMethod.bank,
///   label: l10n.bankTransfer,
///   description: l10n.bankTransferHint,
///   icon: MmIcons.bank,
/// )
/// ```
@immutable
class MmOption<T> {
  /// Creates the option for [value], shown as [label].
  const new({
    required this.value,
    required this.label,
    this.description,
    this.icon,
    this.searchTerms = const [],
  });

  /// The value reported when this option is chosen.
  final T value;

  /// The option's name ("Bank transfer", "Gulberg Heights").
  final String label;

  /// A line below the label that explains the option.
  final String? description;

  /// An icon shown with the option.
  final IconData? icon;

  /// Other words the search of an `MmSelectField` finds this option by (its
  /// name in the other language, a short form such as "UK"); never shown
  /// or read out.
  final List<String> searchTerms;

  @override
  bool operator ==(Object other) =>
      other is MmOption<T> &&
      other.value == value &&
      other.label == label &&
      other.description == description &&
      other.icon == icon &&
      listEquals(other.searchTerms, searchTerms);

  @override
  int get hashCode =>
      Object.hash(value, label, description, icon, Object.hashAll(searchTerms));
}
