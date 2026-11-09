-- Reporting RPCs against a small, fully known portfolio.
--
-- Today = 2026-11-03. Unit A let at 45,000 from 2026-09-01 (deposit 90,000).
-- Unit B vacant (asking 50,000). Payments: 90,000 deposit + 45,000 Sep rent
-- on 2026-09-03 (cash), Oct rent paid 2026-10-20 by bank with 1,500 tax
-- withheld (43,500 cash). November (due 11-05) is unpaid. Expenses: 4,000
-- repairs in October.
begin;
\ir _helpers.psql
select plan(26);

set local app.today_override = '2026-11-03';

select tests.create_user('owner@example.com') as owner \gset
select tests.create_user('outsider@example.com') as outsider \gset
select tests.create_portfolio(:'owner') as pid \gset
select tests.create_rental(:'pid') as r \gset
select (:'r')::jsonb ->> 'property_id' as prop \gset
insert into public.units (portfolio_id, property_id, label, asking_rent)
values (:'pid', :'prop', 'Unit B', 50000);
update public.properties set estimated_value = 30000000 where id = :'prop';
select tests.create_lease(:'pid', :'r', '2026-09-01', 45000,
  '{"security_deposit": 90000, "police_status": "registered"}') as lease \gset

select tests.authenticate_as(:'owner');
select public.record_payment(:'lease', 135000, '2026-09-03', 'cash', gen_random_uuid()) is not null as p1 \gset
select public.record_payment(:'lease', 43500, '2026-10-20', 'bank_transfer', gen_random_uuid(), 'IBFT', null, 1500)
  is not null as p2 \gset
insert into public.expenses (portfolio_id, property_id, category, amount, spent_on, method)
values (:'pid', :'prop', 'repairs_maintenance', 4000, '2026-10-15', 'cash');

-- Dashboard ------------------------------------------------------------------------
select public.get_dashboard(:'pid') as d \gset
select is((:'d')::jsonb -> 'month' ->> 'expected', '45000.00', 'expected this month = November rent');
select is((:'d')::jsonb -> 'month' ->> 'paid', '0.00', 'nothing paid against November yet');
select is((:'d')::jsonb -> 'month' ->> 'collection_rate', '0.0000', 'collection rate 0%');
select is((:'d')::jsonb -> 'outstanding' ->> 'total', '45000.00', 'outstanding = November');
select is((:'d')::jsonb -> 'outstanding' ->> 'overdue', '0', 'nothing overdue before the 5th');
select is((:'d')::jsonb -> 'outstanding' -> 'aging' ->> 'not_due', '45000.00', 'aging: not yet due');
select is((:'d')::jsonb -> 'occupancy' ->> 'rate', '0.5000', 'one of two units occupied');
select is((:'d')::jsonb -> 'occupancy' ->> 'vacant_asking_rent', '50000.00', 'vacancy loss per month');
select is((:'d')::jsonb -> 'deposits' ->> 'held', '90000.00', 'deposit held');
select is(jsonb_array_length((:'d')::jsonb -> 'police_pending'), 0, 'registered tenancies are not pending');

-- After the due date passes, November is overdue.
set local app.today_override = '2026-11-20';
select public.get_dashboard(:'pid') as d2 \gset
select is((:'d2')::jsonb -> 'outstanding' -> 'aging' ->> 'd1_30', '45000.00', 'aging: 1-30 days');
select is((:'d2')::jsonb -> 'top_arrears' -> 0 ->> 'days_overdue', '15', 'days overdue since the oldest unpaid due');
set local app.today_override = '2026-11-03';

-- Receivables -----------------------------------------------------------------------
select results_eq(
  $$select outstanding, overdue, credit, last_paid_on from public.get_receivables(
      (select id from public.portfolios limit 1))$$,
  $$values (45000.00::numeric, 0::numeric, 0.00::numeric, '2026-10-20'::date)$$,
  'receivables list balance, overdue, credit and last payment'
);

