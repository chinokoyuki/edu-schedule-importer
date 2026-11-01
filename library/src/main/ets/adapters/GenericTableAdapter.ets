import { ImportResult, ImportedCourse, TablePayload } from '../models/ImportTypes'
import { ScheduleAdapter, emptyResult, makeCourse } from './Adapter'
import { PeriodTable } from '../core/PeriodTable'
import { parseWeeks, parseWeekday, maxWeek } from '../core/WeekRules'
import { buildTerm, inferTermStart, parseTermLabel } from '../core/Term'
import { GENERIC_TABLE_SCRIPT } from '../scripts/GenericTableScript'
import { PeriodSlot } from '../models/ImportTypes'

/**
 * Reads a timetable rendered as an HTML table.
 *
 * The page script returns every table as a grid of strings. This adapter picks
 * the largest one, finds the row that names the weekdays, then reads each cell
 * below it. Cells may hold several courses, each written as a name followed by
 * `(1-2节)1-16周` and, optionally, a campus, a room and teachers.
 */
const COURSE_PATTERN: string =
  '([\\u4e00-\\u9fa5A-Za-z][^()★☆■▲◆;；:：,，\\s]{0,29})[★☆■▲◆]?\\(?(\\d{1,2})(?:[-~—](\\d{1,2}))?节\\)?'

interface CourseMatch {
  index: number
  length: number
  name: string
  startPeriod: number
  endPeriod: number
}

interface HeaderMap {
  row: number
  columns: Map<number, number>
}

interface CellInfo {
  weeks: number[]
  campus: string
  room: string
  teacher: string
}

function cleanName(text: string): string {
  const name: string = text.replace(/[★☆■▲◆#]/g, '').replace(/^[·\-—_:：,，;；\s]+/, '').trim()
  return name
}

/** Picks the table with the most cells; timetables are usually the largest one. */
function pickLargest(tables: string[][][]): string[][] | null {
  let best: string[][] | null = null
  let bestCount: number = 0
  for (let i = 0; i < tables.length; i++) {
    const table: string[][] = tables[i]
    if (table === undefined) {
      continue
    }
    let count: number = 0
    for (let r = 0; r < table.length; r++) {
      const row: string[] = table[r]
      if (row !== undefined) {
        count += row.length
      }
    }
    if (count > bestCount) {
      bestCount = count
      best = table
    }
  }
  return best
}

/** Finds the row that names at least three weekdays. */
function findHeader(table: string[][]): HeaderMap | null {
  for (let r = 0; r < table.length; r++) {
    const row: string[] = table[r]
    if (row === undefined) {
      continue
    }
    const columns = new Map<number, number>()
    for (let c = 0; c < row.length; c++) {
      const day: number = parseWeekday(row[c])
      if (day > 0) {
        columns.set(c, day)
      }
    }
    if (columns.size >= 3) {
      const header: HeaderMap = { row: r, columns: columns }
      return header
    }
  }
  return null
}

/** Splits the text that follows a period marker into weeks, campus, room and teacher. */
function parseTail(tail: string): CellInfo {
  const info: CellInfo = { weeks: [], campus: '', room: '', teacher: '' }
  if (tail === '') {
    return info
  }
  let rest: string = tail

  const weekMatch = rest.match(/(\d{1,2}(?:\s*[-~—]\s*\d{1,2})?)\s*周(?:\([^)]*\))?/)
  if (weekMatch !== null) {
    info.weeks = parseWeeks(weekMatch[0])
    rest = rest.replace(weekMatch[0], ' ')
  }

  const campusMatch = rest.match(/([\u4e00-\u9fa5]{2,4}校区)/)
  if (campusMatch !== null) {
    info.campus = campusMatch[1]
    rest = rest.replace(campusMatch[1], ' ')
  }

  const teacherMatch = rest.match(/([\u4e00-\u9fa5]{2,4}\d?(?:[,，][\u4e00-\u9fa5]{2,4}\d?)*)$/)
  if (teacherMatch !== null) {
    info.teacher = teacherMatch[1]
    rest = rest.substring(0, teacherMatch.index)
  }

  let room: string = rest.replace(/\([^)]*\)/g, ' ')
  room = room.replace(/-\d+$/, ' ')
  room = room.replace(/^[\s,，;；:：\-—_]+/, '').replace(/[\s,，;；:：\-—_]+$/, '')
  info.room = room.trim()
  return info
}

export class GenericTableAdapter implements ScheduleAdapter {
  readonly id: string = 'generic-table'
  readonly label: string = 'Generic table'
  readonly script: string = GENERIC_TABLE_SCRIPT
  private periods: PeriodTable

  constructor(periods: PeriodTable = PeriodTable.standard()) {
    this.periods = periods
  }

