import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/features/tenants/data/tenant.dart';

/// The words for the tenant values the database names.
extension TenantWords on AppLocalizations {
  String tenantKind(TenantKind kind) => switch (kind) {
    TenantKind.individual => tenantKindIndividual,
    TenantKind.company => tenantKindCompany,
    TenantKind.government => tenantKindGovernment,
    TenantKind.other => propertyTypeOther,
  };

  String guardianRelation(GuardianRelation relation) => switch (relation) {
    GuardianRelation.sonOf => guardianSonOf,
    GuardianRelation.daughterOf => guardianDaughterOf,
    GuardianRelation.wifeOf => guardianWifeOf,
    GuardianRelation.other => propertyTypeOther,
  };
}

/// "Son of Ahmed Khan", or null without a guardian's name.
String? guardianText(AppLocalizations l10n, Tenant tenant) {
  final name = tenant.guardianName;
  if (name == null || name.isEmpty) return null;
  final relation = tenant.guardianRelation;
  return relation == null || relation == GuardianRelation.other
      ? name
      : l10n.guardianLine(l10n.guardianRelation(relation), name);
}