-- Payment facts ----------------------------------------------------------------------
select results_eq(
  $$select due_date, settled_on from public.get_payment_facts((select id from public.portfolios limit 1), '2026-01-01')
    order by due_date$$,
  $$values ('2026-09-05'::date, '2026-09-03'::date), ('2026-10-05', '2026-10-20')$$,
  'settlement dates per rent due feed the payment score (November is not yet due)'
);

-- Cash flow ----------------------------------------------------------------------------
select results_eq(
  $$select month, cash_received, rent_collected, deposits_collected, tax_withheld, expenses
    from public.get_cashflow((select id from public.portfolios limit 1), '2026-09-01', '2026-10-31')$$,
  $$values ('2026-09-01'::date, 135000.00::numeric, 45000.00::numeric, 90000.00::numeric, 0.00::numeric, 0::numeric),
           ('2026-10-01', 43500.00, 45000.00, 0, 1500.00, 4000.00)$$,
  'monthly cash flow splits rent, deposits, withholding and expenses'
);
select throws_ok(
  $$select * from public.get_cashflow((select id from public.portfolios limit 1), '2026-10-01', '2026-01-01')$$,
  '22023', 'invalid_date', 'reversed ranges are rejected'
);

-- Property performance ---------------------------------------------------------------
select results_eq(
  $$select units, occupied_units, rent_income, expenses, net_operating_income
    from public.get_property_performance((select id from public.portfolios limit 1), '2026-09-01', '2026-10-31')$$,
  $$values (2, 1, 90000.00::numeric, 4000.00::numeric, 86000.00::numeric)$$,
  'per-property income, expenses and NOI'
);

-- Tax year -------------------------------------------------------------------------------
select results_eq(
  $$select gross_rent, tax_withheld, repairs_allowance, net_after_repairs_allowance
    from public.get_tax_year_statement((select id from public.portfolios limit 1), 2027)$$,
  $$values (90000.00::numeric, 1500.00::numeric, 18000.00::numeric, 72000.00::numeric)$$,
  'TY2027 (Jul 2026-Jun 2027): gross rent, tax withheld, 1/5 repairs allowance'
);
select is(
  (select expenses_by_category ->> 'repairs_maintenance'
   from public.get_tax_year_statement((select id from public.portfolios limit 1), 2027)),
  '4000.00', 'expenses are itemised by category'
);
select throws_ok(
  $$select * from public.get_tax_year_statement((select id from public.portfolios limit 1), 1999)$$,
  '22023', 'invalid_tax_year', 'implausible tax years are rejected'
);

-- Cash positions -----------------------------------------------------------------------
select results_eq(
  $$select cash_collected, cash_expenses, cash_in_hand
    from public.get_cash_positions((select id from public.portfolios limit 1))$$,
  $$values (135000.00::numeric, 4000.00::numeric, 131000.00::numeric)$$,
  'cash in hand = cash received - handed over - cash expenses'
);

-- Search ---------------------------------------------------------------------------------
select is(
  (select entity_type from public.search_portfolio((select id from public.portfolios limit 1), 'unit b') limit 1),
  'unit', 'search finds units by label'
);
select is(
  (select count(*)::integer from public.search_portfolio((select id from public.portfolios limit 1), '%%%')),
  0, 'LIKE wildcards in the query are escaped'
);
select is(
  (select count(*)::integer from public.search_portfolio((select id from public.portfolios limit 1), 'a')),
  0, 'queries shorter than two characters return nothing'
);

-- Authorisation -------------------------------------------------------------------------
select tests.authenticate_as(:'outsider');
select throws_ok(
  format('select public.get_receivables(%L)', :'pid'), '42501', 'forbidden',
  'reports are forbidden to non-members'
);
select throws_ok(
  format('select * from public.search_portfolio(%L, %L)', :'pid', 'unit'), '42501', 'forbidden',
  'search is forbidden to non-members'
);

select * from finish();
rollback;
