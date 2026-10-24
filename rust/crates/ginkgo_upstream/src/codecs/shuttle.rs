//! Official shuttle timetable projection (API §6C).
//!
//! The published page renders a handful of `<table>` blocks whose rows carry
//! `colspan` group headers. Only structure that is actually present is
//! projected: unknown cells stay empty and a table with no readable runs is
//! dropped instead of being invented.
use crate::AppError;
pub use ginkgo_domain::features::shuttle::*;
use regex::Regex;
use std::sync::OnceLock;

pub const SOURCE_URL: &str = "https://www.buaa.edu.cn/info/1065/1762.htm";
const MAX_TABLES: usize = 12;
const MAX_RUNS_PER_SIDE: usize = 200;

fn table_re() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| Regex::new(r"(?is)<table[^>]*>(.*?)</table>").expect("table re"))
}
fn row_re() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| Regex::new(r"(?is)<tr[^>]*>(.*?)</tr>").expect("row re"))
}
fn cell_re() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| Regex::new(r"(?is)<t[dh]([^>]*)>(.*?)</t[dh]>").expect("cell re"))
}
fn tag_re() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| Regex::new(r"(?is)<[^>]+>").expect("tag re"))
}
fn colspan_re() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| Regex::new(r#"(?i)colspan\s*=\s*"?(\d+)"#).expect("colspan re"))
}

fn text_of(fragment: &str) -> String {
    let stripped = tag_re().replace_all(fragment, " ");
    let decoded = stripped
        .replace("&nbsp;", " ")
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&#39;", "'");
    decoded.split_whitespace().collect::<Vec<_>>().join(" ")
}

struct Cell {
    text: String,
    span: usize,
}

fn cells_of(row: &str) -> Vec<Cell> {
    cell_re()
        .captures_iter(row)
        .map(|capture| {
            let attrs = capture.get(1).map(|m| m.as_str()).unwrap_or_default();
            let span = colspan_re()
                .captures(attrs)
                .and_then(|c| c.get(1))
                .and_then(|m| m.as_str().parse::<usize>().ok())
                .unwrap_or(1)
                .clamp(1, 8);
            Cell {
                text: text_of(capture.get(2).map(|m| m.as_str()).unwrap_or_default()),
                span,
            }
        })
        .collect()
}

fn is_header(text: &str) -> bool {
    matches!(text, "班次" | "运行时间" | "可乘人数" | "发车时间" | "序号")
}

fn looks_like_time(text: &str) -> bool {
    let bytes = text.as_bytes();
    bytes.len() >= 4
        && bytes.iter().filter(|b| **b == b':').count() == 1
        && text.split(':').all(|part| {
            !part.is_empty() && part.len() <= 2 && part.bytes().all(|b| b.is_ascii_digit())
        })
}

