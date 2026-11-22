/// What a saved entry holds, as its key says (`docs/architecture/app.md`,
/// Reading): the user's own, a portfolio's, or one whose portfolio is not
/// known. The cache tells them apart from the keys alone, without reading a
/// value, so that it can remove what belongs to a portfolio that left the
/// user's list.
library;

import 'package:flutter/foundation.dart' show immutable;

/// What a saved entry's key says it holds.
@immutable
sealed class EntryTag {
  const new();

  /// The tag as it stands in a key: `own`, `p:<portfolio id>` or
  /// `unknown`.
  String get text;

  /// The tag [text] names; [UnknownTag] for anything else, so that an
  /// entry nobody can place counts as of no known portfolio.
  static EntryTag parse(String text) {
    if (text == OwnTag.word) return const OwnTag();
    if (text.startsWith(PortfolioTag.prefix)) {
      final id = text.substring(PortfolioTag.prefix.length);
      if (isPlainId(id)) return PortfolioTag(id);
    }
    return const UnknownTag();
  }

  /// Whether [id] can stand in a key between two dots: not empty, and
  /// without a dot. User and portfolio ids are UUIDs.
  static bool isPlainId(String id) => id.isNotEmpty && !id.contains('.');
}

/// The user's own: the portfolio list, the profile, the residence.
final class OwnTag extends EntryTag {
  const new();

  static const word = 'own';

  @override
  String get text => word;

  @override
  bool operator ==(Object other) => other is OwnTag;

  @override
  int get hashCode => word.hashCode;
}

/// One portfolio's record or list.
final class PortfolioTag extends EntryTag {
  const new(this.portfolioId);

  static const prefix = 'p:';

  final String portfolioId;

  @override
  String get text => '$prefix$portfolioId';

  @override
  bool operator ==(Object other) =>
      other is PortfolioTag && other.portfolioId == portfolioId;

  @override
  int get hashCode => portfolioId.hashCode;
}

/// A value whose portfolio is not known: an empty list, a value with no
/// portfolio of its own, or a key nobody can place.
final class UnknownTag extends EntryTag {
  const new();

  static const word = 'unknown';

  @override
  String get text => word;

  @override
  bool operator ==(Object other) => other is UnknownTag;

  @override
  int get hashCode => word.hashCode;
}

/// How a query's saved entry is tagged. Every query says which kind it is:
/// [OwnScope] for the three queries of the user's own, and a
/// [RecordScope] for everything else.
sealed class CacheScope<T> {
  const new();

  /// The tag of the entry that holds [value].
  EntryTag tagOf(T value);

  /// The tag when it is known before the value is (null: the entry is
  /// found by its query, under whatever tag its value gave it).
  EntryTag? get knownTag;
}

/// The user's own: the portfolio list, the profile and the residence,
/// which hold nothing of any portfolio beyond the list itself. Only the
/// three members below make one, each with its own query.
final class OwnScope<T> extends CacheScope<T> {
  const new _(this.query, [this._portfolios]);

  /// The portfolio list, whose value names the portfolios [portfolios]
  /// gives: the cache does not keep a list that names one the user has
  /// left.
  static OwnScope<T> portfolioList<T>(
    Iterable<String> Function(T value) portfolios,
  ) => OwnScope._('portfolios', portfolios);

  /// The profile.
  static OwnScope<T> profile<T>() => OwnScope<T>._('profile');

  /// The residence.
  static OwnScope<T> residence<T>() => OwnScope<T>._('residence');

  /// The query of the entry: one of the three.
  final String query;

  final Iterable<String> Function(T value)? _portfolios;

  /// The portfolios [value] names: the list's, none for the others.
  Set<String> portfoliosOf(T value) => {...?_portfolios?.call(value)};

  @override
  EntryTag tagOf(T value) => const OwnTag();

  @override
  EntryTag get knownTag => const OwnTag();
}

/// A query of a portfolio's records, or of records whose portfolio is
/// not known: what an `SwrNotifier` declares.
sealed class RecordScope<T> extends CacheScope<T> {
  const new();
}

/// A query in one portfolio, named before the fetch: a list or a summary
/// whose request filters by [portfolioId], so every row of its answer is
/// of it, or the answer is empty.
final class InPortfolio<T> extends RecordScope<T> {
  /// Throws [ArgumentError] when [portfolioId] cannot stand in a key: a
  /// mistake in the app.
  new(this.portfolioId) {
    if (!EntryTag.isPlainId(portfolioId)) {
      throw ArgumentError.value(portfolioId, 'portfolioId', 'not an id');
    }
  }

  final String portfolioId;

  @override
  EntryTag tagOf(T value) => PortfolioTag(portfolioId);

  @override
  EntryTag get knownTag => PortfolioTag(portfolioId);
}

/// A query by a record's or a parent's id, whose portfolio comes with the
/// answer: [portfolioOf] reads it from the value (null when the value
/// names none, as an empty list).
final class FromValue<T> extends RecordScope<T> {
  const new(this.portfolioOf);

  final String? Function(T value) portfolioOf;

  @override
  EntryTag tagOf(T value) {
    final id = portfolioOf(value);
    // An id the server sent that cannot stand in a key places nothing.
    if (id == null || !EntryTag.isPlainId(id)) return const UnknownTag();
    return PortfolioTag(id);
  }

  @override
  EntryTag? get knownTag => null;
}

/// A query whose answer names no portfolio: never kept past the session's
/// first list of portfolios. The safe choice for a new query that has
/// nothing to name.
final class UnknownPortfolio<T> extends RecordScope<T> {
  const new();

  @override
  EntryTag tagOf(T value) => const UnknownTag();

  @override
  EntryTag get knownTag => const UnknownTag();
}

/// The one portfolio all of [ids] name; null when there are none, one is
/// null, or two differ.
String? samePortfolio(Iterable<String?> ids) {
  String? one;
  for (final id in ids) {
    if (id == null) return null;
    if (one != null && one != id) return null;
    one = id;
  }
  return one;
}
