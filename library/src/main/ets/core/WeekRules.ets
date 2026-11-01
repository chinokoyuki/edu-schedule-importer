import { PeriodRange } from '../models/ImportTypes'

const MIN_WEEK: number = 1
const MAX_WEEK: number = 60
const CN_DIGITS: string = '一二三四五六日'
const EN_WEEKDAYS: string[] = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday']

/**
 * Reads week numbers from text such as `1-16周`, `1-8,10-16周`, `1-15周(单)`
 * or `第3-5周`. Odd and even markers are applied after the ranges expand.
 */
export function parseWeeks(raw: string): number[] {
  if (raw.trim() === '') {
    return []
  }
  const oddOnly: boolean = raw.indexOf('单') >= 0
  const evenOnly: boolean = raw.indexOf('双') >= 0
  let text: string = raw.replace(/\([^)]*\)/g, ' ')
  text = text.replace(/周/g, ' ')
  text = text.replace(/[，；;、\/]/g, ',')
  const collected: number[] = []
  const tokens: string[] = text.split(',')
  for (let i = 0; i < tokens.length; i++) {
    const part: string = tokens[i].trim()
    if (part === '') {
      continue
    }
    const range = part.match(/^第?(\d{1,2})\s*[-~—]\s*(\d{1,2})$/)
    if (range !== null) {
      const start: number = parseInt(range[1], 10)
      const end: number = parseInt(range[2], 10)
      if (!isNaN(start) && !isNaN(end) && start >= MIN_WEEK && end >= start && end <= MAX_WEEK) {
        for (let week = start; week <= end; week++) {
          collected.push(week)
        }
      }
      continue
    }
    const single = part.match(/^第?(\d{1,2})$/)
    if (single !== null) {
      const week: number = parseInt(single[1], 10)
      if (!isNaN(week) && week >= MIN_WEEK && week <= MAX_WEEK) {
        collected.push(week)
      }
    }
  }
  const unique = new Set<number>()
  for (let i = 0; i < collected.length; i++) {
    const week: number = collected[i]
    if (oddOnly && week % 2 === 0) {
      continue
    }
    if (evenOnly && week % 2 === 1) {
      continue
    }
    unique.add(week)
  }
  const result: number[] = Array.from(unique)
  result.sort((a: number, b: number): number => a - b)
  return result
}

/** Turns `[1,2,3,5]` into `1-3,5周`; returns an empty string for an empty input. */
export function compressWeeks(weeks: number[]): string {
  if (weeks.length === 0) {
    return ''
  }
  const sorted: number[] = weeks.slice()
  sorted.sort((a: number, b: number): number => a - b)
  const parts: string[] = []
  let segmentStart: number = sorted[0]
  let previous: number = sorted[0]
  for (let i = 1; i <= sorted.length; i++) {
    const current: number = i < sorted.length ? sorted[i] : -1
    if (current === previous + 1) {
      previous = current
      continue
    }
    parts.push(segmentStart === previous ? `${segmentStart}` : `${segmentStart}-${previous}`)
    if (i < sorted.length) {
      segmentStart = current
      previous = current
    }
  }
  return `${parts.join(',')}周`
}

/** Maps `星期一` / `周一` / `Monday` / `Mon` to 1-7; returns 0 when unknown. */
export function parseWeekday(text: string): number {
  const trimmed: string = text.trim()
  if (trimmed === '' || trimmed.length > 16) {
    return 0
  }
  const chinese = trimmed.match(/(?:星期|周)([一二三四五六日天])/)
  if (chinese !== null) {
    const symbol: string = chinese[1]
    if (symbol === '天') {
      return 7
    }
    const index: number = CN_DIGITS.indexOf(symbol)
    return index >= 0 ? index + 1 : 0
  }
  const lower: string = trimmed.toLowerCase()
  for (let i = 0; i < EN_WEEKDAYS.length; i++) {
    const full: string = EN_WEEKDAYS[i]
    if (lower.indexOf(full) >= 0 || lower.indexOf(full.substring(0, 3)) >= 0) {
      return i + 1
    }
  }
  return 0
}

/** Reads `1-2节` / `第3节` into a period range; returns null when absent. */
export function parsePeriodRange(text: string): PeriodRange | null {
  const match = text.match(/(?:第)?(\d{1,2})\s*(?:[-~—]\s*(\d{1,2}))?\s*节/)
  if (match === null) {
    return null
  }
  const start: number = parseInt(match[1], 10)
  if (isNaN(start) || start < 1) {
    return null
  }
  const end: number = match[2] === undefined ? start : parseInt(match[2], 10)
  const result: PeriodRange = { start: start, end: isNaN(end) || end < start ? start : end }
  return result
}

/** Highest week number in the list, or 0 when the list is empty. */
export function maxWeek(weeks: number[]): number {
  let highest: number = 0
  for (let i = 0; i < weeks.length; i++) {
    if (weeks[i] > highest) {
      highest = weeks[i]
    }
  }
  return highest
}
