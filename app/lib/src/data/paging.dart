import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// How many rows a list reads at a time (docs/architecture/app.md).
const pageSize = 50;

/// Where the next page of a list starts: the `created_at` and `id` of the
/// last row read. Rows are ordered by both, so the page boundary is exact
/// even when rows share a timestamp.
@immutable
final class PageCursor {
  const new({required this.createdAt, required this.id});

  factory fromJson(Object? json) {
    final row = JsonRow.of(json, 'cursor');
    return PageCursor(
      createdAt: row.string('created_at'),
      id: row.string('id'),
    );
  }

  /// The timestamp exactly as PostgREST wrote it, so comparing it loses no
  /// precision.
  final String createdAt;
  final String id;

  Map<String, Object?> toJson() => {'created_at': createdAt, 'id': id};

  @override
  bool operator ==(Object other) =>
      other is PageCursor && other.createdAt == createdAt && other.id == id;

  @override
  int get hashCode => Object.hash(createdAt, id);
}

/// The rows of a list read so far, and where the next page starts (null
/// when there is no more).
@immutable
final class Paged<T> {
  const new(this.items, {this.next});

  /// Reads [json] as written by [toJson].
  factory fromJson(Object? json, T Function(Object? json) item) {
    final row = JsonRow.of(json, 'page');
    final next = row.optionalObject('next');
    return Paged([
      for (final value in row.list('items')) item(value),
    ], next: next == null ? null : PageCursor.fromJson(next));
  }

  /// A page read with a limit of [pageSize]: when it is full there may be
  /// more after its last row, whose cursor [cursorOf] gives.
  factory page(List<T> items, PageCursor Function(T item) cursorOf) =>
      Paged(items, next: items.length < pageSize ? null : cursorOf(items.last));

  final List<T> items;
  final PageCursor? next;

  bool get hasMore => next != null;

  /// These rows followed by [more]'s, with [more]'s cursor.
  Paged<T> followedBy(Paged<T> more) =>
      Paged([...items, ...more.items], next: more.next);

  Map<String, Object?> toJson(Object? Function(T item) item) => {
    'items': [for (final value in items) item(value)],
    'next': next?.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is Paged<T> && listEquals(other.items, items) && other.next == next;

  @override
  int get hashCode => Object.hash(Object.hashAll(items), next);
}

/// Keyset paging over `created_at, id`, oldest first ([after]) or newest
/// first ([before]).
extension KeysetPaging<T> on PostgrestFilterBuilder<T> {
  /// Only the rows after [cursor] (all rows when it is null).
  PostgrestFilterBuilder<T> after(PageCursor? cursor) {
    if (cursor == null) return this;
    // Values are quoted: a timestamp has characters PostgREST's logic
    // syntax would otherwise read (the `+` of the offset, the dots).
    final at = '"${cursor.createdAt}"';
    final id = '"${cursor.id}"';
    return or('created_at.gt.$at,and(created_at.eq.$at,id.gt.$id)');
  }

  /// Only the rows before [cursor], for a list read newest first (all rows
  /// when it is null).
  PostgrestFilterBuilder<T> before(PageCursor? cursor) {
    if (cursor == null) return this;
    final at = '"${cursor.createdAt}"';
    final id = '"${cursor.id}"';
    return or('created_at.lt.$at,and(created_at.eq.$at,id.lt.$id)');
  }
}
