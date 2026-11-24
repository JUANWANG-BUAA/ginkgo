//! API.md §6I portal personal metrics (`it.buaa.edu.cn`) & campus network traffic
//! HTML table decoder (`zfw.buaa.edu.cn/home`). Pure Rust, zero external HTML deps.
use crate::{codecs::finance::parse_decimal_minor, AppError, ErrorCode};
use ginkgo_domain::features::network_account::{NetworkTrafficProduct, PortalMetricValue};
use serde_json::Value;
use std::collections::BTreeMap;

pub const KEY_NET_FEE: &str = "net.netFee";
pub const KEY_BOOK_NUM: &str = "book.bookNum";
pub const KEY_MAIL_UNREAD: &str = "mail.unread";
pub const KEY_CLOUD_DRIVE: &str = "wangPan.wangPan";

pub const TARGET_PORTAL_KEYS: [&str; 4] =
    [KEY_NET_FEE, KEY_BOOK_NUM, KEY_MAIL_UNREAD, KEY_CLOUD_DRIVE];

fn portal_envelope(value: &Value) -> Result<&Value, AppError> {
    let code = value
        .get("e")
        .and_then(|c| c.as_i64().or_else(|| c.as_str()?.trim().parse().ok()))
        .ok_or_else(AppError::changed)?;
    match code {
        0 => value
            .get("d")
            .filter(|d| d.is_object())
            .ok_or_else(AppError::changed),
        10013 => Err(AppError::with_detail(
            ErrorCode::ModuleAuthRequired,
            "portal_login_required",
        )),
        401 | 403 => Err(AppError::module_auth_required()),
        _ => Err(AppError::new(ErrorCode::BusinessRejected)),
    }
}

pub fn parse_portal_info(value: &Value) -> Result<(), AppError> {
    let d = portal_envelope(value)?;
    if !d.get("info").is_some_and(Value::is_object) {
        return Err(AppError::changed());
    }
    Ok(())
}

pub fn parse_portal_items(
    value: &Value,
) -> Result<BTreeMap<String, Result<String, AppError>>, AppError> {
    let d = portal_envelope(value)?;
    let rows = d
        .get("data")
        .and_then(Value::as_array)
        .ok_or_else(AppError::changed)?;
    let mut seen: BTreeMap<String, usize> = BTreeMap::new();
    let mut ids: BTreeMap<String, Result<String, AppError>> = BTreeMap::new();

    for row in rows {
        let Some(obj) = row.as_object() else {
            return Err(AppError::changed());
        };
        let key_opt = obj
            .get("key")
            .or_else(|| obj.get("mark"))
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|s| !s.is_empty());
        let Some(key) = key_opt else {
            continue;
        };
        if !TARGET_PORTAL_KEYS.contains(&key) {
            continue;
        }
        let count = seen.entry(key.to_owned()).or_insert(0);
        *count += 1;
        if *count > 1 {
            ids.insert(key.to_owned(), Err(AppError::changed()));
            continue;
        }
        let id_res = match obj.get("id") {
            Some(Value::String(s)) if !s.trim().is_empty() => Ok(s.trim().to_owned()),
            Some(Value::Number(n)) => Ok(n.to_string()),
            _ => Err(AppError::changed()),
        };
        ids.insert(key.to_owned(), id_res);
    }

    for target in TARGET_PORTAL_KEYS {
        ids.entry(target.to_owned())
            .or_insert_with(|| Err(AppError::changed()));
    }
    Ok(ids)
}

pub fn parse_portal_detail(value: &Value) -> Result<PortalMetricValue, AppError> {
    let d = portal_envelope(value)?;
    let data = d
        .get("data")
        .filter(|v| v.is_object())
        .ok_or_else(AppError::changed)?;
    let raw_val = match data.get("value") {
        Some(Value::String(s)) if !s.trim().is_empty() => s.trim().to_owned(),
        Some(Value::Number(n)) => n.to_string(),
        _ => return Err(AppError::changed()),
    };
    if raw_val.starts_with('-') {
        return Err(AppError::changed());
    }
    let unit = match data.get("unit") {
        None | Some(Value::Null) => None,
        Some(Value::String(s)) => {
            let trimmed = s.trim();
            (!trimmed.is_empty()).then(|| trimmed.to_owned())
        }
        Some(_) => return Err(AppError::changed()),
    };
    Ok(PortalMetricValue {
        value: raw_val,
        unit,
    })
}

