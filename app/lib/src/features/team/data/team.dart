import 'package:flutter/foundation.dart';
import 'package:maalik_e_makaan/src/data/rows.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';

/// A person in a portfolio: their role and the name and e-mail their
/// profile shows teammates.
@immutable
final class TeamMember {
  const new({
    required this.userId,
    required this.role,
    required this.fullName,
    required this.email,
    required this.joinedAt,
  });

  /// Reads a `portfolio_members` row selected with [TeamMember.columns]
  /// and the member's `profiles` row (selected with
  /// [TeamMember.profileColumns]), null when the profile is not visible.
  factory fromRows(Object? member, Object? profile) {
    final row = JsonRow.of(member, 'member');
    final person = profile == null ? null : JsonRow.of(profile, 'profile');
    return TeamMember(
      userId: row.string('user_id'),
      role: MemberRole.parse(row.string('role')),
      fullName: person?.string('full_name') ?? '',
      email: person?.optionalString('email'),
      joinedAt: row.timestamp('created_at'),
    );
  }

  /// Reads the row [toJson] writes (the offline cache).
  factory fromJson(Object? json) {
    final row = JsonRow.of(json, 'member');
    return TeamMember(
      userId: row.string('user_id'),
      role: MemberRole.parse(row.string('role')),
      fullName: row.string('full_name'),
      email: row.optionalString('email'),
      joinedAt: row.timestamp('created_at'),
    );
  }

  /// The membership columns [TeamMember.fromRows] reads.
  static const columns = 'user_id,role,created_at';

  /// The profile columns [TeamMember.fromRows] reads.
  static const profileColumns = 'id,full_name,email';

  final String userId;
  final MemberRole role;

  /// Empty when the member has not given a name.
  final String fullName;

  /// The member's sign-in address, as their profile stores it.
  final String? email;

  /// When they joined the portfolio.
  final DateTime joinedAt;

  Map<String, Object?> toJson() => {
    'user_id': userId,
    'role': role.name,
    'full_name': fullName,
    'email': email,
    'created_at': joinedAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is TeamMember &&
      other.userId == userId &&
      other.role == role &&
      other.fullName == fullName &&
      other.email == email &&
      other.joinedAt == joinedAt;

  @override
  int get hashCode => Object.hash(userId, role, fullName, email, joinedAt);
}

/// An invitation that has been neither accepted nor revoked. It may have
/// expired (see [isExpired]); an owner then revokes it or invites again.
@immutable
final class Invitation {
  const new({
    required this.id,
    required this.email,
    required this.role,
    required this.expiresAt,
    required this.createdAt,
  });

  /// Reads a `portfolio_invitations` row selected with [Invitation.columns].
  factory fromRow(Object? json) {
    final row = JsonRow.of(json, 'invitation');
    return Invitation(
      id: row.string('id'),
      email: row.string('email'),
      role: MemberRole.parse(row.string('role')),
      expiresAt: row.timestamp('expires_at'),
      createdAt: row.timestamp('created_at'),
    );
  }

  /// The columns [Invitation.fromRow] reads (never the verifier's hash,
  /// which clients may not read).
  static const columns = 'id,email,role,expires_at,created_at';

  final String id;

  /// The address it was sent to; only that address can accept it.
  final String email;
  final MemberRole role;
  final DateTime expiresAt;
  final DateTime createdAt;

  /// Whether it can no longer be accepted at [now].
  bool isExpired(DateTime now) => !expiresAt.isAfter(now);

  Map<String, Object?> toRow() => {
    'id': id,
    'email': email,
    'role': role.name,
    'expires_at': expiresAt.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is Invitation &&
      other.id == id &&
      other.email == email &&
      other.role == role &&
      other.expiresAt == expiresAt &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, email, role, expiresAt, createdAt);
}

/// A portfolio's people: its members (owners first) and, for owners, the
/// invitations still waiting for an answer (newest first).
@immutable
final class Team {
  const new({required this.members, required this.invitations});

  /// Reads what [toJson] writes.
  factory fromJson(Object? json) {
    final row = JsonRow.of(json, 'team');
    return Team(
      members: [for (final m in row.list('members')) TeamMember.fromJson(m)],
      invitations: [
        for (final i in row.list('invitations')) Invitation.fromRow(i),
      ],
    );
  }

  final List<TeamMember> members;
  final List<Invitation> invitations;

  /// How many members hold [role].
  int count(MemberRole role) =>
      members.where((member) => member.role == role).length;

  Map<String, Object?> toJson() => {
    'members': [for (final member in members) member.toJson()],
    'invitations': [for (final invitation in invitations) invitation.toRow()],
  };

  @override
  bool operator ==(Object other) =>
      other is Team &&
      listEquals(other.members, members) &&
      listEquals(other.invitations, invitations);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(members), Object.hashAll(invitations));
}

