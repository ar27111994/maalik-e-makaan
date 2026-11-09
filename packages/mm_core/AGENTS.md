# packages/mm_core/AGENTS.md

Pure-Dart domain library: no Flutter, no I/O. Every rule about money, dates, identity and rent
lives here once and is shared by the app, its tests and the SQL through `contracts/`. The root
[`AGENTS.md`](../../AGENTS.md) rules apply; the module map is in [`README.md`](README.md).

## Where things are

| Path                | What                                                                                     |
| ------------------- | ---------------------------------------------------------------------------------------- |
| `lib/src/money/`    | `Money` (integer paisa, explicit rounding), formatting, input parsing, basis points      |
| `lib/src/time/`     | `CalendarDate`, `MonthPeriod`, `TaxYear` (1 July to 30 June), `DateRange`; Pakistan time |
| `lib/src/identity/` | `Cnic`, `PhoneNumber`, `Iban`, `EmailAddress`                                            |
| `lib/src/text/`     | Sanitiser (the `contracts/clean_text.json` rules) and digit normalisation                |
| `lib/src/rent/`     | Due dates, proration, increments, late-fee policies                                      |
| `lib/src/ledger/`   | Oldest-first payment allocation, mirroring `record_payment`                              |
| `test/contract/`    | The clean-text, identity and rent-maths contract tests against `contracts/*.json`        |

## Rules here

- No dependency on Flutter or any I/O package; only `characters`, `collection` and `meta`.
- 100% line coverage is a gate (`make test-core`).
- A change to a rule that SQL also implements (rent maths, allocation, identity forms, text
  cleaning) changes the SQL in a new migration and the vectors (`make contracts`) in the same
  pull request; see [`docs/agents/workflows.md`](../../docs/agents/workflows.md#change-money-or-rent-maths).
- The Lean, Z3 and Bend tracks in `formal/` model this arithmetic; run `make verify` after
  changing it.

## Commands

```sh
make test-core                               # tests and the 100% coverage gate
cd packages/mm_core && dart test test/money  # one folder
cd packages/mm_core && dart analyze --fatal-infos
make contracts-check                         # vectors still match the generator
```
