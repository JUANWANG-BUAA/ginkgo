//! Pure execution-report view. Never aggregate category/group/course credits.
use super::Workspace;
use ginkgo_domain::{
    features::graduate::{AcademicData, CreditProgress, ReadRow, ReadSection},
    ports::GraduateSource,
    AppError,
};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GraduateCreditMap {
    pub summary: Option<GraduateCreditNode>,
    pub nodes: Vec<GraduateCreditNode>,
    pub notice: Option<String>,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GraduateCreditNode {
    /// Source ordinal, not an inferred category/group relationship.
    pub source_index: u32,
    pub title: String,
    pub progress: Option<GraduateCreditMetrics>,
    pub rows: Vec<ReadRow>,
}
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct GraduateCreditMetrics {
    pub state: GraduateCreditState,
    pub required: Option<f64>,
    pub earned: Option<f64>,
    pub pending: Option<f64>,
    /// Derived only from this node's official requirement and recognized credits.
    pub remaining: Option<f64>,
    pub ratio: Option<f64>,
}
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub enum GraduateCreditState {
    Unknown,
    NoMinimum,
    Incomplete,
    RequirementMet,
}
fn valid(value: Option<f64>) -> Option<f64> {
    value.filter(|value| value.is_finite() && *value >= 0.0)
}
fn metrics(value: &CreditProgress) -> GraduateCreditMetrics {
    let required = valid(value.required);
    let earned = valid(value.earned);
    GraduateCreditMetrics {
        state: match (required, earned) {
            (Some(0.0), _) => GraduateCreditState::NoMinimum,
            (Some(r), Some(e)) if e >= r => GraduateCreditState::RequirementMet,
            (Some(_), Some(_)) => GraduateCreditState::Incomplete,
            _ => GraduateCreditState::Unknown,
        },
        required,
        earned,
        pending: valid(value.pending),
        remaining: required.zip(earned).map(|(r, e)| (r - e).max(0.0)),
        ratio: required
            .zip(earned)
            .filter(|(r, _)| *r > 0.0)
            .map(|(r, e)| (e / r).clamp(0.0, 1.0)),
    }
}
fn node(index: usize, section: &ReadSection) -> GraduateCreditNode {
    GraduateCreditNode {
        source_index: index as u32,
        title: section.title.clone(),
        progress: section.progress.as_ref().map(metrics),
        rows: section.rows.clone(),
    }
}
pub fn project_graduate_credit_map(data: &AcademicData) -> GraduateCreditMap {
    // This title is authored by the existing business projection, not read from
    // raw school JSON. Fallback plan/pool sections must not masquerade as totals.
    let has_summary = data
        .sections
        .first()
        .is_some_and(|section| section.title == "培养方案执行报告");
    GraduateCreditMap {
        summary: has_summary.then(|| node(0, &data.sections[0])),
        nodes: data
            .sections
            .iter()
            .enumerate()
            .skip(usize::from(has_summary))
            .map(|(index, section)| node(index, section))
            .collect(),
        notice: data.notice.clone(),
    }
}
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct GraduateCreditMapOutcome {
    pub data: GraduateCreditMap,
    pub failure: Option<AppError>,
}
impl<U: GraduateSource> Workspace<U> {
    pub async fn load_graduate_credit_map(
        &self,
        force: bool,
    ) -> Result<GraduateCreditMapOutcome, AppError> {
        let report = self.upstream.load_graduate_execution(force).await?;
        Ok(GraduateCreditMapOutcome {
            data: project_graduate_credit_map(&report.data),
            failure: report.failure,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use ginkgo_domain::{
        ports::{DataOutcome, GraduateOutcome, GraduatePart},
        ErrorCode,
    };
    struct ReportOnly;
    impl GraduateSource for ReportOnly {
        async fn load_graduate(&self, _: bool) -> Result<GraduateOutcome, AppError> {
            panic!("map must not activate status or a combined read")
        }
        async fn load_graduate_part(
            &self,
            part: GraduatePart,
            force: bool,
        ) -> Result<GraduateOutcome, AppError> {
            assert!(matches!(part, GraduatePart::Report));
            assert!(force);
            Ok(DataOutcome {
                data: AcademicData {
                    sections: vec![],
                    notice: Some("保留快照".into()),
                },
                failure: Some(AppError::new(ErrorCode::ChangedResponse)),
            })
        }
    }
    #[tokio::test]
    async fn graduate_credit_map_preserves_read_failure_and_never_reads_status() {
        let result = Workspace::new(ReportOnly)
            .load_graduate_credit_map(true)
            .await
            .unwrap();
        assert_eq!(result.failure.unwrap().code, ErrorCode::ChangedResponse);
        assert_eq!(result.data.notice.as_deref(), Some("保留快照"));
        assert!(result.data.summary.is_none());
    }
    struct StrictOnly;
    impl GraduateSource for StrictOnly {
        async fn load_graduate(&self, _: bool) -> Result<GraduateOutcome, AppError> {
            panic!("no combined read")
        }
        async fn load_graduate_part(
            &self,
            _: GraduatePart,
            _: bool,
        ) -> Result<GraduateOutcome, AppError> {
            panic!("must not use pool fallback")
        }
        async fn load_graduate_execution(&self, force: bool) -> Result<GraduateOutcome, AppError> {
            assert!(force);
            Err(AppError::new(ErrorCode::ChangedResponse))
        }
    }
    #[tokio::test]
    async fn graduate_credit_map_routes_through_strict_execution_override() {
        let result = Workspace::new(StrictOnly)
            .load_graduate_credit_map(true)
            .await
            .unwrap_err();
        assert_eq!(result.code, ErrorCode::ChangedResponse);
    }
    fn section(
        title: &str,
        required: Option<f64>,
        earned: Option<f64>,
        pending: Option<f64>,
    ) -> ReadSection {
        ReadSection {
            title: title.into(),
            rows: vec![],
            progress: Some(CreditProgress {
                required,
                earned,
                pending,
            }),
        }
    }
    #[test]
    fn graduate_credit_map_never_sums_overlapping_groups_or_pool() {
        let data = AcademicData {
            notice: Some("学校说明".into()),
            sections: vec![
                section("培养方案执行报告", Some(32.0), Some(8.0), None),
                section("合并类别", Some(8.0), Some(4.0), Some(3.0)),
                section("合并类别 · 课组", Some(8.0), Some(4.0), Some(3.0)),
            ],
        };
        let map = project_graduate_credit_map(&data);
        let top = map.summary.unwrap().progress.unwrap();
        assert_eq!(top.required, Some(32.0));
        assert_eq!(top.earned, Some(8.0));
        assert_eq!(top.remaining, Some(24.0));
        assert_eq!(top.pending, None);
        assert_eq!(top.ratio, Some(0.25));
        assert_eq!(map.nodes.len(), 2);
        assert_eq!(map.nodes[1].source_index, 2);
        assert_eq!(map.notice.as_deref(), Some("学校说明"));
    }
    #[test]
    fn graduate_credit_map_unknown_invalid_zero_and_pending_stay_distinct() {
        let unknown = metrics(&CreditProgress {
            required: Some(10.0),
            earned: None,
            pending: Some(10.0),
        });
        assert_eq!(unknown.remaining, None);
        assert_eq!(unknown.ratio, None);
        assert_eq!(unknown.earned, None);
        let invalid = metrics(&CreditProgress {
            required: Some(f64::NAN),
            earned: Some(-1.0),
            pending: Some(f64::INFINITY),
        });
        assert_eq!(invalid.required, None);
        assert_eq!(invalid.earned, None);
        assert_eq!(invalid.pending, None);
        let zero = metrics(&CreditProgress {
            required: Some(0.0),
            earned: Some(0.0),
            pending: Some(0.0),
        });
        assert_eq!(zero.remaining, Some(0.0));
        assert_eq!(zero.ratio, None);
        assert_eq!(zero.pending, Some(0.0));
        let over = metrics(&CreditProgress {
            required: Some(2.0),
            earned: Some(3.0),
            pending: Some(1.0),
        });
        assert_eq!(over.earned, Some(3.0));
        assert_eq!(over.remaining, Some(0.0));
        assert_eq!(over.ratio, Some(1.0));
    }
    #[test]
    fn graduate_credit_map_empty_and_plan_fallback_do_not_invent_total() {
        let empty = project_graduate_credit_map(&AcademicData {
            sections: vec![],
            notice: None,
        });
        assert!(empty.summary.is_none());
        assert!(empty.nodes.is_empty());
        let fallback = project_graduate_credit_map(&AcademicData {
            sections: vec![section(
                "计划课程池（不等于毕业学分要求）",
                None,
                None,
                None,
            )],
            notice: Some("报告读取失败".into()),
        });
        assert!(fallback.summary.is_none());
        assert_eq!(fallback.nodes.len(), 1);
        let json = serde_json::to_value(fallback).unwrap();
        assert!(json["nodes"][0].get("sourceIndex").is_some());
        assert!(json["nodes"][0]["progress"]["remaining"].is_null());
    }
}
