/// A portfolio's answer to "Does the owner of these properties live
/// abroad?" (`portfolios.owner_abroad`).
///
/// It is asked when a portfolio is created, with no answer chosen, and for
/// a portfolio that has no answer yet (every portfolio made before the
/// question existed), on the next open by an owner or manager. It is never
/// filled in from anyone's `Residence`. The overseas-owner rules run only
/// for [abroad].
enum OwnerAbroad {
  /// Not yet answered (stored as NULL).
  notAnswered,

  /// The owner lives abroad (true).
  abroad,

  /// The owner lives in Pakistan (false).
  inPakistan;

  /// Decodes the stored value: `null`, `true` or `false`. Throws a
  /// [FormatException] for anything else.
  static OwnerAbroad fromJson(Object? json) => switch (json) {
    null => notAnswered,
    true => abroad,
    false => inPakistan,
    _ => throw FormatException('Expected true, false or null', '$json'),
  };

  /// The stored value: `null`, `true` or `false`.
  bool? toJson() => switch (this) {
    notAnswered => null,
    abroad => true,
    inPakistan => false,
  };

  /// Whether the question still needs an answer.
  bool get needsAnswer => this == notAnswered;

  /// Whether the overseas-owner rules apply: only when answered "abroad".
  bool get overseasRulesApply => this == abroad;
}
