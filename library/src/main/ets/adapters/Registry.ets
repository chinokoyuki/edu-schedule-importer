import { ScheduleAdapter } from './Adapter'
import { GenericTableAdapter } from './GenericTableAdapter'
import { QiangzhiAdapter } from './QiangzhiAdapter'
import { EntssAdapter } from './EntssAdapter'
import { PeriodTable } from '../core/PeriodTable'

/**
 * Entry point for picking an adapter by name.
 *
 * ```ts
 * const adapter = EduImporters.byId('qiangzhi')
 * if (adapter !== null) {
 *   const result = adapter.parse(await runInWebView(controller, adapter.script))
 * }
 * ```
 */
export class EduImporters {
  /** Adapter that reads a timetable rendered as an HTML table. */
  static generic(periods: PeriodTable = PeriodTable.standard()): ScheduleAdapter {
    return new GenericTableAdapter(periods)
  }

  /** Adapter for the Qiangzhi (强智) timetable layout. */
  static qiangzhi(periods: PeriodTable = PeriodTable.standard()): ScheduleAdapter {
    return new QiangzhiAdapter(periods)
  }

  /** Adapter for Entss (乘方), which serves the grid from an API. */
  static entss(): ScheduleAdapter {
    return new EntssAdapter()
  }

  /** Looks an adapter up by id. Returns null for unknown ids. */
  static byId(id: string, periods: PeriodTable = PeriodTable.standard()): ScheduleAdapter | null {
    if (id === 'generic-table') {
      return new GenericTableAdapter(periods)
    }
    if (id === 'qiangzhi') {
      return new QiangzhiAdapter(periods)
    }
    if (id === 'entss') {
      return new EntssAdapter()
    }
    return null
  }

  /** Ids of the adapters shipped with this release. */
  static ids(): string[] {
    return ['generic-table', 'qiangzhi', 'entss']
  }
}
