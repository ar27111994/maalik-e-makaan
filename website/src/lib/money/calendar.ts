/**
 * Calendar dates without a time of day or time zone, months and date ranges.
 * Mirrors calendar_date.dart, month_period.dart, date_range.dart and
 * tax_year.dart in packages/mm_core/lib/src/time/. Arithmetic uses integer
 * day numbers (no `Date` objects), so it is exact for years 1–9999.
 */

const ISO_DATE = /^(\d{4})-(\d{2})-(\d{2})$/;
const ISO_MONTH = /^(\d{4})-(\d{2})(?:-\d{2})?$/;
const MONTH_LENGTHS = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31] as const;

export function isLeapYear(year: number): boolean {
  return (year % 4 === 0 && year % 100 !== 0) || year % 400 === 0;
}

export function daysInMonth(year: number, month: number): number {
  if (month === 2 && isLeapYear(year)) return 29;
  const length = MONTH_LENGTHS[month - 1];
  if (length === undefined) throw new RangeError(`month must be within 1..12, got ${month}`);
  return length;
}

function checkInteger(value: number, name: string, min: number, max: number): void {
  if (!Number.isInteger(value) || value < min || value > max) {
    throw new RangeError(`${name} must be an integer within ${min}..${max}, got ${value}`);
  }
}

/** Days since 1970-01-01 in the proleptic Gregorian calendar (H. Hinnant's days_from_civil). */
function dayNumber(year: number, month: number, day: number): number {
  const y = month <= 2 ? year - 1 : year;
  const era = Math.floor(y / 400);
  const yearOfEra = y - era * 400;
  const dayOfYear = Math.floor((153 * (month + (month > 2 ? -3 : 9)) + 2) / 5) + day - 1;
  const dayOfEra =
    yearOfEra * 365 + Math.floor(yearOfEra / 4) - Math.floor(yearOfEra / 100) + dayOfYear;
  return era * 146_097 + dayOfEra - 719_468;
}

/** The inverse of {@link dayNumber} (civil_from_days). */
function fromDayNumber(days: number): CalendarDate {
  const z = days + 719_468;
  const era = Math.floor(z / 146_097);
  const dayOfEra = z - era * 146_097;
  const yearOfEra = Math.floor(
    (dayOfEra -
      Math.floor(dayOfEra / 1460) +
      Math.floor(dayOfEra / 36_524) -
      Math.floor(dayOfEra / 146_096)) /
      365,
  );
  const dayOfYear =
    dayOfEra - (365 * yearOfEra + Math.floor(yearOfEra / 4) - Math.floor(yearOfEra / 100));
  const mp = Math.floor((5 * dayOfYear + 2) / 153);
  const day = dayOfYear - Math.floor((153 * mp + 2) / 5) + 1;
  const month = mp < 10 ? mp + 3 : mp - 9;
  const year = yearOfEra + era * 400 + (month <= 2 ? 1 : 0);
  return new CalendarDate(year, month, day);
}

/** A validated calendar date, e.g. a rent due date. */
export class CalendarDate {
  readonly year: number;
  readonly month: number;
  readonly day: number;

  constructor(year: number, month: number, day: number) {
    checkInteger(year, "year", 1, 9999);
    checkInteger(month, "month", 1, 12);
    checkInteger(day, "day", 1, daysInMonth(year, month));
    this.year = year;
    this.month = month;
    this.day = day;
  }

  /** Parses a strict ISO-8601 date (`YYYY-MM-DD`); throws a `SyntaxError` otherwise. */
  static parse(iso: string): CalendarDate {
    const parsed = CalendarDate.tryParse(iso);
    if (parsed === null)
      throw new SyntaxError(`Expected a YYYY-MM-DD date, got ${JSON.stringify(iso)}`);
    return parsed;
  }

  /** Parses `YYYY-MM-DD`, returning `null` for malformed or impossible dates. */
  static tryParse(iso: string): CalendarDate | null {
    const match = ISO_DATE.exec(iso.trim());
    if (match === null) return null;
    const [year, month, day] = [Number(match[1]), Number(match[2]), Number(match[3])];
    if (year < 1 || month < 1 || month > 12 || day < 1 || day > daysInMonth(year, month))
      return null;
    return new CalendarDate(year, month, day);
  }