pub fn parse_net_fee_minor(metric: &PortalMetricValue) -> Result<i64, AppError> {
    let minor = parse_decimal_minor(&metric.value)?;
    if minor < 0 {
        return Err(AppError::changed());
    }
    Ok(minor)
}

pub fn parse_non_negative_count(metric: &PortalMetricValue) -> Result<u64, AppError> {
    metric
        .value
        .trim()
        .parse::<u64>()
        .map_err(|_| AppError::changed())
}

#[derive(Debug, Clone)]
struct ParsedCell {
    is_th: bool,
    col_seq: Option<String>,
    text: String,
    buttons: Vec<String>,
    nested_tables: Vec<ParsedTable>,
}

#[derive(Debug, Clone)]
struct ParsedRow {
    in_thead: bool,
    cells: Vec<ParsedCell>,
}

#[derive(Debug, Clone)]
struct ParsedTable {
    rows: Vec<ParsedRow>,
}

struct TableBuilder {
    in_thead: bool,
    rows: Vec<ParsedRow>,
    current_row: Option<ParsedRow>,
    current_cell: Option<ParsedCell>,
    current_button: Option<String>,
}

impl TableBuilder {
    fn new() -> Self {
        Self {
            in_thead: false,
            rows: Vec::new(),
            current_row: None,
            current_cell: None,
            current_button: None,
        }
    }

    fn finish_button(&mut self) {
        if let Some(btn_raw) = self.current_button.take() {
            let normalized = collapse_ws(&decode_entities(&btn_raw));
            if !normalized.is_empty() {
                if let Some(cell) = self.current_cell.as_mut() {
                    cell.buttons.push(normalized);
                }
            }
        }
    }

    fn finish_cell(&mut self) {
        self.finish_button();
        if let Some(mut cell) = self.current_cell.take() {
            cell.text = collapse_ws(&decode_entities(&cell.text));
            if let Some(row) = self.current_row.as_mut() {
                row.cells.push(cell);
            }
        }
    }

    fn finish_row(&mut self) {
        self.finish_cell();
        if let Some(row) = self.current_row.take() {
            if !row.cells.is_empty() {
                self.rows.push(row);
            }
        }
    }

    fn finish(mut self) -> ParsedTable {
        self.finish_row();
        ParsedTable { rows: self.rows }
    }
}

