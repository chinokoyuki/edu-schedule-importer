# edu-schedule-importer

从 ArkWeb 已打开的页面里读出课表，转成结构化的课程数据。用 ArkTS 编写，面向 HarmonyOS。

用户在学校站点里正常登录，停在课表页，点一下按钮。注入脚本读取当前页面上的课表，适配器把它转换成课程、周次和节次。

[English](README.md)

## 边界

这个库读取的是用户自己打开、自己登录的页面。它不索取、不保存、不传输账号密码，也不绕过登录流程。请只对你有权访问的账号和系统使用。

仓库里不含任何学校清单。用哪个适配器由接入方决定，不由这个仓库替你决定。

## 功能

- 两个适配器：通用 HTML 表格、强智（Qiangzhi）版式
- 注入脚本只返回 JSON，解析部分可以不依赖设备直接测试
- 周次文本处理：`1-16周`、`1-8,10-12周`、`1-15周(单)`、`第3-5周`
- 节次到时间的映射，节次表可替换
- 学期标签提取与开学周一估算
- 除 ArkWeb 外没有运行时依赖

## 环境要求

Stage 模型，ArkTS，目标 SDK 6.1.1(24)。宿主工程的 `Web` 组件需要 `ohos.permission.INTERNET`。

## 安装

```json5
// entry/oh-package.json5
{
  "dependencies": {
    "@chinokoyuki/edu-schedule-importer": "file:../edu-schedule-importer/library"
  }
}
```

然后在工程根目录执行 `ohpm install`。

## 快速上手

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
    this.summary = `${result.courses.length} 门课，${result.term.label}`
  }

  build() {
    Column() {
      Web({ src: 'https://your-school.example/', controller: this.controller })
        .layoutWeight(1)
      Button('读取课表').onClick(() => {
        this.readTimetable()
      })
      Text(this.summary)
    }
  }
}
```

等用户进到课表页之后再调用。脚本读的是当前文档，调用太早通常只会拿到 `no_schedule_page`。

## API

| 符号 | 用途 |
| --- | --- |
| `EduImporters.byId(id)` | 按 id 取适配器，未知 id 返回 null。 |
| `EduImporters.ids()` | 当前版本内置的 id：`generic-table`、`qiangzhi`。 |
| `EduImporters.generic(periods?)` / `.qiangzhi(periods?)` | 直接构造适配器。 |
| `runInWebView(controller, script)` | 在页面里执行脚本。不会抛异常，见下文。 |
| `unwrapScriptResult(text)` | 去掉部分内核附加的那层 JSON 字符串包装。 |
| `adapter.parse(raw)` | 把脚本输出转成 `ImportResult`，不会抛异常。 |
| `parseWeeks(text)` / `compressWeeks(weeks)` | 周次文本与数组互转。 |
| `parseWeekday(text)` | `星期一` / `周一` / `Monday` 转 1-7，识别不到返回 0。 |
| `parsePeriodRange(text)` | `1-2节` 转 `{ start, end }`。 |
| `parseTermLabel(text)` / `inferTermStart(label)` | 学期标签与开学周一估算。 |
| `PeriodTable.standard()` | 八节课，08:00 到 17:45。 |

### 返回结构

```ts
interface ImportResult {
  adapterId: string
  courses: ImportedCourse[]
  term: TermInfo
  warnings: string[]
}
```

`ImportedCourse` 包含 `name`、`teacher`、`room`、`campus`、`weekday`（1-7）、`startPeriod`、`endPeriod`、`weeks`、`startTime`、`endTime`。`TermInfo` 包含 `label`、`startDate`、`totalWeeks`。

`warnings` 是固定编码：`invalid_json`、`no_schedule_page`、`no_weekday_header`、`no_courses`、`missing_weeks`、`script_failed`。

ArkWeb 拒绝执行脚本时（控制器已解绑、页面已销毁），`runInWebView` 返回 `{"error":"script_failed"}` 而不是抛异常；适配器会把它变成 `script_failed` 警告。所以整条链路不需要包一层 `try`。

## 数据格式

适配器只吃 JSON，所以容易测试，也容易替换。

`generic-table`

```json
{
  "url": "https://example.edu/timetable",
  "tables": [
    [["节次", "星期一", "星期二"], ["1-2", "高等数学(1-2节)1-16周", "", ""]]
  ]
}
```

每个表格是行数组，每行是单元格文本数组。`rowspan`、`colspan` 在脚本里已经展开。

一个格子里一门课一行。学校把两门课塞进同一格时，通常靠换行分隔而不是标点，所以换行就是边界：

```json
{
  "tables": [
    [["节次", "星期一", "星期二", "星期三"],
     ["7-8", "形势与政策(7-8节)9-12周教学楼101吴十\n学术讲座(7-8节)13-16周报告厅201郑一", "", ""]]
  ]
}
```

这一格会出两门课。整格当一串读的话，前一门的教师名会被吃进后一门的课程名里。

`qiangzhi`

```json
{
  "sem": "2026-2027-1",
  "cells": [
    { "d": 1, "n": "高等数学", "t": "王五", "w": "1-16周(1-2节)", "r": "教学楼203" }
  ]
}
```

## 新增适配器

1. 写一段返回 JSON 的脚本。DOM 操作留在页面里，ArkTS 侧没有 DOM。
2. 把 JSON 解析成 `ImportResult`，复用 `core/` 里的工具。
3. 在 `EduImporters` 里注册 id，并补一份录制数据的测试。

录制数据请用测试账号，录制后删掉姓名、教室和任何能指向个人的信息。能手工构造的就不必录制。

## 工程结构

```
library/                     库本体，也是 ohpm 发布的内容
  Index.ets                  对外导出
  src/main/ets/core          周次、节次、学期工具
  src/main/ets/adapters      适配器与注册表
  src/main/ets/scripts       注入页面的 JavaScript
  src/main/ets/web           WebviewController 封装
  src/test                   hypium 测试