pub fn parse(html: &str) -> Result<ShuttleTimetable, AppError> {
    let mut tables = Vec::new();
    for table in table_re().captures_iter(html).take(MAX_TABLES) {
        let Some(body) = table.get(1) else { continue };
        let mut left = String::new();
        let mut right = String::new();
        let mut sections: Vec<ShuttleSection> = Vec::new();
        for row in row_re().captures_iter(body.as_str()) {
            let Some(cells) = row.get(1).map(|m| cells_of(m.as_str())) else {
                continue;
            };
            if cells.is_empty() {
                continue;
            }
            // Group header spanning the whole row (e.g. 星期一至星期五).
            if cells.len() == 1 && cells[0].span >= 4 {
                sections.push(ShuttleSection {
                    label: cells[0].text.clone(),
                    left: Vec::new(),
                    right: Vec::new(),
                });
                continue;
            }
            // First row names the two directions.
            if left.is_empty()
                && cells.len() == 2
                && cells[0].span >= 2
                && !is_header(&cells[0].text)
                && !looks_like_time(&cells[0].text)
            {
                left = cells[0].text.clone();
                right = cells[1].text.clone();
                continue;
            }
            let section = match sections.last_mut() {
                Some(section) => section,
                None => {
                    sections.push(ShuttleSection {
                        label: String::new(),
                        left: Vec::new(),
                        right: Vec::new(),
                    });
                    sections.last_mut().expect("just pushed")
                }
            };
            let texts: Vec<&str> = cells.iter().map(|cell| cell.text.as_str()).collect();
            let runs = match texts.len() {
                // index, time, capacity, index, time, capacity
                6 => (
                    ShuttleRun {
                        index: texts[0].to_string(),
                        time: texts[1].to_string(),
                        capacity: texts[2].to_string(),
                    },
                    ShuttleRun {
                        index: texts[3].to_string(),
                        time: texts[4].to_string(),
                        capacity: texts[5].to_string(),
                    },
                ),
                // index, time, index, time
                4 => (
                    ShuttleRun {
                        index: texts[0].to_string(),
                        time: texts[1].to_string(),
                        capacity: String::new(),
                    },
                    ShuttleRun {
                        index: texts[2].to_string(),
                        time: texts[3].to_string(),
                        capacity: String::new(),
                    },
                ),
                _ => continue,
            };
            if !looks_like_time(&runs.0.time) || !looks_like_time(&runs.1.time) {
                continue;
            }
            if section.left.len() >= MAX_RUNS_PER_SIDE || section.right.len() >= MAX_RUNS_PER_SIDE {
                continue;
            }
            section.left.push(runs.0);
            section.right.push(runs.1);
        }
        sections.retain(|section| !section.left.is_empty() || !section.right.is_empty());
        if left.is_empty() || right.is_empty() || sections.is_empty() {
            continue;
        }
        tables.push(ShuttleTable {
            left,
            right,
            sections,
        });
    }
    if tables.is_empty() {
        return Err(AppError::changed());
    }
    Ok(ShuttleTimetable {
        tables,
        source: SOURCE_URL.into(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    const PAGE: &str = r#"<html><body>
      <table><tbody>
        <tr><td colspan="3">学院路校区→沙河校区</td><td colspan="3">沙河校区→学院路校区</td></tr>
        <tr><td colspan="6">星期一至星期五</td></tr>
        <tr><td>班次</td><td>运行时间</td><td>可乘人数</td><td>班次</td><td>运行时间</td><td>可乘人数</td></tr>
        <tr><td>1</td><td>7:00</td><td>45</td><td>1</td><td>7:10</td><td>45</td></tr>
        <tr><td>2</td><td>8:00</td><td>45</td><td>2</td><td>8:10</td><td>45</td></tr>
        <tr><td colspan="6">双休日、节假日</td></tr>
        <tr><td>1</td><td>9:00</td><td>45</td><td>1</td><td>9:10</td><td>45</td></tr>
      </tbody></table>
      <table><tbody>
        <tr><td colspan="2">沙河校区→地铁沙河站</td><td colspan="2">地铁沙河站→沙河校区</td></tr>
        <tr><td colspan="4">星期一至星期五</td></tr>
        <tr><td>班次</td><td>发车时间</td><td>班次</td><td>发车时间</td></tr>
        <tr><td>1</td><td>7:30</td><td>1</td><td>7:35</td></tr>
      </tbody></table>
    </body></html>"#;

    #[test]
    fn projects_both_directions_with_dated_sections() {
        let timetable = parse(PAGE).expect("timetable");
        assert_eq!(timetable.tables.len(), 2);
        let first = &timetable.tables[0];
        assert_eq!(first.left, "学院路校区→沙河校区");
        assert_eq!(first.right, "沙河校区→学院路校区");
        assert_eq!(first.sections.len(), 2);
        assert_eq!(first.sections[0].label, "星期一至星期五");
        assert_eq!(first.sections[0].left.len(), 2);
        assert_eq!(first.sections[0].left[0].time, "7:00");
        assert_eq!(first.sections[0].left[0].capacity, "45");
        assert_eq!(first.sections[1].label, "双休日、节假日");
        assert_eq!(first.sections[1].left[0].time, "9:00");
        // The tram table has no capacity column and keeps it empty.
        let tram = &timetable.tables[1];
        assert_eq!(tram.left, "沙河校区→地铁沙河站");
        assert_eq!(tram.sections[0].right[0].time, "7:35");
        assert_eq!(tram.sections[0].right[0].capacity, "");
    }

    #[test]
    fn non_clock_text_is_not_projected_as_a_departure() {
        for time in ["", "待定", "7:xx", "7:30:00", "7：30"] {
            let page = format!(
                r#"<table>
                <tr><td colspan="2">合成去程</td><td colspan="2">合成返程</td></tr>
                <tr><td>1</td><td>{time}</td><td>1</td><td>{time}</td></tr>
                </table>"#
            );
            assert_eq!(
                parse(&page).unwrap_err().code,
                crate::ErrorCode::ChangedResponse
            );
        }
    }

    #[test]
    fn unreadable_rows_do_not_hide_a_separate_readable_direction_pair() {
        let page = r#"<table>
            <tr><td colspan="2">合成去程</td><td colspan="2">合成返程</td></tr>
            <tr><td colspan="4">合成工作日</td></tr>
            <tr><td>1</td><td>待定</td><td>1</td><td>待定</td></tr>
            <tr><td>2</td><td>7:30</td><td>2</td><td>7:35</td></tr>
            </table>"#;
        let timetable = parse(page).unwrap();
        let section = &timetable.tables[0].sections[0];
        assert_eq!(section.label, "合成工作日");
        assert_eq!(section.left.len(), 1);
        assert_eq!(section.right.len(), 1);
        assert_eq!(section.left[0].index, "2");
        assert_eq!(section.left[0].time, "7:30");
        assert_eq!(section.right[0].index, "2");
        assert_eq!(section.right[0].time, "7:35");
    }

    #[test]
    fn a_page_without_readable_runs_is_a_changed_response() {
        assert!(parse("<html><body>no tables</body></html>").is_err());
        assert!(parse("<table><tr><td>x</td></tr></table>").is_err());
    }
}