pub fn parse_traffic_html(html: &str) -> Result<Vec<NetworkTrafficProduct>, AppError> {
    let cleaned = strip_ignored_blocks(html);
    let root_tables = parse_tables(&cleaned);
    let mut all_tables = Vec::new();
    for table in &root_tables {
        collect_tables(table, &mut all_tables);
    }

    let mut matched_tables = Vec::new();
    for table in all_tables {
        let headers = direct_headers(table)?;
        if headers.contains_key("已用流量")
            && headers.contains_key("免费流量剩余(不含套餐)")
            && headers.contains_key("计费流量剩余(不含套餐)")
        {
            matched_tables.push((table, headers));
        }
    }
    if matched_tables.len() != 1 {
        return Err(AppError::changed());
    }
    let (traffic_table, headers) = &matched_tables[0];
    let used_seq = &headers["已用流量"];
    let free_seq = &headers["免费流量剩余(不含套餐)"];
    let paid_seq = &headers["计费流量剩余(不含套餐)"];
    let name_seq = headers
        .get("产品名称")
        .or_else(|| headers.get("产品"))
        .or_else(|| headers.get("套餐/产品"));

    let mut products = Vec::new();
    for row in &traffic_table.rows {
        if row.in_thead || row.cells.iter().all(|c| c.is_th) {
            continue;
        }
        if !row.cells.iter().any(|c| !c.is_th && c.col_seq.is_some()) {
            continue;
        }

        let used_cell = find_unique_td(&row.cells, used_seq)?;
        let free_cell = find_unique_td(&row.cells, free_seq)?;
        let paid_cell = find_unique_td(&row.cells, paid_seq)?;

        let _used_qty = parse_traffic_quantity(&used_cell.text)?;
        let base_free_qty = parse_traffic_quantity(&free_cell.text)?;
        let _paid_qty = parse_traffic_quantity(&paid_cell.text)?;

        let product_name = name_seq
            .and_then(|seq| find_unique_td(&row.cells, seq).ok())
            .map(|c| c.text.trim().to_owned())
            .filter(|s| !s.is_empty());

        let mut pkg_quantities = Vec::new();
        for cell in &row.cells {
            for nested in &cell.nested_tables {
                extract_package_available_quantities(nested, &mut pkg_quantities)?;
            }
        }

        let package_count = u32::try_from(pkg_quantities.len()).map_err(|_| AppError::changed())?;
        let free_remaining_text = if pkg_quantities.is_empty() {
            free_cell.text.trim().to_owned()
        } else {
            let mut all = Vec::with_capacity(1 + pkg_quantities.len());
            all.push(base_free_qty);
            all.extend(pkg_quantities);
            sum_and_format_quantities(&all)?
        };

        products.push(NetworkTrafficProduct {
            product_name,
            used_text: used_cell.text.trim().to_owned(),
            free_remaining_text,
            paid_remaining_text: paid_cell.text.trim().to_owned(),
            package_count,
        });
    }

    Ok(products)
}

fn collect_tables<'a>(table: &'a ParsedTable, out: &mut Vec<&'a ParsedTable>) {
    out.push(table);
    for row in &table.rows {
        for cell in &row.cells {
            for nested in &cell.nested_tables {
                collect_tables(nested, out);
            }
        }
    }
}

fn normalize_label(raw: &str) -> String {
    raw.split_whitespace()
        .collect::<String>()
        .replace('（', "(")
        .replace('）', ")")
}

fn direct_headers(table: &ParsedTable) -> Result<BTreeMap<String, String>, AppError> {
    let mut map = BTreeMap::new();
    let mut seen_seqs = std::collections::HashSet::new();
    for row in &table.rows {
        for cell in &row.cells {
            if !cell.is_th {
                continue;
            }
            if let Some(seq) = &cell.col_seq {
                let normalized = normalize_label(&cell.text);
                let label = normalized.as_str();
                if label.is_empty() {
                    continue;
                }
                if matches!(
                    label,
                    "已用流量"
                        | "免费流量剩余(不含套餐)"
                        | "计费流量剩余(不含套餐)"
                        | "套餐名称"
                        | "统计"
                ) && (map.contains_key(label) || !seen_seqs.insert(seq.clone()))
                {
                    return Err(AppError::changed());
                }
                map.entry(normalized).or_insert_with(|| seq.clone());
            }
        }
    }
    Ok(map)
}

fn find_unique_td<'a>(cells: &'a [ParsedCell], col_seq: &str) -> Result<&'a ParsedCell, AppError> {
    let matches: Vec<&ParsedCell> = cells
        .iter()
        .filter(|c| !c.is_th && c.col_seq.as_deref() == Some(col_seq))
        .collect();
    if matches.len() != 1 {
        return Err(AppError::changed());
    }
    Ok(matches[0])
}

