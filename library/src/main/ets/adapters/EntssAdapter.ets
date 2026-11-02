import { EntssPayload, EntssRecord, ImportResult, ImportedCourse } from '../models/ImportTypes'
import { ScheduleAdapter, emptyResult, makeCourse, pushUnique } from './Adapter'
import { maxWeek, parseWeeks } from '../core/WeekRules'
import { buildTerm, inferTermStart, parseIsoDay } from '../core/Term'
import { ENTSS_SCRIPT } from '../scripts/EntssScript'

/** `202601` becomes `2026-2027学年第1学期`; empty for anything else. */
function semesterLabel(semester: string): string {
  const match = semester.match(/^(\d{4})(\d+)$/)
  if (match === null) {
    return ''
  }
  const year: number = parseInt(match[1], 10)
  if (isNaN(year)) {
    return ''
  }
  const term: number = match[2] === '2' || match[2] === '02' ? 2 : 1
  return `${year}-${year + 1}学年第${term}学期`
}

/** `09:20:00` becomes `09:20`; empty when the value is not a clock time. */
function clock(value: string): string {
  const match = value.match(/^(\d{1,2}):(\d{2})/)
  if (match === null) {
    return ''
  }
  const hour: number = parseInt(match[1], 10)
  if (isNaN(hour)) {
    return ''
  }
  const padded: string = hour < 10 ? `0${hour}` : `${hour}`
  return `${padded}:${match[2]}`
}

/** The API sends weekdays as `"1"` to `"7"`; 0 means "not a weekday". */
function weekdayOf(value: string): number {
  const day: number = parseInt(value, 10)
  if (isNaN(day) || day < 1 || day > 7) {
    return 0
  }
  return day
}

function textOf(value: string | undefined): string {
  return value === undefined ? '' : value.trim()
}

/**
 * Reads an Entss (乘方) timetable.
 *
 * The page builds its grid from an API, so the script calls that API and hands
 * back the rows as they are. Each row carries weeks, weekdays and clock times
 * already, which makes this the only adapter that does not need a period
 * table: `startTime` and `endTime` come from the school's own schedule, and
 * `startPeriod` and `endPeriod` stay 0.
 */
export class EntssAdapter implements ScheduleAdapter {
  readonly id: string = 'entss'
  readonly label: string = 'Entss (乘方)'
  readonly script: string = ENTSS_SCRIPT

  parse(raw: string): ImportResult {
    const result: ImportResult = emptyResult(this.id)
    let payload: EntssPayload
    try {
      payload = JSON.parse(raw) as EntssPayload
    } catch (error) {
      result.warnings.push('invalid_json')
      return result
    }

    if (payload.error !== undefined && payload.error !== '') {
      result.warnings.push(payload.error)
      return result
    }

    const label: string = semesterLabel(payload.sem === undefined ? '' : payload.sem)
    const records: EntssRecord[] = payload.records === undefined ? [] : payload.records
    const seen = new Set<string>()
    let highest: number = 0
    let missingWeeks: number = 0

    for (let i = 0; i < records.length; i++) {
      const record: EntssRecord = records[i]
      if (record === undefined) {
        continue
      }
      const name: string = textOf(record.kcmc)
      if (name === '') {
        continue
      }
      const weeks: number[] = parseWeeks(textOf(record.zc))
      if (weeks.length === 0) {
        missingWeeks++
        continue
      }
      const first: number = weekdayOf(textOf(record.qsxq))
      if (first === 0) {
        continue
      }
      let last: number = weekdayOf(textOf(record.jsxq))
      if (last === 0 || last < first) {
        last = first
      }
      const startTime: string = clock(textOf(record.qssj))
      const endTime: string = clock(textOf(record.jssj))

      for (let day = first; day <= last; day++) {
        const course: ImportedCourse = makeCourse(name, day, weeks)
        course.teacher = textOf(record.teaxms)
        course.room = textOf(record.jxcdmc)
        course.startTime = startTime
        course.endTime = endTime
        pushUnique(result.courses, seen, course)
      }

      const week: number = maxWeek(weeks)
      if (week > highest) {
        highest = week
      }
    }

    if (missingWeeks > 0) {
      result.warnings.push('missing_weeks')
    }
    if (result.courses.length === 0) {
      result.warnings.push('no_courses')
    }

    const stated: Date | null = payload.week1 === undefined ? null : parseIsoDay(payload.week1)
    const start: Date | null = stated !== null ? stated : (label === '' ? null : inferTermStart(label))
    result.term = buildTerm(label, start, highest)
    return result
  }
}
