import { TermInfo } from '../models/ImportTypes'

const DEFAULT_TOTAL_WEEKS: number = 20

/** Extracts `2026-2027学年第1学期` from arbitrary text; returns an empty string when absent. */
export function parseTermLabel(text: string): string {
  const match = text.match(/\d{4}-\d{4}学年第[12]学期/)
  return match === null ? '' : match[0]
}

/** First Monday of a month. `month` is 1-12. */
export function firstMondayOf(year: number, month: number): Date {
  const first = new Date(year, month - 1, 1)
  const weekday: number = first.getDay() === 0 ? 7 : first.getDay()
  return new Date(year, month - 1, 1 + (8 - weekday) % 7)
}

/**
 * Approximates the Monday of week 1 from a term label.
 *
 * Term 1 starts on the first Monday of September. Term 2 starts on the first
 * Monday on or after 20 February of the following year. Schools differ, so
 * treat this as a starting point the user can correct.
 */
export function inferTermStart(label: string): Date | null {
  const match = label.match(/(\d{4})-(\d{4})学年第([12])学期/)
  if (match === null) {
    return null
  }
  const startYear: number = parseInt(match[1], 10)
  if (isNaN(startYear)) {
    return null
  }
  if (match[3] === '1') {
    return firstMondayOf(startYear, 9)
  }
  const base = new Date(startYear + 1, 1, 20)
  const weekday: number = base.getDay() === 0 ? 7 : base.getDay()
  return new Date(startYear + 1, 1, 20 + (8 - weekday) % 7)
}

/** Reads `2026-09-07` or `2026/9/7` into a local date; returns null when invalid. */
export function parseIsoDay(text: string): Date | null {
  const match = text.match(/(\d{4})[-/](\d{1,2})[-/](\d{1,2})/)
  if (match === null) {
    return null
  }
  const year: number = parseInt(match[1], 10)
  const month: number = parseInt(match[2], 10)
  const day: number = parseInt(match[3], 10)
  if (isNaN(year) || isNaN(month) || isNaN(day) || month < 1 || month > 12 || day < 1 || day > 31) {
    return null
  }
  return new Date(year, month - 1, day)
}

/** Assembles term metadata, falling back to 20 weeks when the highest week is unknown. */
export function buildTerm(label: string, start: Date | null, highestWeek: number): TermInfo {
  const term: TermInfo = {
    label: label,
    startDate: start,
    totalWeeks: highestWeek > 0 ? highestWeek : DEFAULT_TOTAL_WEEKS
  }
  return term
}