fn extract_package_available_quantities(
    table: &ParsedTable,
    out: &mut Vec<TrafficQuantity>,
) -> Result<(), AppError> {
    let headers = direct_headers(table)?;
    if headers.contains_key("套餐名称") && headers.contains_key("统计") {
        let stat_seq = &headers["统计"];
        for row in &table.rows {
            if row.in_thead || row.cells.iter().all(|c| c.is_th) {
                continue;
            }
            if !row.cells.iter().any(|c| !c.is_th && c.col_seq.is_some()) {
                continue;
            }
            let stat_cell = find_unique_td(&row.cells, stat_seq)?;
            for btn in &stat_cell.buttons {
                let compact = normalize_label(btn);
                if let Some(rest) = compact
                    .strip_prefix("可用流量：")
                    .or_else(|| compact.strip_prefix("可用流量:"))
                {
                    out.push(parse_traffic_quantity(rest)?);
                }
            }
        }
    }
    for row in &table.rows {
        for cell in &row.cells {
            for nested in &cell.nested_tables {
                extract_package_available_quantities(nested, out)?;
            }
        }
    }
    Ok(())
}

#[derive(Debug, Clone, Copy)]
struct TrafficQuantity {
    micro_bytes: u128,
    unit_rank: u32,
}

fn parse_traffic_quantity(raw: &str) -> Result<TrafficQuantity, AppError> {
    let trimmed = raw.split_whitespace().collect::<String>().replace(',', "");
    if trimmed.is_empty() || trimmed.starts_with('-') {
        return Err(AppError::changed());
    }
    let Some(split_idx) = trimmed.find(|c: char| !c.is_ascii_digit() && c != '.') else {
        let (w, f) = trimmed.split_once('.').unwrap_or((trimmed.as_str(), ""));
        if !w.is_empty()
            && f.len() <= 6
            && w.bytes().all(|b| b == b'0')
            && f.bytes().all(|b| b == b'0')
        {
            return Ok(TrafficQuantity {
                micro_bytes: 0,
                unit_rank: 0,
            });
        }
        return Err(AppError::changed());
    };
    let (num_part, unit_part) = trimmed.split_at(split_idx);
    let num_part = num_part.trim();
    let unit_part = unit_part.trim();
    if num_part.is_empty() || unit_part.is_empty() {
        return Err(AppError::changed());
    }
    let unit_rank = match unit_part.to_ascii_lowercase().as_str() {
        "byte" | "bytes" | "b" => 0,
        "k" | "kb" | "kib" => 1,
        "m" | "mb" | "mib" => 2,
        "g" | "gb" | "gib" => 3,
        "t" | "tb" | "tib" => 4,
        _ => return Err(AppError::changed()),
    };
    let (whole_str, frac_str) = num_part.split_once('.').unwrap_or((num_part, ""));
    if whole_str.is_empty()
        || frac_str.len() > 6
        || !whole_str.bytes().all(|b| b.is_ascii_digit())
        || !frac_str.bytes().all(|b| b.is_ascii_digit())
    {
        return Err(AppError::changed());
    }
    let whole: u128 = whole_str.parse().map_err(|_| AppError::changed())?;
    let mut padded_frac = frac_str.to_owned();
    while padded_frac.len() < 6 {
        padded_frac.push('0');
    }
    let frac: u128 = padded_frac.parse().map_err(|_| AppError::changed())?;
    let micro_units = whole
        .checked_mul(1_000_000)
        .and_then(|v| v.checked_add(frac))
        .ok_or_else(AppError::changed)?;
    let factor = 1024_u128.pow(unit_rank);
    let micro_bytes = micro_units
        .checked_mul(factor)
        .ok_or_else(AppError::changed)?;
    Ok(TrafficQuantity {
        micro_bytes,
        unit_rank,
    })
}

fn sum_and_format_quantities(items: &[TrafficQuantity]) -> Result<String, AppError> {
    let max_rank = items
        .iter()
        .map(|q| q.unit_rank)
        .max()
        .ok_or_else(AppError::changed)?;
    let mut total_micro_bytes: u128 = 0;
    for item in items {
        total_micro_bytes = total_micro_bytes
            .checked_add(item.micro_bytes)
            .ok_or_else(AppError::changed)?;
    }
    let divisor = 1024_u128.pow(max_rank);
    let rounded_micro = total_micro_bytes
        .checked_add(divisor / 2)
        .ok_or_else(AppError::changed)?
        / divisor;
    let whole = rounded_micro / 1_000_000;
    let frac = rounded_micro % 1_000_000;
    let suffix = match max_rank {
        0 => "byte",
        1 => "K",
        2 => "M",
        3 => "G",
        4 => "T",
        _ => return Err(AppError::changed()),
    };
    if frac == 0 {
        Ok(format!("{whole}{suffix}"))
    } else {
        let frac_text = format!("{frac:06}");
        let trimmed = frac_text.trim_end_matches('0');
        Ok(format!("{whole}.{trimmed}{suffix}"))
    }
}

