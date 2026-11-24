#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FinanceIncomeEntry {
    pub id: String,
    pub project: Option<String>,
    pub description: Option<String>,
    pub gross_minor: Option<i64>,
    pub tax_minor: Option<i64>,
    pub net_minor: Option<i64>,
    pub tax_rate: Option<String>,
    pub recorded_date: Option<String>,
    pub year: Option<String>,
    pub month: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FinanceIncomeReport {
    pub entries: Vec<FinanceIncomeEntry>,
    pub total: u32,
    pub fetched_at: String,
}
