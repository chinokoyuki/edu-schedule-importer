import { describe, it, expect } from '@ohos/hypium'
import { compressWeeks, parsePeriodRange, parseWeeks, parseWeekday } from '../main/ets/core/WeekRules'
import { inferTermStart, parseTermLabel } from '../main/ets/core/Term'
import { EduImporters } from '../main/ets/adapters/Registry'
import { ImportResult, ImportedCourse } from '../main/ets/models/ImportTypes'

const GENERIC_PAYLOAD: string = '{"url":"https://example.edu/timetable","tables":[' +
  '[["课表"],["星期一","星期二"]],' +
  '[["2026-2027学年第1学期","","","","",""],' +
  '["节次","星期一","星期二","星期三","星期四","星期五"],' +
  '["1-2","高等数学★(1-2节)1-16周东湖校区教学楼203张三","","大学物理(3-4节)1-8周(单)西区校区实验楼101李四","",""],' +
  '["3-4","","线性代数(1-2节)3-6周东湖校区教学楼305王五","","",""]]' +
  ']}'

const QIANGZHI_PAYLOAD: string = '{"system":"qiangzhi","sem":"2026-2027-1","cells":[' +
  '{"d":1,"n":"高等数学","t":"王五","w":"1-16周(1-2节)","r":"教学楼203"},' +
  '{"d":3,"n":"大学物理","t":"赵六","w":"1-15周(单)(3-4节)","r":"实验楼101"},' +
  '{"d":3,"n":"大学物理","t":"赵六","w":"1-15周(单)(3-4节)","r":"实验楼101"}' +
  ']}'