fn strip_ignored_blocks(html: &str) -> String {
    let mut out = String::with_capacity(html.len());
    let mut i = 0;
    while let Some(tail) = html.get(i..) {
        if tail.is_empty() {
            break;
        }
        if let Some(after_open) = tail.strip_prefix("<!--") {
            if let Some(end) = after_open.find("-->") {
                i += 4 + end + 3;
                continue;
            }
            break;
        }
        if let Some(skip_to) = skip_raw_tag(tail, "script").or_else(|| skip_raw_tag(tail, "style"))
        {
            i += skip_to;
            continue;
        }
        let Some(ch) = tail.chars().next() else {
            break;
        };
        out.push(ch);
        i += ch.len_utf8();
    }
    out
}

fn skip_raw_tag(slice: &str, tag: &str) -> Option<usize> {
    let bytes = slice.as_bytes();
    if bytes.first().copied() != Some(b'<') {
        return None;
    }
    let rest = bytes.get(1..)?;
    let tag_bytes = tag.as_bytes();
    if rest.len() < tag_bytes.len() || !rest[..tag_bytes.len()].eq_ignore_ascii_case(tag_bytes) {
        return None;
    }
    let after = rest.get(tag_bytes.len()).copied()?;
    if !matches!(after, b'>' | b' ' | b'\t' | b'\r' | b'\n' | b'/') {
        return None;
    }
    let close_len = 2 + tag_bytes.len();
    let mut search_from = 1 + tag_bytes.len();
    while search_from + close_len <= bytes.len() {
        if bytes[search_from] == b'<'
            && bytes[search_from + 1] == b'/'
            && bytes[search_from + 2..search_from + close_len].eq_ignore_ascii_case(tag_bytes)
        {
            let after_close = bytes.get(search_from + close_len).copied();
            if matches!(
                after_close,
                Some(b'>' | b' ' | b'\t' | b'\r' | b'\n' | b'/')
            ) {
                if let Some(gt_rel) = bytes[search_from + close_len..]
                    .iter()
                    .position(|&b| b == b'>')
                {
                    return Some(search_from + close_len + gt_rel + 1);
                }
            }
        }
        search_from += 1;
    }
    Some(bytes.len())
}

fn starts_like_html_tag(tag_slice: &str) -> bool {
    let bytes = tag_slice.as_bytes();
    if bytes.first().copied() != Some(b'<') {
        return false;
    }
    match bytes.get(1).copied() {
        Some(b'a'..=b'z' | b'A'..=b'Z' | b'!' | b'?') => true,
        Some(b'/') => matches!(bytes.get(2).copied(), Some(b'a'..=b'z' | b'A'..=b'Z')),
        _ => false,
    }
}

