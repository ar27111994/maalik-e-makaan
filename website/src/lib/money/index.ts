/**
 * The website's money and rent arithmetic, shared by every calculator. It
 * mirrors packages/mm_core (Dart) and the database's SQL, and all three are
 * tested against contracts/rent_math_vectors.json, so a calculator on this
 * site never disagrees with the app's ledger. Money is integer paisa held in
 * `bigint`: floating point is never used for money.
 */
export {
  planFifoAllocation,
  type AllocationPlan,
  type ChargeAllocation,
  type OpenCharge,
} from "./allocation.ts";
export { basisPointsFromPercent, percentFromBasisPoints } from "./basis-points.ts";
export {
  CalendarDate,
  DateRange,
  MonthPeriod,
  TaxYear,
  daysInMonth,
  isLeapYear,
} from "./calendar.ts";
export { normalizeDigits, toUrduDigits } from "./digits.ts";
export {
  formatMoney,
  groupDigits,
  type CurrencyDisplay,
  type DigitGrouping,
  type MoneyFormatOptions,
  type MoneyLanguage,
  type MoneyNotation,
  type PaisaDisplay,
} from "./format.ts";
export {
  MAX_LATE_FEE,
  lateFeeFor,
  lateFeePolicyFromColumns,
  type LateFeePolicy,
} from "./late-fee.ts";
export { Money, type WholeNumber } from "./money.ts";
export { parseMoneyInput } from "./parse.ts";
export {
  RENT_ROUNDING,
  billablePeriods,
  billedRent,
  billingDueDate,
  dueDate,
  incrementedRent,
  nextAnniversary,
  occupiedDays,
  proratedRent,
  type RentRounding,
} from "./rent-math.ts";
export { divideRounded, type RoundingMode } from "./rounding.ts";
