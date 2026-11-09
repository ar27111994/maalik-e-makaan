import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/features/operations/application/places.dart';
import 'package:maalik_e_makaan/src/features/operations/data/place.dart';
import 'package:mm_ui/mm_ui.dart';

/// Where a property and unit were chosen.
typedef PlaceChoice = ({String? propertyId, String? unitId});

/// Choosing where something belongs: a property of the portfolio (or none,
/// when [propertyRequired] is false: the whole portfolio), then one of its
/// units or the whole property.
///
/// A property chosen once and fixed ([propertyFixed], as for a connection
/// or a repair, whose property cannot change) is shown, not offered; its
/// [propertyName] and [unitLabel] name it while the places load, or when
/// it has since been archived.
class PlaceFields extends ConsumerWidget {
  const new({
    required this.portfolioId,
    required this.value,
    required this.onChanged,
    this.propertyRequired = false,
    this.propertyFixed = false,
    this.propertyName,
    this.unitLabel,
    this.propertyError,
    this.propertyHelper,
    super.key,
  });

  final String portfolioId;
  final PlaceChoice value;
  final ValueChanged<PlaceChoice> onChanged;
  final bool propertyRequired;
  final bool propertyFixed;
  final String? propertyName;
  final String? unitLabel;

  /// Why the property is missing, once the form was tried.
  final String? propertyError;
  final String? propertyHelper;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final places = ref.watch(placesProvider(portfolioId)).value?.value;
    final place = places == null ? null : placeOf(places, value.propertyId);
    final propertyId = value.propertyId;
    final unitId = value.unitId;
    // The record's own unit stays a choice even if it is now archived.
    final units = [
      ...?place?.units,
      if (unitId != null &&
          place?.unitLabel(unitId) == null &&
          unitLabel != null)
        UnitPlace(id: unitId, label: unitLabel!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (propertyFixed)
          MmDetailRow(
            label: l10n.propertyLabel,
            value: place?.name ?? propertyName ?? '',
          )
        else
          MmSelectField<String?>(
            label: l10n.propertyLabel,
            required: propertyRequired,
            optional: !propertyRequired,
            helper: propertyHelper,
            errorText: propertyError,
            placeholder: places == null ? l10n.loadingPlaces : null,
            options: [
              if (!propertyRequired)
                MmOption(value: null, label: l10n.wholePortfolioOption),
              for (final place in places ?? const <PropertyPlace>[])
                MmOption(value: place.id, label: place.name),
              // The record's own property, archived since.
              if (propertyId != null &&
                  places != null &&
                  place == null &&
                  propertyName != null)
                MmOption(value: propertyId, label: propertyName!),
            ],
            value: propertyId,
            onChanged: (id) {
              if (id != propertyId) onChanged((propertyId: id, unitId: null));
            },
          ),
        if (propertyId != null) ...[
          const SizedBox(height: MmSpace.s4),
          MmSelectField<String?>(
            label: l10n.unitLabel,
            optional: true,
            options: [
              MmOption(value: null, label: l10n.wholePropertyOption),
              for (final unit in units)
                MmOption(value: unit.id, label: unit.label),
            ],
            value: unitId,
            onChanged: (id) => onChanged((propertyId: propertyId, unitId: id)),
          ),
        ],
      ],
    );
  }
}