fn parse_tables(html: &str) -> Vec<ParsedTable> {
    let mut root_tables = Vec::new();
    let mut stack: Vec<TableBuilder> = Vec::new();
    let mut pos = 0;

    while let Some(rem) = html.get(pos..) {
        if rem.is_empty() {
            break;
        }
        let Some(lt_rel) = rem.find('<') else {
            if let Some(top) = stack.last_mut() {
                append_text(top, rem);
            }
            break;
        };
        if lt_rel > 0 {
            if let Some(text_part) = rem.get(..lt_rel) {
                if let Some(top) = stack.last_mut() {
                    append_text(top, text_part);
                }
            }
        }
        let tag_start = pos + lt_rel;
        let Some(tag_slice) = html.get(tag_start..) else {
            break;
        };
        if !starts_like_html_tag(tag_slice) {
            if let Some(top) = stack.last_mut() {
                append_text(top, "<");
            }
            pos = tag_start + 1;
            continue;
        }
        let Some(gt_rel) = find_tag_end(tag_slice) else {
            break;
        };
        let Some(raw_tag) = tag_slice.get(1..gt_rel) else {
            pos = tag_start + 1;
            continue;
        };
        pos = tag_start + gt_rel + 1;

        let trimmed = raw_tag.trim();
        let (is_close, body) = match trimmed.strip_prefix('/') {
            Some(rest) => (true, rest.trim_start()),
            None => (false, trimmed),
        };
        let name_end = body
            .find(|c: char| c.is_ascii_whitespace() || c == '/')
            .unwrap_or(body.len());
        let Some(name_slice) = body.get(..name_end) else {
            continue;
        };
        let tag_name = name_slice.to_ascii_lowercase();
        let attrs = body.get(name_end..).unwrap_or("");

        match (is_close, tag_name.as_str()) {
            (false, "table") => {
                if stack.len() < 16 {
                    stack.push(TableBuilder::new());
                }
            }
            (true, "table") => {
                if let Some(builder) = stack.pop() {
                    let finished = builder.finish();
                    if let Some(parent) = stack.last_mut() {
                        if let Some(cell) = parent.current_cell.as_mut() {
                            cell.nested_tables.push(finished);
                        }
                    } else {
                        root_tables.push(finished);
                    }
                }
            }
            (false, "thead") => {
                if let Some(top) = stack.last_mut() {
                    top.in_thead = true;
                }
            }
            (true, "thead") => {
                if let Some(top) = stack.last_mut() {
                    top.finish_row();
                    top.in_thead = false;
                }
            }
            (false, "tbody") | (true, "tbody") => {
                if let Some(top) = stack.last_mut() {
                    top.finish_row();
                }
            }
            (false, "tr") => {
                if let Some(top) = stack.last_mut() {
                    top.finish_row();
                    top.current_row = Some(ParsedRow {
                        in_thead: top.in_thead,
                        cells: Vec::new(),
                    });
                }
            }
            (true, "tr") => {
                if let Some(top) = stack.last_mut() {
                    top.finish_row();
                }
            }
            (false, "th" | "td") => {
                if let Some(top) = stack.last_mut() {
                    if top.current_row.is_none() {
                        top.current_row = Some(ParsedRow {
                            in_thead: top.in_thead,
                            cells: Vec::new(),
                        });
                    }
                    top.finish_cell();
                    top.current_cell = Some(ParsedCell {
                        is_th: tag_name == "th",
                        col_seq: extract_attr(attrs, "data-col-seq"),
                        text: String::new(),
                        buttons: Vec::new(),
                        nested_tables: Vec::new(),
                    });
                }
            }
            (true, "th" | "td") => {
                if let Some(top) = stack.last_mut() {
                    top.finish_cell();
                }
            }
            (false, "button") => {
                if let Some(top) = stack.last_mut() {
                    if top.current_cell.is_some() {
                        top.finish_button();
                        top.current_button = Some(String::new());
                    }
                }
            }
            (true, "button") => {
                if let Some(top) = stack.last_mut() {
                    top.finish_button();
                }
            }
            _ => {}
        }
    }
    root_tables
}

fn append_text(top: &mut TableBuilder, slice: &str) {
    if let Some(btn) = top.current_button.as_mut() {
        btn.push_str(slice);
    }
    if let Some(cell) = top.current_cell.as_mut() {
        cell.text.push_str(slice);
    }
}

fn find_tag_end(slice: &str) -> Option<usize> {
    let mut quote: Option<u8> = None;
    for (idx, b) in slice.bytes().enumerate().skip(1) {
        match (quote, b) {
            (Some(q), ch) if ch == q => quote = None,
            (None, b'"' | b'\'') => quote = Some(b),
            (None, b'>') => return Some(idx),
            _ => {}
        }
    }
    None
}

