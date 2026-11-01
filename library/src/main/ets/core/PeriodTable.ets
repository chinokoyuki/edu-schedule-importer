import { PeriodSlot } from '../models/ImportTypes'

/**
 * Period times. The defaults match a common eight-period day: four in the
 * morning, four in the afternoon. Replace them when a school uses a different
 * layout, or when the timetable page states its own times.
 */
export const DEFAULT_PERIODS: PeriodSlot[] = [
  { start: '08:00', end: '08:45' },
  { start: '09:00', end: '09:45' },
  { start: '10:00', end: '10:45' },
  { start: '11:00', end: '11:45' },
  { start: '14:00', end: '14:45' },
  { start: '15:00', end: '15:45' },
  { start: '16:00', end: '16:45' },
  { start: '17:00', end: '17:45' }
]

export class PeriodTable {
  private slots: PeriodSlot[]

  constructor(slots: PeriodSlot[] = DEFAULT_PERIODS) {
    this.slots = slots
  }

  /** Eight-period table described in {@link DEFAULT_PERIODS}. */
  static standard(): PeriodTable {
    return new PeriodTable(DEFAULT_PERIODS)
  }

  size(): number {
    return this.slots.length
  }

  /** Start and end of a single period. Returns null when out of range. */
  slot(period: number): PeriodSlot | null {
    const index: number = period - 1
    if (index < 0 || index >= this.slots.length) {
      return null
    }
    return this.slots[index]
  }

  /** Merged range from `start` to `end`, or null when either is out of range. */
  range(start: number, end: number): PeriodSlot | null {
    const first: PeriodSlot | null = this.slot(start)
    const last: PeriodSlot | null = this.slot(end >= start ? end : start)
    if (first === null || last === null) {
      return null
    }
    const merged: PeriodSlot = { start: first.start, end: last.end }
    return merged
  }
}
