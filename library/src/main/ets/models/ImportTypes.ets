/**
 * Data shapes returned by the importers.
 *
 * Weekdays are numbers (1 = Monday, 7 = Sunday) and periods are 1-based
 * indexes into a {@link PeriodTable}, so callers can map them to whatever
 * layout their own timetable uses.
 */

/** Start and end time of one period, formatted as HH:mm. */
export interface PeriodSlot {
  start: string
  end: string
}

/** A course as it appears on the timetable. */
export interface ImportedCourse {
  name: string
  teacher: string
  room: string
  campus: string
  /** 1 = Monday ... 7 = Sunday. 0 when the source did not provide one. */
  weekday: number
  /** 0 when the source did not provide one. */
  startPeriod: number
  endPeriod: number
  /** Week numbers, ascending and deduplicated. Empty when unknown. */
  weeks: number[]
  /** HH:mm, empty when the period table has no matching slot. */
  startTime: string
  endTime: string
}

/** Semester metadata recovered from the page. */
export interface TermInfo {
  /** For example `2026-2027学年第1学期`. Empty when the page did not show it. */
  label: string
  /** Monday of week 1, when it could be determined. */
  startDate: Date | null
  /** Highest week number seen in the timetable, or 20 when unknown. */
  totalWeeks: number
}

/** Result of one import run. */
export interface ImportResult {
  /** Identifier of the adapter that produced this result. */
  adapterId: string
  courses: ImportedCourse[]
  term: TermInfo
  /**
   * Non-fatal problems, as stable codes: `invalid_json`, `no_schedule_page`,
   * `no_weekday_header`, `no_courses`.
   */
  warnings: string[]
}

/** Inclusive period range extracted from text such as `1-2节`. */
export interface PeriodRange {
  start: number
  end: number
}

/** One cell of a Qiangzhi timetable. */
export interface QiangzhiCell {
  /** Weekday, 1-7. */
  d?: number
  /** Course name. */
  n?: string
  /** Teacher. */
  t?: string
  /** Week and period text, e.g. `1-16周(1-2节)`. */
  w?: string
  /** Room. */
  r?: string
}

/** Payload produced by the Qiangzhi page script. */
export interface QiangzhiPayload {
  error?: string
  sem?: string
  cells?: QiangzhiCell[]
}

/** Payload produced by the generic table script. */
export interface TablePayload {
  error?: string
  url?: string
  tables?: string[][][]
}

/**
 * One row of the Entss (乘方) timetable API. The page renders its grid from
 * these records, so the fields are already structured — no scraping needed.
 */
export interface EntssRecord {
  /** Course name. */
  kcmc?: string
  /** Teachers, as the API joins them. */
  teaxms?: string
  /** Classroom. */
  jxcdmc?: string
  /** Weeks, for example `1-8,10-12`. */
  zc?: string
  /** First weekday, 1-7. */
  qsxq?: string
  /** Last weekday, 1-7. Usually the same as `qsxq`. */
  jsxq?: string
  /** Start time, `09:20:00`. */
  qssj?: string
  /** End time, `11:50:00`. */
  jssj?: string
}

/** Payload produced by the Entss page script. */
export interface EntssPayload {
  error?: string
  /** Semester code, for example `202601`. */
  sem?: string
  /** Monday of week 1 as `2026-09-07`. Empty when the page did not say. */
  week1?: string
  records?: EntssRecord[]
}
