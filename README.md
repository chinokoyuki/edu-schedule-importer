# edu-schedule-importer

Reads a school timetable out of an ArkWeb session and turns it into structured courses. Built for HarmonyOS with ArkTS.

The user opens their school site in a `Web` component, signs in as usual, and taps a button. An injected script reads the timetable that is already on screen; an adapter converts it into courses, weeks and periods.

[中文说明](README.zh-CN.md)

## Scope

This library reads a page the user has already opened and signed in to. It does not ask for, store or transmit credentials, and it does not bypass authentication. Use it only with accounts and systems you are permitted to access.

It also ships no school list. Which adapter to use is a choice the app makes, not something this repository decides.

## Features

- Three adapters: a generic HTML table reader, one for the Qiangzhi (强智) layout, and one for Entss (乘方), which reads the API the page calls itself
- Injected scripts return plain JSON, so parsing can be tested without a device
- Week text handling: `1-16周`, `1-8,10-12周`, `1-15周(单)`, `第3-5周`
- Period to time mapping through a configurable table
- Semester label extraction and a first-Monday estimate
- No runtime dependencies beyond ArkWeb

## Requirements

Stage model, ArkTS. Targets SDK 6.1.1(24). The app needs `ohos.permission.INTERNET` for the `Web` component.

## Install

```json5
// entry/oh-package.json5
{
  "dependencies": {
    "@chinokoyuki/edu-schedule-importer": "file:../edu-schedule-importer/library"
  }
}
```

Then run `ohpm install` in the project root.

## Quick start

```ts
import { webview } from '@kit.ArkWeb'
import { EduImporters, ImportResult, ScheduleAdapter, runInWebView } from '@chinokoyuki/edu-schedule-importer'

@Entry
@Component
struct ImportPage {
  private controller: webview.WebviewController = new webview.WebviewController()
  @State summary: string = ''

  async readTimetable(): Promise<void> {
    const adapter: ScheduleAdapter | null = EduImporters.byId('qiangzhi')
    if (adapter === null) {
      return
    }
    const raw: string = await runInWebView(this.controller, adapter.script)
    const result: ImportResult = adapter.parse(raw)
    this.summary = `${result.courses.length} courses, ${result.term.label}`
  }

  build() {
    Column() {
      Web({ src: 'https://your-school.example/', controller: this.controller })
        .layoutWeight(1)
      Button('Read timetable').onClick(() => {
        this.readTimetable()
      })
      Text(this.summary)
    }
  }
}
```

Call `readTimetable` after the user has reached the timetable page. The script reads the current document, so an early call usually returns `no_schedule_page`.

## API

| Symbol | Purpose |
| --- | --- |
| `EduImporters.byId(id)` | Returns an adapter, or null for an unknown id. |
| `EduImporters.ids()` | Ids shipped with this release: `generic-table`, `qiangzhi`, `entss`. |
| `EduImporters.generic(periods?)` / `.qiangzhi(periods?)` | Builds an adapter directly. |
| `EduImporters.entss()` | Builds the Entss adapter, which needs no period table. |
| `runInWebView(controller, script)` | Runs the script in the page. Never rejects; see below. |
| `unwrapScriptResult(text)` | Removes the extra JSON string layer some kernels add. |
| `adapter.parse(raw)` | Converts script output into an `ImportResult`. Never throws. |
| `parseWeeks(text)` / `compressWeeks(weeks)` | Week text to numbers and back. |
| `parseWeekday(text)` | `星期一` / `周一` / `Monday` to 1-7, 0 when unknown. |
| `parsePeriodRange(text)` | `1-2节` to `{ start, end }`. |
| `parseTermLabel(text)` / `inferTermStart(label)` | Semester label and an estimated first Monday. |
| `PeriodTable.standard()` | Eight-period day, 08:00 to 17:45. |

### Result

```ts
interface ImportResult {
  adapterId: string
  courses: ImportedCourse[]
  term: TermInfo
  warnings: string[]
}
```

`ImportedCourse` carries `name`, `teacher`, `room`, `campus`, `weekday` (1-7), `startPeriod`, `endPeriod`, `weeks`, `startTime` and `endTime`. `TermInfo` carries `label`, `startDate` and `totalWeeks`.

`startPeriod` and `endPeriod` are 0 for Entss courses. That adapter gets clock times from the school's own schedule instead of mapping period numbers, so `startTime` and `endTime` are the fields to read.

Warnings are stable codes: `invalid_json`, `no_schedule_page`, `no_semester`, `request_failed`, `no_weekday_header`, `no_courses`, `missing_weeks`, `script_failed`.

`runInWebView` returns `{"error":"script_failed"}` instead of rejecting when ArkWeb refuses to run the script. The adapters turn that into the `script_failed` warning, so the whole flow needs no `try` block.

## Payload contracts

Adapters consume JSON, which makes them easy to test and easy to replace.

`generic-table`

