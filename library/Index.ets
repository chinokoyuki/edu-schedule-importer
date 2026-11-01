/**
 * Public entry point of edu-schedule-importer.
 */
export {
  ImportedCourse,
  ImportResult,
  PeriodRange,
  PeriodSlot,
  QiangzhiCell,
  QiangzhiPayload,
  TablePayload,
  TermInfo
} from './src/main/ets/models/ImportTypes'

export { DEFAULT_PERIODS, PeriodTable } from './src/main/ets/core/PeriodTable'
export { compressWeeks, maxWeek, parsePeriodRange, parseWeekday, parseWeeks } from './src/main/ets/core/WeekRules'
export { buildTerm, firstMondayOf, inferTermStart, parseIsoDay, parseTermLabel } from './src/main/ets/core/Term'

export { ScheduleAdapter } from './src/main/ets/adapters/Adapter'
export { GenericTableAdapter } from './src/main/ets/adapters/GenericTableAdapter'
export { QiangzhiAdapter } from './src/main/ets/adapters/QiangzhiAdapter'
export { EduImporters } from './src/main/ets/adapters/Registry'

export { runInWebView, unwrapScriptResult } from './src/main/ets/web/WebViewRunner'
export { GENERIC_TABLE_SCRIPT } from './src/main/ets/scripts/GenericTableScript'
export { QIANGZHI_SCRIPT } from './src/main/ets/scripts/QiangzhiScript'
