import 'package:maalik_e_makaan/l10n/generated/app_localizations.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/presentation/portfolio_switcher.dart';
import 'package:maalik_e_makaan/src/features/team/data/team.dart';
import 'package:mm_ui/mm_ui.dart';

/// What [role] may do, in a sentence.
String roleHelp(AppLocalizations l10n, MemberRole role) => switch (role) {
  MemberRole.owner => l10n.roleOwnerHelp,
  MemberRole.manager => l10n.roleManagerHelp,
  MemberRole.accountant => l10n.roleAccountantHelp,
  MemberRole.viewer => l10n.roleViewerHelp,
};

/// The four roles as choices, each with what it may do.
List<MmOption<MemberRole>> roleOptions(AppLocalizations l10n) => [
  for (final role in MemberRole.values)
    MmOption(
      value: role,
      label: roleLabel(l10n, role),
      description: roleHelp(l10n, role),
    ),
];

/// How [member] is named in the team: their name, else their address.
String memberName(AppLocalizations l10n, TeamMember member) {
  if (member.fullName.isNotEmpty) return member.fullName;
  return member.email ?? l10n.memberNoName;
}