entry/                       示例工程
```

## 示例工程

`entry/` 是一个 Stage 模型应用：把本地一个假课表页面塞进 `Web` 组件，点「读取课表」就用通用适配器读一遍并列出课程。不需要账号，不联网，也不对应任何具体学校。

页面在 `entry/src/main/resources/rawfile/mock_timetable.html`，里面特意放了 `rowspan` 单元格和一个装了两门课的单元格，合并展开和换行规则都能跑到。

```powershell
$env:DEVECO_SDK_HOME = "E:\DevEco Studio\sdk"
$env:PATH = "E:\DevEco Studio\jbr\bin;" + $env:PATH
& "E:\DevEco Studio\tools\ohpm\bin\ohpm.bat" install
& "E:\DevEco Studio\tools\hvigor\bin\hvigorw.bat" --no-daemon assembleHap --mode module -p product=default -p module=entry@default
```

产物在 `entry/build/default/outputs/default/entry-default-unsigned.hap`。

要接到真实站点，把 `entry/src/main/ets/pages/Index.ets` 里 `Web` 的地址换成学校地址，让用户自己登录，然后在 `onPageEnd` 之后调用导入。

### 构建时的警告

没配签名时会打印 `No signingConfig found for product default`，这是正常的。要在 DevEco Studio 里配一份签名才能装到设备上。

hvigor 还可能多打印两条本地模块的提示：`Missing module info for local modules ...` 和 `The version number ... does not comply with the SemVer specification`。原因是 ohpm 包名和模块名对不上。不影响产物，HAP 里的 `ets/modules.abc` 能找到 `GenericTableAdapter` 和两段注入脚本。

## 限制

- 一个适配器对应一种版式。厂商改版就会失效，需要持续维护。
- 时间来自 `PeriodTable`，不是页面。作息不同的学校要自己准备节次表。
- 通用表格适配器按 `名称(1-2节)1-16周校区教室教师` 的顺序读。缺的部分留空；顺序特别怪的，教室名可能落到教师字段里。整格没有节次标记时退化成「整格当课程名」，且只在这一格只有一行时生效。
- 强智适配器依赖 `.kbcontent` 与 `font[title]` 提示。其他厂商暂未实现。

## 测试

测试位于 `library/src/test`，使用 `@ohos/hypium`，全部基于手写数据，不访问网络。在示例工程里跑，或放进任何引用了本模块的 Stage 工程。

## 许可证

Apache-2.0，见 [LICENSE](LICENSE)。
