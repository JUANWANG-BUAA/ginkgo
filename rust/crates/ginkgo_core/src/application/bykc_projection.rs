use crate::{features::bykc::Catalog, AppError};

/// Page projection adds the selected term without exposing upstream fields or
/// asking Flutter to repeat the school's semester policy.
#[derive(serde::Serialize)]
#[serde(rename_all = "camelCase")]
pub struct BykcCatalogView {
    #[serde(flatten)]
    pub catalog: Catalog,
    pub current_term: Option<crate::features::bykc::Semester>,
}

pub fn project_catalog(catalog: Catalog) -> Result<BykcCatalogView, AppError> {
    project_catalog_at(
        catalog,
        &chrono::DateTime::<chrono::Utc>::from(std::time::SystemTime::now()).to_rfc3339(),
    )
}

fn project_catalog_at(catalog: Catalog, instant: &str) -> Result<BykcCatalogView, AppError> {
    let current_term = crate::features::bykc::current_semester(&catalog.terms, instant)?;
    Ok(BykcCatalogView {
        catalog,
        current_term,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn catalog_projection_uses_the_shared_beijing_semester_policy() {
        use crate::features::bykc::Semester;
        let catalog = Catalog {
            terms: vec![
                Semester {
                    id: "active".into(),
                    name: "合成当前学期".into(),
                    start: Some("2026-09-01 00:00:00".into()),
                    end: Some("2027-01-31 23:59:59".into()),
                },
                Semester {
                    id: "future".into(),
                    name: "合成未来学期".into(),
                    start: Some("2027-09-01 00:00:00".into()),
                    end: Some("2028-01-31 23:59:59".into()),
                },
            ],
            courses: vec![],
        };
        let view = project_catalog_at(catalog, "2026-08-31T16:00:00Z").expect("Beijing boundary");
        let json = serde_json::to_value(view).expect("page contract");
        assert_eq!(json["currentTerm"]["id"], "active");
        assert_eq!(json["terms"].as_array().expect("terms").len(), 2);
        assert_eq!(json["courses"], serde_json::json!([]));
    }
}