  parse(raw: string): ImportResult {
    const result: ImportResult = emptyResult(this.id)
    let payload: TablePayload
    try {
      payload = JSON.parse(raw) as TablePayload
    } catch (error) {
      result.warnings.push('invalid_json')
      return result
    }

    const tables: string[][][] = payload.tables === undefined ? [] : payload.tables
    if (payload.error !== undefined && payload.error !== '') {
      result.warnings.push(payload.error)
      return result
    }
    const table: string[][] | null = pickLargest(tables)
    if (table === null) {
      result.warnings.push('no_schedule_page')
      return result
    }
    const header: HeaderMap | null = findHeader(table)
    if (header === null) {
      result.warnings.push('no_weekday_header')
      return result
    }

    let label: string = ''
    if (table.length > 0 && table[0].length > 0) {
      label = parseTermLabel(table[0][0])
    }
    let highest: number = 0
    for (let r = header.row + 1; r < table.length; r++) {
      const row: string[] = table[r]
      if (row === undefined) {
        continue
      }
      header.columns.forEach((weekday: number, column: number) => {
        if (column >= row.length) {
          return
        }
        const cell: string = row[column]
        if (cell === undefined || cell.trim() === '') {
          return
        }
        const courses: ImportedCourse[] = this.parseCell(cell, weekday)
        for (let i = 0; i < courses.length; i++) {
          const course: ImportedCourse = courses[i]
          result.courses.push(course)
          const week: number = maxWeek(course.weeks)
          if (week > highest) {
            highest = week
          }
        }
        if (label === '') {
          label = parseTermLabel(cell)
        }
      })
    }

    if (result.courses.length === 0) {
      result.warnings.push('no_courses')
    }
    result.term = buildTerm(label, label === '' ? null : inferTermStart(label), highest)
    return result
  }

  /**
   * A cell holds one course per line. Schools put several courses in one cell
   * by stacking them, so the line break is the boundary between them; reading
   * the whole cell as one string would let one course's teacher run into the
   * next course's name.
   */
  private parseCell(text: string, weekday: number): ImportedCourse[] {
    const courses: ImportedCourse[] = []
    const rawLines: string[] = text.split(/\n+/)
    const lines: string[] = []
    for (let i = 0; i < rawLines.length; i++) {
      const line: string = rawLines[i].replace(/\s+/g, '')
      if (line !== '') {
        lines.push(line)
      }
    }
    if (lines.length === 0) {
      return courses
    }
    if (lines.length === 1) {
      return this.parseLine(lines[0], weekday, true)
    }
    for (let i = 0; i < lines.length; i++) {
      const parsed: ImportedCourse[] = this.parseLine(lines[i], weekday, false)
      for (let j = 0; j < parsed.length; j++) {
        courses.push(parsed[j])
      }
    }
    return courses
  }

  /**
   * Reads one line. `allowFallback` keeps the whole line as a course name when
   * no period marker is present; that only makes sense for a single-line cell,
   * where the text cannot be a leftover from another course.
   */
  private parseLine(flat: string, weekday: number, allowFallback: boolean): ImportedCourse[] {
    const courses: ImportedCourse[] = []
    if (flat === '') {
      return courses
    }
    const regex: RegExp = new RegExp(COURSE_PATTERN, 'g')
    const matches: CourseMatch[] = []
    let found = regex.exec(flat)
    while (found !== null) {
      const name: string = cleanName(found[1])
      const start: number = parseInt(found[2], 10)
      const end: number = found[3] === undefined ? start : parseInt(found[3], 10)
      if (name !== '' && !isNaN(start)) {
        const match: CourseMatch = {
          index: found.index,
          length: found[0].length,
          name: name,
          startPeriod: start,
          endPeriod: isNaN(end) ? start : end
        }
        matches.push(match)
      }
      found = regex.exec(flat)
    }

    if (matches.length === 0) {
      if (!allowFallback) {
        return courses
      }
      const fallback: string = cleanName(flat)
      if (fallback.length > 1 && fallback.length < 30 && fallback.indexOf('无课') < 0) {
        courses.push(makeCourse(fallback, weekday, []))
      }
      return courses
    }

    for (let i = 0; i < matches.length; i++) {
      const marker: CourseMatch = matches[i]
      const tailEnd: number = i + 1 < matches.length ? matches[i + 1].index : flat.length
      const tail: string = flat.substring(marker.index + marker.length, tailEnd)
      const info: CellInfo = parseTail(tail)
      const course: ImportedCourse = makeCourse(marker.name, weekday, info.weeks)
      course.startPeriod = marker.startPeriod
      course.endPeriod = marker.endPeriod
      course.campus = info.campus
      course.room = info.room
      course.teacher = info.teacher
      const slot: PeriodSlot | null = this.periods.range(marker.startPeriod, marker.endPeriod)
      if (slot !== null) {
        course.startTime = slot.start
        course.endTime = slot.end
      }
      courses.push(course)
    }
    return courses
  }
}