export default function eduImporterTest() {
  describe('week rules', () => {
    it('expands ranges, lists and odd or even markers', 0, () => {
      expect(parseWeeks('1-16周').length).assertEqual(16)
      expect(parseWeeks('1-8,10-12周').length).assertEqual(11)
      expect(parseWeeks('1-15周(单)').join(',')).assertEqual('1,3,5,7,9,11,13,15')
      expect(parseWeeks('2-10周(双)').join(',')).assertEqual('2,4,6,8,10')
      expect(parseWeeks('5,4,4,3').join(',')).assertEqual('3,4,5')
      expect(parseWeeks('').length).assertEqual(0)
    })

    it('compresses a week list', 0, () => {
      expect(compressWeeks([1, 2, 3, 5])).assertEqual('1-3,5周')
      expect(compressWeeks([])).assertEqual('')
    })

    it('reads weekdays from Chinese and English text', 0, () => {
      expect(parseWeekday('星期一')).assertEqual(1)
      expect(parseWeekday('周日')).assertEqual(7)
      expect(parseWeekday('周三')).assertEqual(3)
      expect(parseWeekday('Monday')).assertEqual(1)
      expect(parseWeekday('Fri')).assertEqual(5)
      expect(parseWeekday('节次')).assertEqual(0)
    })

    it('reads period ranges', 0, () => {
      const first = parsePeriodRange('1-2节')
      expect(first !== null).assertTrue()
      if (first !== null) {
        expect(first.start).assertEqual(1)
        expect(first.end).assertEqual(2)
      }
      const single = parsePeriodRange('第3节')
      expect(single !== null).assertTrue()
      if (single !== null) {
        expect(single.end).assertEqual(3)
      }
      const mixed = parsePeriodRange('1-15周(单)(3-4节)')
      expect(mixed !== null).assertTrue()
      if (mixed !== null) {
        expect(mixed.start).assertEqual(3)
      }
      expect(parsePeriodRange('无') === null).assertTrue()
    })
  })

  describe('term', () => {
    it('reads the semester label', 0, () => {
      expect(parseTermLabel('2026-2027学年第1学期的课表')).assertEqual('2026-2027学年第1学期')
      expect(parseTermLabel('没有学期信息')).assertEqual('')
    })

    it('infers the first Monday of the term', 0, () => {
      const autumn = inferTermStart('2026-2027学年第1学期')
      expect(autumn !== null).assertTrue()
      if (autumn !== null) {
        expect(autumn.getMonth()).assertEqual(8)
        expect(autumn.getDate()).assertEqual(7)
        expect(autumn.getDay()).assertEqual(1)
      }
      const spring = inferTermStart('2026-2027学年第2学期')
      expect(spring !== null).assertTrue()
      if (spring !== null) {
        expect(spring.getMonth()).assertEqual(1)
        expect(spring.getDay()).assertEqual(1)
      }
    })
  })

  describe('generic table adapter', () => {
    it('picks the timetable and reads its cells', 0, () => {
      const adapter = EduImporters.byId('generic-table')
      expect(adapter !== null).assertTrue()
      if (adapter === null) {
        return
      }
      const result: ImportResult = adapter.parse(GENERIC_PAYLOAD)
      expect(result.courses.length).assertEqual(3)

      const math: ImportedCourse = result.courses[0]
      expect(math.name).assertEqual('高等数学')
      expect(math.weekday).assertEqual(1)
      expect(math.startPeriod).assertEqual(1)
      expect(math.endPeriod).assertEqual(2)
      expect(math.weeks.length).assertEqual(16)
      expect(math.campus).assertEqual('东湖校区')
      expect(math.room).assertEqual('教学楼203')
      expect(math.teacher).assertEqual('张三')
      expect(math.startTime).assertEqual('08:00')
      expect(math.endTime).assertEqual('09:45')

      const physics: ImportedCourse = result.courses[1]
      expect(physics.weekday).assertEqual(3)
      expect(physics.weeks.join(',')).assertEqual('1,3,5,7')
      expect(physics.room).assertEqual('实验楼101')
      expect(result.term.label).assertEqual('2026-2027学年第1学期')
      expect(result.term.totalWeeks).assertEqual(16)
    })

    it('keeps a cell that has no period marker', 0, () => {
      const adapter = EduImporters.byId('generic-table')
      if (adapter === null) {
        return
      }
      const payload: string = '{"tables":[[["节次","星期一","星期二","星期三"],["1","班会","",""]]]}'
      const result: ImportResult = adapter.parse(payload)
      expect(result.courses.length).assertEqual(1)
      expect(result.courses[0].name).assertEqual('班会')
      expect(result.courses[0].weeks.length).assertEqual(0)
    })

    it('reads two courses from one cell when they are stacked', 0, () => {
      const adapter = EduImporters.byId('generic-table')
      if (adapter === null) {
        return
      }
      const payload: string = '{"tables":[[["节次","星期一","星期二","星期三"],' +
        '["7-8","形势与政策(7-8节)9-12周教学楼101吴十\\n学术讲座(7-8节)13-16周报告厅201郑一","",""]]]}'
      const result: ImportResult = adapter.parse(payload)
      expect(result.courses.length).assertEqual(2)
      expect(result.courses[0].name).assertEqual('形势与政策')
      expect(result.courses[1].name).assertEqual('学术讲座')
      expect(result.courses[0].teacher).assertEqual('吴十')
      expect(result.courses[1].teacher).assertEqual('郑一')
      expect(result.courses[1].room).assertEqual('报告厅201')
    })

    it('reports unusable input', 0, () => {
      const adapter = EduImporters.byId('generic-table')
      if (adapter === null) {
        return
      }
      expect(adapter.parse('not json').warnings[0]).assertEqual('invalid_json')
      expect(adapter.parse('{"tables":[]}').warnings[0]).assertEqual('no_schedule_page')
      expect(adapter.parse('{"tables":[[["a","b"]]]}').warnings[0]).assertEqual('no_weekday_header')
      expect(adapter.parse('{"error":"script_failed"}').warnings[0]).assertEqual('script_failed')
    })
  })

  describe('qiangzhi adapter', () => {
    it('reads cells and removes duplicates', 0, () => {
      const adapter = EduImporters.byId('qiangzhi')
      expect(adapter !== null).assertTrue()
      if (adapter === null) {
        return
      }
      const result: ImportResult = adapter.parse(QIANGZHI_PAYLOAD)
      expect(result.courses.length).assertEqual(2)
      expect(result.term.label).assertEqual('2026-2027学年第1学期')
      expect(result.term.totalWeeks).assertEqual(16)

      const physics: ImportedCourse = result.courses[1]
      expect(physics.weekday).assertEqual(3)
      expect(physics.startPeriod).assertEqual(3)
      expect(physics.endPeriod).assertEqual(4)
      expect(physics.weeks.join(',')).assertEqual('1,3,5,7,9,11,13,15')
      expect(physics.startTime).assertEqual('10:00')
      expect(physics.endTime).assertEqual('11:45')
    })

    it('reports page errors and courses without weeks', 0, () => {
      const adapter = EduImporters.byId('qiangzhi')
      if (adapter === null) {
        return
      }
      expect(adapter.parse('{"error":"no_schedule_page"}').warnings[0]).assertEqual('no_schedule_page')
      const missing: ImportResult = adapter.parse('{"cells":[{"d":1,"n":"课","w":""}]}')
      expect(missing.warnings.indexOf('missing_weeks') >= 0).assertTrue()
      expect(missing.warnings.indexOf('no_courses') >= 0).assertTrue()
    })
  })

  describe('registry', () => {
    it('lists adapters and rejects unknown ids', 0, () => {
      expect(EduImporters.ids().length).assertEqual(2)
      expect(EduImporters.byId('nope') === null).assertTrue()
    })
  })
}
