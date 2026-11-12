# mm_core

Pure-Dart domain layer for **Maalik-e-Makaan**. It has no Flutter or I/O dependencies, so every
rule that touches money, dates or identity is exhaustively unit tested (100% line coverage is
enforced in CI).

| Area         | What it provides                                                                                                                                                                                                                                                                                                                |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `money/`     | `Money`: exact rupees/paisa with explicit rounding modes. `MoneyFormat`: Western or lakh/crore grouping, English or Urdu, compact "12.5 lakh". `parseMoneyInput`: accepts `Rs 1,50,000/-`, `1.5 lakh`, `۱۵۰۰۰۰`. Basis-point helpers.                                                                                           |
| `time/`      | `CalendarDate` (date-only, Pakistan Standard Time "today"), `MonthPeriod`, `TaxYear` (Pakistan's 1 July–30 June year), `DateRange`. For a person's own alerts only: `TimeZoneId` (bundled IANA data, 2020–2100; a skipped or repeated local time is the later instant), `ClockTime`, `LocalDateTime`, `QuietHours`, `DualTime`. |
| `residence/` | `CountryCode` (ISO 3166-1 alpha-2), `Residence` (declared, never inferred; `alertZone`), `OwnerAbroad` (a portfolio's answer; NULL is not answered).                                                                                                                                                                            |
| `identity/`  | `Cnic` (masked by default, never infers gender), `PhoneNumber` (E.164 normalisation of every Pakistani format), `Iban` (MOD-97), `EmailAddress`.                                                                                                                                                                                |
| `text/`      | Sanitisers that strip control, bidi-override and invisible characters while preserving Urdu joiners; Urdu/Arabic digit normalisation.                                                                                                                                                                                           |
| `rent/`      | Due dates, proration, increments with Pakistani rounding, anniversaries, late-fee policies.                                                                                                                                                                                                                                     |
| `ledger/`    | Oldest-first payment allocation that mirrors the database's `record_payment`.                                                                                                                                                                                                                                                   |

```bash
dart test                 # unit tests
make test-core            # tests + 100% coverage gate (from the repo root)
```
