import { ImportResult, ImportedCourse, PeriodRange, QiangzhiCell, QiangzhiPayload } from '../models/ImportTypes'
import { ScheduleAdapter, emptyResult, makeCourse, pushUnique } from './Adapter'
import { PeriodTable } from '../core/PeriodTable'
import { maxWeek, parsePeriodRange, parseWeeks } from '../core/WeekRules'
import { buildTerm, inferTermStart } from '../core/Term'
import { QIANGZHI_SCRIPT } from '../scripts/QiangzhiScript'
import { PeriodSlot } from '../models/ImportTypes'

/** `2026-2027-1` becomes `2026-2027学年第1学期`. */
function semesterLabel(semester: string): string {
  const match = semester.match(/^(\d{4})-(\d{4})-([12])$/)
  if (match === null) {
    return ''
  }
  return `${match[1]}-${match[2]}学年第${match[3]}学期`
}

/**
 * Reads a Qiangzhi (强智) timetable.
 *
 * The page script already extracts weekday, name, teacher, weeks and room.
 * This adapter turns the week text into numbers, maps periods to times and
 * drops duplicates that appear in several cells.
 */
export class QiangzhiAdapter implements ScheduleAdapter {
  readonly id: string = 'qiangzhi'
  readonly label: string = 'Qiangzhi'
  readonly script: string = QIANGZHI_SCRIPT
  private periods: PeriodTable

  constructor(periods: PeriodTable = PeriodTable.standard()) {
    this.periods = periods
  }

  parse(raw: string): ImportResult {
    const result: ImportResult = emptyResult(this.id)
    let payload: QiangzhiPayload
    try {
      payload = JSON.parse(raw) as QiangzhiPayload
    } catch (error) {
      result.warnings.push('invalid_json')
      return result
    }

    if (payload.error !== undefined && payload.error !== '') {
      result.warnings.push(payload.error)
      return result
    }

    const cells: QiangzhiCell[] = payload.cells === undefined ? [] : payload.cells
    const semester: string = payload.sem === undefined ? '' : payload.sem
    const label: string = semesterLabel(semester)
    const seen = new Set<string>()
    let highest: number = 0
    let missingWeeks: number = 0

    for (let i = 0; i < cells.length; i++) {
      const cell: QiangzhiCell = cells[i]
      const weekday: number = cell.d === undefined ? 0 : cell.d
      const name: string = cell.n === undefined ? '' : cell.n.trim()
      if (weekday < 1 || weekday > 7 || name === '') {
        continue
      }
      const weekText: string = cell.w === undefined ? '' : cell.w
      const weeks: number[] = parseWeeks(weekText)
      if (weeks.length === 0) {
        missingWeeks++
        continue
      }

      const course: ImportedCourse = makeCourse(name, weekday, weeks)
      course.teacher = cell.t === undefined ? '' : cell.t.trim()
      course.room = cell.r === undefined ? '' : cell.r.trim()

      const range: PeriodRange | null = parsePeriodRange(weekText)
      if (range !== null) {
        course.startPeriod = range.start
        course.endPeriod = range.end
        const slot: PeriodSlot | null = this.periods.range(range.start, range.end)
        if (slot !== null) {
          course.startTime = slot.start
          course.endTime = slot.end
        }
      }

      pushUnique(result.courses, seen, course)
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
    result.term = buildTerm(label, label === '' ? null : inferTermStart(label), highest)
    return result
  }
}