```json
{
  "url": "https://example.edu/timetable",
  "tables": [
    [["节次", "星期一", "星期二"], ["1-2", "高等数学(1-2节)1-16周", "", ""]]
  ]
}
```

Every table is an array of rows, each row an array of cell texts. `rowspan` and `colspan` are already expanded.

A cell holds one course per line. Schools stack two courses in one cell more often than they separate them with punctuation, so the line break is the boundary:

```json
{
  "tables": [
    [["节次", "星期一", "星期二", "星期三"],
     ["7-8", "形势与政策(7-8节)9-12周教学楼101吴十\n学术讲座(7-8节)13-16周报告厅201郑一", "", ""]]
  ]
}
```

That cell yields two courses. Reading it as one string would let the first course's teacher run into the second course's name.

`qiangzhi`

```json
{
  "sem": "2026-2027-1",
  "cells": [
    { "d": 1, "n": "高等数学", "t": "王五", "w": "1-16周(1-2节)", "r": "教学楼203" }
  ]
}
```

`entss`

```json
{
  "sem": "202601",
  "week1": "2026-09-07",
  "records": [
    {
      "kcmc": "高等数学", "teaxms": "张三", "jxcdmc": "博学楼203",
      "zc": "1-16", "qsxq": "1", "jsxq": "1",
      "qssj": "08:00:00", "jssj": "09:40:00"
    }
  ]
}
```

`records` are the rows of the school's timetable API, passed through unchanged. `zc` holds weeks as `1-8,10-12`, `qsxq` and `jsxq` hold weekdays as numbers, and the two time fields use `HH:mm:ss`. When `jsxq` is past `qsxq`, the course is repeated for each day in between, which is how a lab booked across three afternoons arrives.

## Writing an adapter

1. Run a script that returns JSON. Keep DOM work inside the page; ArkTS has no DOM.
2. Parse that JSON into `ImportResult`, using the helpers in `core/`.
3. Register the id in `EduImporters` and add a test with a recorded payload.

Record payloads from a test account, then delete names, rooms and anything that identifies a person. Synthetic payloads are better.

## Project layout

```
library/                     the module, and what ohpm publishes
  Index.ets                  public exports
  src/main/ets/core          week, period and term helpers
  src/main/ets/adapters      adapters and the registry
  src/main/ets/scripts       JavaScript injected into the page
  src/main/ets/web           WebviewController wrapper
  src/test                   hypium tests
entry/                       sample app
```

## Sample app

`entry/` is a stage-model app that loads a local page with a made-up timetable into a `Web` component. Tapping **Read timetable** runs the generic adapter against that page and lists the courses. No account, no network, no particular school.

The page lives in `entry/src/main/resources/rawfile/mock_timetable.html` and includes a `rowspan` cell and a cell holding two courses, so the expansion and the line-break rule are both exercised.

```powershell
$env:DEVECO_SDK_HOME = "E:\DevEco Studio\sdk"
$env:PATH = "E:\DevEco Studio\jbr\bin;" + $env:PATH
& "E:\DevEco Studio\tools\ohpm\bin\ohpm.bat" install
& "E:\DevEco Studio\tools\hvigor\bin\hvigorw.bat" --no-daemon assembleHap --mode module -p product=default -p module=entry@default
```

The output is `entry/build/default/outputs/default/entry-default-unsigned.hap`.

To point the sample at a real site, change the `Web` source in `entry/src/main/ets/pages/Index.ets` to the school URL, let the user sign in, and call the import after `onPageEnd`.

### Build warnings

A build without a signing profile prints `No signingConfig found for product default`. That is expected. Add a signing profile in DevEco Studio if you want to install the HAP on a device.

hvigor may also print two notes about the local module: `Missing module info for local modules ...` and `The version number ... does not comply with the SemVer specification`. Both come from the ohpm package name not matching the module name. They do not change the output; `ets/modules.abc` in the HAP contains `GenericTableAdapter` and the injected scripts.

## Limitations

- An adapter matches one layout. When a vendor redesigns its pages, the adapter breaks. Expect to maintain it.
- Period times come from `PeriodTable`, not from the page. Schools with different bells need their own table.
- The generic table reader follows a `名称(1-2节)1-16周校区教室教师` order. Missing parts are left empty; a very unusual order may land a room name in the teacher field. Cells without any period marker fall back to the whole text as the course name, and only when the cell has a single line.
- Qiangzhi support reads `.kbcontent` cells and `font[title]` hints.
- Entss support calls two endpoints of that product (`getCalendarWeekDatas` and `getDatesOfWeek`) with the semester code it finds in the page. A school that renamed those paths, or that hides the semester field, returns `request_failed` or `no_semester`.
- Other vendors are not implemented.

## Tests

Tests live in `library/src/test` and use `@ohos/hypium`, with written-out payloads and no network access. Run them from the sample project, or from any stage-model project that references the module.

## License

Apache-2.0. See [LICENSE](LICENSE).