fn extract_attr(attrs: &str, target: &str) -> Option<String> {
    let bytes = attrs.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        while i < bytes.len() && bytes[i].is_ascii_whitespace() {
            i += 1;
        }
        if i >= bytes.len() || bytes[i] == b'/' {
            break;
        }
        let name_start = i;
        while i < bytes.len()
            && !bytes[i].is_ascii_whitespace()
            && bytes[i] != b'='
            && bytes[i] != b'/'
        {
            i += 1;
        }
        let Some(name) = attrs.get(name_start..i) else {
            break;
        };
        while i < bytes.len() && bytes[i].is_ascii_whitespace() {
            i += 1;
        }
        let val = if i < bytes.len() && bytes[i] == b'=' {
            i += 1;
            while i < bytes.len() && bytes[i].is_ascii_whitespace() {
                i += 1;
            }
            if i < bytes.len() && (bytes[i] == b'"' || bytes[i] == b'\'') {
                let q = bytes[i];
                i += 1;
                let v_start = i;
                while i < bytes.len() && bytes[i] != q {
                    i += 1;
                }
                let out = attrs.get(v_start..i);
                if i < bytes.len() {
                    i += 1;
                }
                out
            } else {
                let v_start = i;
                while i < bytes.len() && !bytes[i].is_ascii_whitespace() {
                    i += 1;
                }
                attrs.get(v_start..i)
            }
        } else {
            None
        };
        if name.eq_ignore_ascii_case(target) {
            return val.map(|v| decode_entities(v).trim().to_owned());
        }
    }
    None
}

fn decode_entities(raw: &str) -> String {
    raw.replace("&nbsp;", " ")
        .replace("&#160;", " ")
        .replace("&amp;", "&")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&#39;", "'")
}