  static min(a: CalendarDate, b: CalendarDate): CalendarDate {
    return a.isAfter(b) ? b : a;
  }

  static max(a: CalendarDate, b: CalendarDate): CalendarDate {
    return a.isBefore(b) ? b : a;
  }

  private get dayNumber(): number {
    return dayNumber(this.year, this.month, this.day);
  }

  /** ISO weekday: Monday = 1 … Sunday = 7. */
  get weekday(): number {
    // 1970-01-01 was a Thursday (4).
    return ((((this.dayNumber + 3) % 7) + 7) % 7) + 1;
  }

  get lengthOfMonth(): number {
    return daysInMonth(this.year, this.month);
  }

  get isLastDayOfMonth(): boolean {
    return this.day === this.lengthOfMonth;
  }

  addDays(days: number): CalendarDate {
    checkInteger(days, "days", -3_652_059, 3_652_059);
    return fromDayNumber(this.dayNumber + days);
  }

  /** `months` months later (earlier when negative); the day is clamped to the target month. */
  addMonths(months: number): CalendarDate {
    checkInteger(months, "months", -119_988, 119_988);
    const zeroBased = this.year * 12 + (this.month - 1) + months;
    const year = Math.floor(zeroBased / 12);
    const month = zeroBased - year * 12 + 1;
    return new CalendarDate(year, month, Math.min(this.day, daysInMonth(year, month)));
  }

  addYears(years: number): CalendarDate {
    return this.addMonths(years * 12);
  }

  /** Whole days from `other` to this date (positive when this is later). */
  differenceInDays(other: CalendarDate): number {
    return this.dayNumber - other.dayNumber;
  }

  compareTo(other: CalendarDate): number {
    if (this.year !== other.year) return this.year < other.year ? -1 : 1;
    if (this.month !== other.month) return this.month < other.month ? -1 : 1;
    if (this.day !== other.day) return this.day < other.day ? -1 : 1;
    return 0;
  }

  equals(other: unknown): boolean {
    return other instanceof CalendarDate && this.compareTo(other) === 0;
  }

  isBefore(other: CalendarDate): boolean {
    return this.compareTo(other) < 0;
  }

  isAfter(other: CalendarDate): boolean {
    return this.compareTo(other) > 0;
  }

  isOnOrBefore(other: CalendarDate): boolean {
    return this.compareTo(other) <= 0;
  }

  isOnOrAfter(other: CalendarDate): boolean {
    return this.compareTo(other) >= 0;
  }

  toIso(): string {
    return `${String(this.year).padStart(4, "0")}-${String(this.month).padStart(2, "0")}-${String(this.day).padStart(2, "0")}`;
  }

  toJSON(): string {
    return this.toIso();
  }

  toString(): string {
    return this.toIso();
  }
}

/** A calendar month, e.g. the November 2026 rent period. */
export class MonthPeriod {
  readonly year: number;
  readonly month: number;

  constructor(year: number, month: number) {
    checkInteger(year, "year", 1, 9999);
    checkInteger(month, "month", 1, 12);
    this.year = year;
    this.month = month;
  }

  static of(date: CalendarDate): MonthPeriod {
    return new MonthPeriod(date.year, date.month);
  }

  /** Parses `YYYY-MM` or a full `YYYY-MM-DD` date (the day is ignored). */
  static parse(value: string): MonthPeriod {
    const match = ISO_MONTH.exec(value.trim());
    if (match === null) throw new SyntaxError(`Expected YYYY-MM, got ${JSON.stringify(value)}`);
    const month = Number(match[2]);
    if (month < 1 || month > 12) throw new SyntaxError(`Month must be within 01..12: ${value}`);
    return new MonthPeriod(Number(match[1]), month);
  }

  /** Every month from `from` to `to` inclusive; empty when `to` is before `from`. */
  static range(from: MonthPeriod, to: MonthPeriod): MonthPeriod[] {
    const count = to.monthsSince(from);
    return Array.from({ length: Math.max(0, count + 1) }, (_, i) => from.addMonths(i));
  }

  get first(): CalendarDate {
    return new CalendarDate(this.year, this.month, 1);
  }