/// [members] owners first, then managers, accountants and viewers; by name
/// (or e-mail when there is none) within a role, then by id.
List<TeamMember> sortMembers(Iterable<TeamMember> members) {
  String key(TeamMember member) =>
      (member.fullName.isEmpty ? member.email ?? '' : member.fullName)
          .toLowerCase();
  return members.toList()..sort((a, b) {
    final byRole = a.role.index.compareTo(b.role.index);
    if (byRole != 0) return byRole;
    final byName = key(a).compareTo(key(b));
    return byName != 0 ? byName : a.userId.compareTo(b.userId);
  });
}

/// What became of the invitation e-mail (`invite-member`'s
/// `email_delivery`).
enum EmailDelivery with DbEnum {
  /// The e-mail was sent.
  sent('sent'),

  /// This server sends no e-mail: share the link yourself.
  notConfigured('not_configured'),

  /// Too many e-mails to this address or from you in the last hour.
  rateLimited('rate_limited'),

  /// Sending failed; the invitation exists and its link works.
  failed('failed'),

  /// A value a newer server sends that this app does not know.
  unknown('unknown');

  new(this.db);

  @override
  final String db;

  /// The delivery called [name]; [unknown] for a value this app does not
  /// know.
  static EmailDelivery parse(String name) {
    for (final value in values) {
      if (value.db == name && value != unknown) return value;
    }
    return unknown;
  }
}

/// A new invitation: who it is for, until when, and the link that accepts
/// it, which the owner can also share themselves (WhatsApp).
@immutable
final class InvitationLink {
  const new({
    required this.invitationId,
    required this.email,
    required this.role,
    required this.expiresAt,
    required this.url,
    required this.delivery,
  });

  /// Reads `invite-member`'s answer.
  factory fromJson(Object? json) {
    final row = JsonRow.of(json, 'invitation');
    final url = Uri.tryParse(row.string('invite_url'));
    if (url == null || !url.isScheme('https') && !url.isScheme('http')) {
      throw FormatException(
        'invite_url is not a link',
        row.string('invite_url'),
      );
    }
    return InvitationLink(
      invitationId: row.string('invitation_id'),
      email: row.string('email'),
      role: MemberRole.parse(row.string('role')),
      expiresAt: row.timestamp('expires_at'),
      url: url,
      delivery: EmailDelivery.parse(row.string('email_delivery')),
    );
  }

  final String invitationId;
  final String email;
  final MemberRole role;
  final DateTime expiresAt;

  /// Opens the invitation in the app; it carries the one-time token.
  final Uri url;
  final EmailDelivery delivery;

  @override
  bool operator ==(Object other) =>
      other is InvitationLink &&
      other.invitationId == invitationId &&
      other.email == email &&
      other.role == role &&
      other.expiresAt == expiresAt &&
      other.url == url &&
      other.delivery == delivery;

  @override
  int get hashCode =>
      Object.hash(invitationId, email, role, expiresAt, url, delivery);
}

/// Why an invitation could not be accepted (`accept_invitation`'s status).
enum InvitationRefusal with DbEnum {
  /// The link is not a real invitation (mistyped or cut short).
  invalid('invalid'),

  /// An owner withdrew it, or its inviter is no longer an owner; or you
  /// accepted it and are no longer a member (removed, or you left since),
  /// so it no longer gives you access.
  revoked('revoked'),

  /// Someone else accepted it already.
  alreadyUsed('already_used'),

  /// Seven days have passed.
  expired('expired'),

  /// The signed-in account has not confirmed its e-mail address.
  emailNotVerified('email_not_verified'),

  /// The signed-in account is not the address it was sent to.
  emailMismatch('email_mismatch'),

  /// A status a newer server sends that this app does not know.
  unknown('unknown');

  new(this.db);

  @override
  final String db;
}

/// The answer to accepting an invitation.
@immutable
sealed class AcceptOutcome {
  const new();

  /// Reads `accept_invitation`'s answer.
  factory fromJson(Object? json) {
    final row = JsonRow.of(json, 'acceptance');
    final status = row.string('status');
    if (status == 'accepted') {
      return InvitationAccepted(
        portfolioId: row.string('portfolio_id'),
        role: MemberRole.parse(row.string('role')),
      );
    }
    for (final refusal in InvitationRefusal.values) {
      if (refusal.db == status && refusal != InvitationRefusal.unknown) {
        return InvitationRefused(refusal);
      }
    }
    return const InvitationRefused(InvitationRefusal.unknown);
  }
}

/// The user is now a member of [portfolioId] (or was already) as [role].
final class InvitationAccepted extends AcceptOutcome {
  const new({required this.portfolioId, required this.role});

  final String portfolioId;
  final MemberRole role;

  @override
  bool operator ==(Object other) =>
      other is InvitationAccepted &&
      other.portfolioId == portfolioId &&
      other.role == role;

  @override
  int get hashCode => Object.hash(portfolioId, role);
}

/// The invitation cannot be accepted, for [reason].
final class InvitationRefused extends AcceptOutcome {
  const new(this.reason);

  final InvitationRefusal reason;

  @override
  bool operator ==(Object other) =>
      other is InvitationRefused && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;
}
