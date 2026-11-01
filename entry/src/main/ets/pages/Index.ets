import { webview } from '@kit.ArkWeb';
import {
  compressWeeks,
  EduImporters,
  ImportedCourse,
  ImportResult,
  ScheduleAdapter,
  runInWebView
} from '@chinokoyuki/edu-schedule-importer';

const WEEKDAY_NAMES: string[] = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

interface CourseRow {
  key: string;
  title: string;
  detail: string;
}

/**
 * Turns a course into one line of text. Times and weeks are optional: a cell
 * that only holds a name still produces a row.
 */
function describe(course: ImportedCourse): CourseRow {
  const day: string = WEEKDAY_NAMES[course.weekday];
  const periods: string = course.startPeriod === course.endPeriod
    ? `${course.startPeriod}`
    : `${course.startPeriod}-${course.endPeriod}`;
  const place: string = `${course.campus} ${course.room}`.trim();
  const parts: string[] = [`${day} ${periods}`];
  if (course.startTime !== '') {
    parts.push(`${course.startTime}-${course.endTime}`);
  }
  if (course.weeks.length > 0) {
    parts.push(compressWeeks(course.weeks));
  }
  if (course.teacher !== '') {
    parts.push(course.teacher);
  }
  if (place !== '') {
    parts.push(place);
  }
  const row: CourseRow = {
    key: `${course.name}|${course.weekday}|${course.startPeriod}`,
    title: course.name,
    detail: parts.join('  ·  ')
  };
  return row;
}

@Entry
@Component
struct Index {
  private controller: webview.WebviewController = new webview.WebviewController();
  @State rows: CourseRow[] = [];
  @State status: string = 'Opening the page';
  @State warnings: string = '';
  @State loaded: boolean = false;

  readTimetable(): void {
    const adapter: ScheduleAdapter | null = EduImporters.byId('generic-table');
    if (adapter === null) {
      this.status = 'Adapter not found';
      return;
    }
    this.status = 'Reading the page';
    runInWebView(this.controller, adapter.script)
      .then((raw: string) => {
        const result: ImportResult = adapter.parse(raw);
        const collected: CourseRow[] = [];
        for (let i = 0; i < result.courses.length; i++) {
          collected.push(describe(result.courses[i]));
        }
        this.rows = collected;
        this.warnings = result.warnings.length === 0 ? '' : `warnings: ${result.warnings.join(', ')}`;
        this.status = `${collected.length} courses, ${result.term.label}, ${result.term.totalWeeks} weeks`;
      })
      .catch(() => {
        this.status = 'Import failed';
      });
  }

  build() {
    Column({ space: 8 }) {
      Text('edu-schedule-importer')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
        .width('100%');
      Text('A local page stands in for a school site. A real app points the Web component at the timetable page and asks the user to sign in first.')
        .fontSize(12)
        .fontColor('#6B6B6B')
        .width('100%');

      Web({ src: $rawfile('mock_timetable.html'), controller: this.controller })
        .javaScriptAccess(true)
        .height(260)
        .width('100%')
        .border({ width: 1, color: '#E0E0E4' })
        .onPageEnd(() => {
          this.loaded = true;
          this.status = 'Page ready';
        });

      Row({ space: 8 }) {
        Button('Read timetable')
          .enabled(this.loaded)
          .onClick(() => {
            this.readTimetable();
          });
        Button('Clear')
          .backgroundColor('#E8E8EC')
          .fontColor('#1D1D1F')
          .onClick(() => {
            this.rows = [];
            this.warnings = '';
            this.status = this.loaded ? 'Page ready' : 'Opening the page';
          });
      }
      .width('100%');

      Text(this.status)
        .fontSize(12)
        .fontColor('#6B6B6B')
        .width('100%');
      if (this.warnings !== '') {
        Text(this.warnings)
          .fontSize(12)
          .fontColor('#B4531A')
          .width('100%');
      }

      List({ space: 2 }) {
        ForEach(this.rows, (row: CourseRow) => {
          ListItem() {
            Column({ space: 2 }) {
              Text(row.title).fontSize(15).width('100%');
              Text(row.detail).fontSize(12).fontColor('#6B6B6B').width('100%');
            }
            .alignItems(HorizontalAlign.Start)
            .padding({ top: 7, bottom: 7 })
            .width('100%');
          }
        }, (row: CourseRow): string => row.key)
      }
      .layoutWeight(1)
      .width('100%');
    }
    .padding(18)
    .width('100%')
    .height('100%');
  }
}
