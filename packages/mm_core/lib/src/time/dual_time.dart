import 'package:meta/meta.dart';
import 'package:mm_core/src/time/time_zone.dart';

/// An instant shown to an owner abroad in both times: Pakistan's, where the
/// properties are, and their own ("3:15 pm in Lahore (10:15 am in London)").
///
/// [own] is `null` when the owner's clock reads the same as Pakistan's at
/// that instant (an owner in Pakistan, or in another UTC+05:00 zone), so the
/// time is shown once.
@immutable
final class DualTime {
  const new _(this.pakistan, this.own);

  /// [instant] in Pakistan and in [own]. Throws a [StateError] when [own] is
  /// not known to this build (use `Residence.alertZone`, which always is).
  factory at(DateTime instant, {required TimeZoneId own}) {
    final pakistan = TimeZoneId.pakistan.at(instant);
    final zoned = own.at(instant);
    return DualTime._(pakistan, zoned.offset == pakistan.offset ? null : zoned);
  }

  /// The instant on Pakistan's clocks.
  final ZonedDateTime pakistan;

  /// The instant on the owner's own clocks, or `null` when they read the
  /// same as Pakistan's.
  final ZonedDateTime? own;

  @override
  bool operator ==(Object other) =>
      other is DualTime && other.pakistan == pakistan && other.own == own;

  @override
  int get hashCode => Object.hash(pakistan, own);

  @override
  String toString() => own == null ? '$pakistan' : '$pakistan / $own';
}