fn collapse_ws(raw: &str) -> String {
    let mut out = String::new();
    for part in raw.split_whitespace() {
        if !out.is_empty() {
            out.push(' ');
        }
        out.push_str(part);
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parses_portal_items_and_details_with_isolated_faults() {
        let items = json!({
            "e": 0,
            "m": "ok",
            "d": {
                "data": [
                    {"key": "net.netFee", "id": 101},
                    {"key": "book.bookNum", "id": "202"},
                    {"key": "mail.unread", "id": "303"},
                    {"key": "mail.unread", "id": "999"},
                    {"key": "wangPan.wangPan", "id": "404"}
                ]
            }
        });
        let map = parse_portal_items(&items).expect("envelope ok");
        assert_eq!(map[KEY_NET_FEE].as_deref().ok(), Some("101"));
        assert_eq!(map[KEY_BOOK_NUM].as_deref().ok(), Some("202"));
        assert!(
            map[KEY_MAIL_UNREAD].is_err(),
            "duplicate key must fail only that metric"
        );
        assert_eq!(map[KEY_CLOUD_DRIVE].as_deref().ok(), Some("404"));

        let fee =
            parse_portal_detail(&json!({"e": 0, "d": {"data": {"value": "36.50", "unit": "元"}}}))
                .expect("netFee detail");
        assert_eq!(parse_net_fee_minor(&fee).expect("minor"), 3650);

        let login_err = parse_portal_items(&json!({"e": 10013, "m": "not login"})).unwrap_err();
        assert_eq!(login_err.detail.as_deref(), Some("portal_login_required"));
    }

    #[test]
    fn parses_reordered_traffic_columns_and_isolates_nested_package_validity_column() {
        let html = r#"
        <html><body>
          <table class="summary-other"><thead><tr><th data-col-seq="1">无关表</th></tr></thead></table>
          <table class="kv-grid-table">
            <thead>
              <tr>
                <th data-col-seq="2">计费流量剩余(不含套餐)</th>
                <th data-col-seq="0">产品名称</th>
                <th data-col-seq="5">已用流量</th>
                <th data-col-seq="9">免费流量剩余(不含套餐)</th>
                <th data-col-seq="13">套餐详情</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td data-col-seq="2">0M</td>
                <td data-col-seq="0">学生校园网</td>
                <td data-col-seq="5">18.25G</td>
                <td data-col-seq="9">10.5G</td>
                <td data-col-seq="13">
                  <table class="nested-pkg">
                    <thead>
                      <tr>
                        <th data-col-seq="1">套餐名称</th>
                        <th data-col-seq="2">统计</th>
                        <th data-col-seq="3">有效期</th>
                      </tr>
                    </thead>
                    <tbody>
                      <tr>
                        <td data-col-seq="1">学期赠送包</td>
                        <td data-col-seq="2">
                          <button type="button">总流量：20G</button>
                          <button type="button">可用流量：512M</button>
                        </td>
                        <td data-col-seq="3">0天</td>
                      </tr>
                    </tbody>
                  </table>
                </td>
              </tr>
              <tr>
                <td data-col-seq="2">5.00G</td>
                <td data-col-seq="0">家属区宽带</td>
                <td data-col-seq="5">120M</td>
                <td data-col-seq="9">20.00G</td>
                <td data-col-seq="13">--</td>
              </tr>
            </tbody>
          </table>
        </body></html>
        "#;

        let products = parse_traffic_html(html).expect("valid traffic html");
        assert_eq!(products.len(), 2);
        assert_eq!(products[0].product_name.as_deref(), Some("学生校园网"));
        assert_eq!(products[0].used_text, "18.25G");
        assert_eq!(products[0].free_remaining_text, "11G");
        assert_eq!(products[0].paid_remaining_text, "0M");
        assert_eq!(products[0].package_count, 1);

        // Without nested packages, original string & decimals stay untouched.
        assert_eq!(products[1].product_name.as_deref(), Some("家属区宽带"));
        assert_eq!(products[1].free_remaining_text, "20.00G");
        assert_eq!(products[1].paid_remaining_text, "5.00G");
        assert_eq!(products[1].package_count, 0);
    }

    #[test]
    fn rejects_missing_headers_or_malformed_traffic_values() {
        assert_eq!(
            parse_traffic_html("<html><body><form id='login'></form></body></html>")
                .unwrap_err()
                .code,
            ErrorCode::ChangedResponse
        );
        let bad_cell = r#"
        <table>
          <thead><tr>
            <th data-col-seq="1">已用流量</th>
            <th data-col-seq="2">免费流量剩余(不含套餐)</th>
            <th data-col-seq="3">计费流量剩余(不含套餐)</th>
          </tr></thead>
          <tbody><tr>
            <td data-col-seq="1">0天</td>
            <td data-col-seq="2">10G</td>
            <td data-col-seq="3">0G</td>
          </tr></tbody>
        </table>
        "#;
        assert_eq!(
            parse_traffic_html(bad_cell).unwrap_err().code,
            ErrorCode::ChangedResponse
        );
    }

    #[test]
    fn handles_utf8_after_angle_brackets_and_unitless_zero_without_panicking() {
        let html = r#"
        <html><body>
          <div>提示：<免费套餐说明> 与 <a title="<中文属性>">说明</a></div>
          <script>if (1 < 2) { var t = "<中文脚本>"; }</script>
          <table>
            <thead><tr>
              <th data-col-seq="0">产品名称</th>
              <th data-col-seq="1">已用流量</th>
              <th data-col-seq="2">免费流量剩余（不含套餐）</th>
              <th data-col-seq="3">计费流量剩余（不含套餐）</th>
            </tr></thead>
            <tbody><tr>
              <td data-col-seq="0">校园网<研究生></td>
              <td data-col-seq="1">12.5G</td>
              <td data-col-seq="2">17.5G</td>
              <td data-col-seq="3">0</td>
            </tr></tbody>
          </table>
        </body></html>
        "#;
        let products = parse_traffic_html(html).expect("utf-8 angle bracket html");
        assert_eq!(products.len(), 1);
        assert_eq!(products[0].product_name.as_deref(), Some("校园网<研究生>"));
        assert_eq!(products[0].used_text, "12.5G");
        assert_eq!(products[0].free_remaining_text, "17.5G");
        assert_eq!(products[0].paid_remaining_text, "0");
    }
}
