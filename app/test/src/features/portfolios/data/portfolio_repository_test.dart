import 'package:flutter_test/flutter_test.dart';
import 'package:maalik_e_makaan/src/core/failure.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio.dart';
import 'package:maalik_e_makaan/src/features/portfolios/data/portfolio_repository.dart';

import '../../../../support/fakes.dart';
import '../../../../support/supabase.dart';

Map<String, Object?> _row(String role, String id, String name) => {
  'role': role,
  'portfolio': {'id': id, 'name': name},
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

    test('refuses malformed rows and unknown roles', () {
      for (final row in <Object?>[
        'owner',
        {'role': 'owner'},
        {'role': 'owner', 'portfolio': null},
        {
          'role': 'owner',
          'portfolio': {'id': 1, 'name': 'x'},
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
  });

  group('listMine', () {
    test('reads the memberships of the user, active portfolios only', () async {
      final list = await repository.listMine(testUserId);
      expect(list, [gulberg, plaza]);
      final request = supabase.request;
      expect(request.method, 'GET');
      expect(request.url.path, '/rest/v1/portfolio_members');
      expect(request.url.queryParameters, {
        'select': 'role,portfolio:portfolios!inner(id,name)',
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
    test('calls create_portfolio with the name and the attempt id', () async {
      supabase.respond = (_) async => jsonResponse({
        'id': gulberg.id,
        'name': 'Gulberg Houses',
        'default_due_day': 5,
        'receipt_prefix': 'MM',
      });
      final created = await repository.create(
        name: '  Gulberg   Houses ',
        id: gulberg.id,
      );
      expect(created, gulberg);
      final request = supabase.request;
      expect(request.method, 'POST');
      expect(request.url.path, '/rest/v1/rpc/create_portfolio');
      expect(bodyOf(request), {'p_name': 'Gulberg Houses', 'p_id': gulberg.id});
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
}
