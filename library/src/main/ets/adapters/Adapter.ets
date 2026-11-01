import { ImportResult, ImportedCourse } from '../models/ImportTypes'
import { buildTerm } from '../core/Term'

/**
 * An adapter knows two things: the script that reads the page, and how to turn
 * the script output into courses. It deliberately does not touch a
 * `WebviewController`, so `parse` stays a pure function that can be tested with
 * recorded payloads.
 */
export interface ScheduleAdapter {
  /** Stable identifier, used in {@link ImportResult.adapterId}. */
  readonly id: string
  /** Human readable name for settings screens. */
  readonly label: string
  /** JavaScript to run with `WebviewController.runJavaScript`. */
  readonly script: string
  /** Converts the script output into courses. Never throws. */
  parse(raw: string): ImportResult
}

/** Empty result with the term defaults filled in. */
export function emptyResult(adapterId: string): ImportResult {
  const result: ImportResult = {
    adapterId: adapterId,
    courses: [],
    term: buildTerm('', null, 0),
    warnings: []
  }
  return result
}

/** Adds a course unless an equivalent one is already present. */
export function pushUnique(courses: ImportedCourse[], seen: Set<string>, course: ImportedCourse): void {
  const key: string = `${course.name}|${course.weekday}|${course.startPeriod}|${course.endPeriod}|${course.weeks.join(',')}|${course.room}|${course.teacher}`
  if (seen.has(key)) {
    return
  }
  seen.add(key)
  courses.push(course)
}

/** Builds a course with every field present, so callers never read undefined. */
export function makeCourse(name: string, weekday: number, weekList: number[]): ImportedCourse {
  const course: ImportedCourse = {
    name: name,
    teacher: '',
    room: '',
    campus: '',
    weekday: weekday,
    startPeriod: 0,
    endPeriod: 0,
    weeks: weekList,
    startTime: '',
    endTime: ''
  }
  return course
}