  get last(): CalendarDate {
    return new CalendarDate(this.year, this.month, this.lengthInDays);
  }

  get lengthInDays(): number {
    return daysInMonth(this.year, this.month);
  }

  addMonths(months: number): MonthPeriod {
    const zeroBased = this.year * 12 + (this.month - 1) + months;
    const year = Math.floor(zeroBased / 12);
    return new MonthPeriod(year, zeroBased - year * 12 + 1);
  }

  /** Whole months from `other` to this month (positive when this is later). */
  monthsSince(other: MonthPeriod): number {
    return this.year * 12 + this.month - (other.year * 12 + other.month);
  }

  contains(date: CalendarDate): boolean {
    return date.year === this.year && date.month === this.month;
  }

  /** The date in this month with day `day`, clamped to the month's length. */
  dayClamped(day: number): CalendarDate {
    return new CalendarDate(this.year, this.month, Math.min(Math.max(day, 1), this.lengthInDays));
  }

  compareTo(other: MonthPeriod): number {
    const difference = this.monthsSince(other);
    return difference < 0 ? -1 : difference > 0 ? 1 : 0;
  }

  equals(other: unknown): boolean {
    return other instanceof MonthPeriod && this.compareTo(other) === 0;
  }

  toIso(): string {
    return `${String(this.year).padStart(4, "0")}-${String(this.month).padStart(2, "0")}`;
  }

  toString(): string {
    return this.toIso();
  }
}

/** An inclusive range of dates; without an `end` it is open-ended (a periodic tenancy). */
export class DateRange {
  readonly start: CalendarDate;
  readonly end: CalendarDate | null;

  constructor(start: CalendarDate, end: CalendarDate | null = null) {
    if (end?.isBefore(start)) {
      throw new RangeError(`end (${end.toIso()}) must not precede start (${start.toIso()})`);
    }
    this.start = start;
    this.end = end;
  }

  contains(date: CalendarDate): boolean {
    return date.isOnOrAfter(this.start) && (this.end === null || date.isOnOrBefore(this.end));
  }

  overlaps(other: DateRange): boolean {
    const startsBeforeOtherEnds = other.end === null || this.start.isOnOrBefore(other.end);
    const otherStartsBeforeThisEnds = this.end === null || other.start.isOnOrBefore(this.end);
    return startsBeforeOtherEnds && otherStartsBeforeThisEnds;
  }

  intersection(other: DateRange): DateRange | null {
    if (!this.overlaps(other)) return null;
    const first = CalendarDate.max(this.start, other.start);
    let last: CalendarDate | null;
    if (this.end === null) last = other.end;
    else if (other.end === null) last = this.end;
    else last = CalendarDate.min(this.end, other.end);
    return new DateRange(first, last);
  }

  /** Number of days in the range, or `null` when open-ended. */
  get lengthInDays(): number | null {
    return this.end === null ? null : this.end.differenceInDays(this.start) + 1;
  }
}

/**
 * A Pakistani income-tax year: the twelve months ending on 30 June, named
 * after the calendar year in which it ends (ITO 2001 s.74). TY2027 runs from
 * 1 July 2026 to 30 June 2027.
 */
export class TaxYear {
  static readonly START_MONTH = 7;
  readonly endYear: number;

  constructor(endYear: number) {
    checkInteger(endYear, "endYear", 2, 9999);
    this.endYear = endYear;
  }

  static containing(date: CalendarDate): TaxYear {
    return new TaxYear(date.month >= TaxYear.START_MONTH ? date.year + 1 : date.year);
  }

  get start(): CalendarDate {
    return new CalendarDate(this.endYear - 1, TaxYear.START_MONTH, 1);
  }

  get end(): CalendarDate {
    return new CalendarDate(this.endYear, 6, 30);
  }

  contains(date: CalendarDate): boolean {
    return date.isOnOrAfter(this.start) && date.isOnOrBefore(this.end);
  }

  /** Short label, e.g. `TY2027`. */
  get label(): string {
    return `TY${this.endYear}`;
  }

  /** Span label, e.g. `2026-27`. */
  get spanLabel(): string {
    return `${this.endYear - 1}-${String(this.endYear % 100).padStart(2, "0")}`;
  }
}
