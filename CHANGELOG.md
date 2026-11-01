# Changelog

## 0.1.0 - 2026-11-02

First release.

- Two adapters behind one interface: `generic-table` and `qiangzhi`
- Injected scripts that return plain JSON, so parsing can be tested off-device
- Week text handling: `1-16周`, `1-8,10-12周`, `1-15周(单)`, `第3-5周`
- Period to time mapping through a replaceable `PeriodTable`
- Semester label extraction and a first-Monday estimate
- Warning codes instead of exceptions: `invalid_json`, `no_schedule_page`,
  `no_weekday_header`, `no_courses`, `missing_weeks`
