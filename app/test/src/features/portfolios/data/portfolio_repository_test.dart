import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_repository.dart';
import 'package:mm_core/mm_core.dart';

import '../../../../support/fakes.dart';
import '../../../../support/supabase.dart';

Map<String, Object?> _row(
  String role,
  String id,
  String name, [
  bool? ownerAbroad,
]) => {
  'role': role,
  'portfolio': {'id': id, 'name': name, 'owner_abroad': ownerAbroad},
};

void main() {
  late MockSupabase supabase;
  late SupabasePortfolioRepository repository;

  setUp(() {
    supabase = MockSupabase(
      (_) async => jsonResponse([
        _row('manager', plaza.id, 'Saddar Plaza'),
        _row('owner', gulberg.id, 'Gulberg Houses'),
      ]),
    );
    repository = SupabasePortfolioRepository(supabase.client);
  });

  group('PortfolioMembership.fromRow', () {
    test('reads a membership with its embedded portfolio', () {
      final membership = PortfolioMembership.fromRow(
        _row('owner', gulberg.id, 'Gulberg Houses'),
      );
      expect(membership, gulberg);
      expect(PortfolioMembership.fromRow(membership.toRow()), membership);
      expect(membership.hashCode, gulberg.hashCode);
      expect(membership, isNot(plaza));
    });

    test("reads the portfolio's owner-abroad answer", () {
      for (final (stored, answer) in [
        (null, OwnerAbroad.notAnswered),
        (true, OwnerAbroad.abroad),
        (false, OwnerAbroad.inPakistan),
      ]) {
        final membership = PortfolioMembership.fromRow(
          _row('manager', plaza.id, 'Saddar Plaza', stored),
        );
        expect(membership.ownerAbroad, answer);
        expect(PortfolioMembership.fromRow(membership.toRow()), membership);
      }
      expect(gulberg.withOwnerAbroad(OwnerAbroad.abroad), isNot(gulberg));
      expect(
        gulberg.withOwnerAbroad(OwnerAbroad.abroad).hashCode,
        isNot(gulberg.hashCode),
      );
    });

    test('refuses malformed rows and unknown roles', () {
      for (final row in <Object?>[
        'owner',
        {'role': 'owner'},
        {'role': 'owner', 'portfolio': null},
        {
          'role': 'owner',
          'portfolio': {'id': 1, 'name': 'x', 'owner_abroad': null},
        },
        // Saved by an app version before the question: read again.
        {
          'role': 'owner',
          'portfolio': {'id': 'p', 'name': 'x'},
        },
        {
          'role': 'owner',
          'portfolio': {'id': 'p', 'name': 'x', 'owner_abroad': 'yes'},
        },
        _row('landlord', 'p', 'x'),
      ]) {
        expect(
          () => PortfolioMembership.fromRow(row),
          throwsFormatException,
          reason: '$row',
        );
      }
    });

    test('every database role has a value', () {
      for (final role in ['owner', 'manager', 'accountant', 'viewer']) {
        expect(MemberRole.parse(role).name, role);
      }
    });

    test('who answers the question and who is the caretaker', () {
      final answers = {
        for (final role in MemberRole.values) role: role.answersOwnerAbroad,
      };
      expect(answers, {
        MemberRole.owner: true,
        MemberRole.manager: true,
        MemberRole.accountant: false,
        MemberRole.viewer: false,
      });
      expect(
        [
          for (final role in MemberRole.values)
            if (role.changesOwnerAbroad) role,
        ],
        [MemberRole.owner],
      );
      expect(
        [
          for (final role in MemberRole.values)
            if (role.namesCaretaker) role,
        ],
        [MemberRole.owner],
      );
      expect(
        [
          for (final role in MemberRole.values)
            if (role.canBeCaretaker) role,
        ],
        [MemberRole.manager],
      );
    });

    test('the question is asked of owners and managers until answered', () {
      expect(gulberg.asksOwnerAbroad, isTrue);
      expect(plaza.asksOwnerAbroad, isTrue);
      expect(gulbergAsViewer.asksOwnerAbroad, isFalse);
      expect(
        gulberg.withOwnerAbroad(OwnerAbroad.inPakistan).asksOwnerAbroad,
        isFalse,
      );
      expect(
        gulberg.withOwnerAbroad(OwnerAbroad.abroad).asksOwnerAbroad,
        isFalse,
      );
    });
  });

  group('listMine', () {
    test('reads the memberships of the user, active portfolios only', () async {
      final list = await repository.listMine(testUserId);
      expect(list, [gulberg, plaza]);
      final request = supabase.request;
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/portfolio_members');
      expect(request.url.queryParameters, {
        // No hint: one relationship links the tables (01_schema_security).
        'select': 'role,portfolio:portfolios!inner(id,name,owner_abroad)',
        'user_id': 'eq.$testUserId',
        'portfolio.archived_at': 'is.null',
      });
    });

    test('sorts by name ignoring case, then by id', () {
      const a = PortfolioMembership(
        id: 'b',
        name: 'alpha',
        role: MemberRole.viewer,
      );
      const b = PortfolioMembership(
        id: 'a',
        name: 'Alpha',
        role: MemberRole.owner,
      );
      const c = PortfolioMembership(
        id: 'c',
        name: 'Beta',
        role: MemberRole.owner,
      );
      expect(sortByName([c, a, b]), [b, a, c]);
    });

    test('maps failures', () async {
      supabase.respond = (_) async => postgrestError('PGRST301', status: 401);
      await expectLater(
        repository.listMine(testUserId),
        throwsA(isA<SessionExpired>()),
      );
      supabase.respond = (_) async => jsonResponse({'not': 'a list'});
      await expectLater(
        repository.listMine(testUserId),
        throwsA(isA<UnexpectedFailure>()),
      );
    });
  });

  group('delete', () {
    test('calls delete_portfolio with the id and the typed name', () async {
      supabase.respond = (_) async => jsonResponse(null);
      await repository.delete(gulberg.id, confirmation: 'gulberg houses ');
      final request = supabase.request;
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/rpc/delete_portfolio');
      expect(bodyOf(request), {
        'p_portfolio_id': gulberg.id,
        'p_confirmation': 'gulberg houses ',
      });
    });

    test('maps the refusals', () async {
      final cases = {
        postgrestError('42501', status: 403): isA<Forbidden>(),
        postgrestError(
          '22023',
          message: 'confirmation_mismatch',
        ): isA<RejectedFailure>().having(
          (f) => f.reason,
          'reason',
          'confirmation_mismatch',
        ),
        // A deadlock the server's three tries did not get past.
        postgrestError('40P01'): isA<TemporarilyUnavailable>(),
      };
      for (final MapEntry(key: response, value: matcher) in cases.entries) {
        supabase.respond = (_) async => response;
        await expectLater(
          repository.delete(gulberg.id, confirmation: 'Gulberg Houses'),
          throwsA(matcher),
        );
      }
    });
  });

  group('create', () {
    Map<String, Object?> created({bool? ownerAbroad}) => {
      'id': gulberg.id,
      'name': 'Gulberg Houses',
      'default_due_day': 5,
      'receipt_prefix': 'MM',
      'owner_abroad': ownerAbroad,
    };

    test('calls create_portfolio with the name and the attempt id', () async {
      supabase.respond = (_) async => jsonResponse(created());
      final portfolio = await repository.create(
        name: '  Gulberg   Houses ',
        id: gulberg.id,
      );
      expect(portfolio, gulberg);
      expect(portfolio.ownerAbroad, OwnerAbroad.notAnswered);
      final request = supabase.request;
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/rpc/create_portfolio');
      // No answer, no parameter: the call older databases know.
      expect(bodyOf(request), {'p_name': 'Gulberg Houses', 'p_id': gulberg.id});
    });

    test('sends the answer to the owner-abroad question when given', () async {
      for (final (answer, stored) in [
        (OwnerAbroad.abroad, true),
        (OwnerAbroad.inPakistan, false),
      ]) {
        supabase.respond = (_) async =>
            jsonResponse(created(ownerAbroad: stored));
        final portfolio = await repository.create(
          name: 'Gulberg Houses',
          id: gulberg.id,
          ownerAbroad: answer,
        );
        expect(portfolio.ownerAbroad, answer);
        expect(bodyOf(supabase.requests.last), {
          'p_name': 'Gulberg Houses',
          'p_id': gulberg.id,
          'p_owner_abroad': stored,
        });
      }
    });

    test('maps the refusals', () async {
      final cases = {
        postgrestError(
          '22023',
          message: 'portfolio_limit_reached',
        ): isA<RejectedFailure>().having(
          (f) => f.reason,
          'reason',
          'portfolio_limit_reached',
        ),
        postgrestError(
          '22023',
          message: 'account_deleted',
        ): isA<RejectedFailure>().having(
          (f) => f.reason,
          'reason',
          'account_deleted',
        ),
        postgrestError('23514'): isA<RejectedFailure>().having(
          (f) => f.reason,
          'reason',
          'constraint_violation',
        ),
        postgrestError('42501', status: 403): isA<Forbidden>(),
        postgrestError('rate_limited', status: 429, hint: '3600'):
            isA<RateLimited>(),
      };
      for (final MapEntry(key: response, value: matcher) in cases.entries) {
        supabase.respond = (_) async => response;
        await expectLater(
          repository.create(name: 'x', id: gulberg.id),
          throwsA(matcher),
        );
      }
    });

    test('an answer without a portfolio is a ServerFailure', () async {
      supabase.respond = (_) async => jsonResponse({'id': gulberg.id});
      await expectLater(
        repository.create(name: 'x', id: gulberg.id),
        throwsA(isA<ServerFailure>()),
      );
    });
  });

  group('the owner-abroad question', () {
    test(
      'answering asks set_owner_abroad not to overwrite an answer',
      () async {
        supabase.respond = (_) async => jsonResponse(true);
        expect(
          await repository.answerOwnerAbroad(gulberg.id, abroad: true),
          OwnerAbroad.abroad,
        );
        final request = supabase.request;
        expect(request.method, 'POST');
        expect(request.url.path, '/rest/v1/rpc/set_owner_abroad');
        expect(bodyOf(request), {
          'p_portfolio_id': gulberg.id,
          'p_owner_abroad': true,
          'p_if_unanswered': true,
        });
        // Someone answered first: their answer comes back.
        supabase.respond = (_) async => jsonResponse(false);
        expect(
          await repository.answerOwnerAbroad(gulberg.id, abroad: true),
          OwnerAbroad.inPakistan,
        );
      },
    );

    test('changing it overwrites', () async {
      supabase.respond = (_) async => jsonResponse(false);
      expect(
        await repository.changeOwnerAbroad(gulberg.id, abroad: false),
        OwnerAbroad.inPakistan,
      );
      expect(bodyOf(supabase.request), {
        'p_portfolio_id': gulberg.id,
        'p_owner_abroad': false,
        'p_if_unanswered': false,
      });
    });

    test('maps the refusals', () async {
      Matcher rejected(String reason) =>
          isA<RejectedFailure>().having((f) => f.reason, 'reason', reason);
      final cases = {
        postgrestError('22023', message: 'owner_abroad_answered'): rejected(
          'owner_abroad_answered',
        ),
        postgrestError('22023', message: 'invalid_owner_abroad'): rejected(
          'invalid_owner_abroad',
        ),
        postgrestError('42501', status: 403): isA<Forbidden>(),
      };
      for (final MapEntry(key: response, value: matcher) in cases.entries) {
        supabase.respond = (_) async => response;
        await expectLater(
          repository.changeOwnerAbroad(gulberg.id, abroad: true),
          throwsA(matcher),
        );
      }
      // Anything but an answer is a disagreement with the server.
      supabase.respond = (_) async => jsonResponse(null);
      await expectLater(
        repository.answerOwnerAbroad(gulberg.id, abroad: true),
        throwsA(isA<ServerFailure>()),
      );
    });
  });
}
