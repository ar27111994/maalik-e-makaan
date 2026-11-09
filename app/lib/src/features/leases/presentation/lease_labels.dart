import 'package:flutter/widgets.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/core/dates.dart';
import 'package:maalik_e_makaan/src/core/dates.dart' as dates;
import 'package:maalik_e_makaan/src/core/display_text.dart';
import 'package:maalik_e_makaan/src/features/leases/data/lease.dart';
import 'package:maalik_e_makaan/src/features/properties/data/property.dart';
import 'package:mm_core/mm_core.dart';
import 'package:mm_ui/mm_ui.dart';

/// The words for the tenancy values the database names.
extension LeaseWords on AppLocalizations {
  String policeStatus(PoliceStatus status) => switch (status) {
    PoliceStatus.notRequired => policeNotRequired,
    PoliceStatus.pending => policePending,
    PoliceStatus.submitted => policeSubmitted,
    PoliceStatus.registered => registrarRegistered,
  };

  String policeChannel(PoliceChannel channel) => switch (channel) {
    PoliceChannel.onlinePortal => channelOnlinePortal,
    PoliceChannel.khidmatMarkaz => channelKhidmatMarkaz,
    PoliceChannel.policeStation => channelPoliceStation,
    PoliceChannel.other => propertyTypeOther,
  };

  String registrarStatus(RegistrarStatus status) => switch (status) {
    RegistrarStatus.notApplicable => registrarNotApplicable,
    RegistrarStatus.notPresented => registrarNotPresented,
    RegistrarStatus.presented => registrarPresented,
    RegistrarStatus.registered => registrarRegistered,
  };

  String endReason(EndReason reason) => switch (reason) {
    EndReason.termCompleted => endTermCompleted,
    EndReason.tenantMovedOut => endTenantMovedOut,
    EndReason.eviction => endEviction,
    EndReason.mutualAgreement => endMutualAgreement,
    EndReason.other => propertyTypeOther,
  };

  String rentReason(RentChangeReason reason) => switch (reason) {
    RentChangeReason.initial => rentReasonInitial,
    RentChangeReason.annualIncrement => rentReasonAnnualIncrement,
    RentChangeReason.renegotiation => rentReasonRenegotiation,
    RentChangeReason.correction => rentReasonCorrection,
  };

  /// The late-fee policy in words, with its amounts formatted by [money].
  String lateFee(LateFeePolicy policy, MoneyFormat money) => switch (policy) {
    NoLateFee() => lateFeeNone,
    FlatLateFee(:final amount) => listDetail(lateFeeFlat, money.format(amount)),
    PercentLateFee(:final basisPoints) => listDetail(
      lateFeePercent,
      percentValue(percentFromBasisPoints(basisPoints)),
    ),
    DailyLateFee(:final perDay, :final cap) => listDetail(
      lateFeeDaily,
      cap == null
          ? money.format(perDay)
          : detailLine([
              money.format(perDay),
              '$lateFeeCapLabel ${money.format(cap)}',
            ]),
    ),
  };
}

/// A badge saying whether [lease] runs, has ended or starts later.
MmStatusBadge leaseBadge(BuildContext context, Lease lease) {
  final l10n = AppLocalizations.of(context);
  if (!lease.active) {
    return MmStatusBadge(status: MmStatus.neutral, label: l10n.leaseEnded);
  }
  final start = lease.terms.startDate;
  if (start.isAfter(dates.today(context))) {
    return MmStatusBadge(
      status: MmStatus.credit,
      icon: MmIcons.calendar,
      label: l10n.leaseUpcoming(dateLabel(context, start)),
    );
  }
  return MmStatusBadge(status: MmStatus.paid, label: l10n.leaseActive);
}

/// The police registration website of [province], where one exists
/// (`.planning/research/website-facts.md` §1).
Uri? policePortal(Province province) => switch (province) {
  Province.punjab => Uri.parse('https://punjabpolice.gov.pk/trs'),
  Province.sindh => Uri.parse('https://tenantregister.sindhpolice.gov.pk/'),
  Province.islamabad => Uri.parse('https://islamabadpolice.gov.pk/srv-tr.php'),
  _ => null,
};
