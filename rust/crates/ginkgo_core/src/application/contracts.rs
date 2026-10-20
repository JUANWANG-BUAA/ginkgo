//! Shared fixture contract router. One arm per contract family; domain logic
//! stays in `features` and authentication parsers stay in `auth`.
use crate::{
    auth::cas,
    features::{bykc, classroom, grades, homework, schedule, today},
    foundation::school_time,
    AppError, ErrorCode,
};
use serde::{de::DeserializeOwned, Deserialize};
use serde_json::{json, Value};

fn decode<T: DeserializeOwned>(value: Value) -> Result<T, AppError> {
    serde_json::from_value(value).map_err(|_| AppError::changed())
}

pub fn execute_contract(contract: &str, version: u32, input: Value) -> Result<Value, AppError> {
    if version != 1 {
        return Err(AppError::new(ErrorCode::UnsupportedContract));
    }
    let value = match contract {
        "classroom.filter" => {
            let result = classroom::filter(decode(input)?)?;
            let ids: std::collections::BTreeMap<_, _> = result
                .buildings
                .into_iter()
                .map(|(building, rooms)| {
                    (
                        building,
                        rooms.into_iter().map(|r| r.room.id).collect::<Vec<_>>(),
                    )
                })
                .collect();
            json!({"roomIDsByBuilding": ids, "summary": result.summary})
        }
        "classroom.parse_response" => {
            let rooms = classroom::parse_upstream_response(input)?;
            json!({"roomIDsByBuilding": classroom::room_ids_by_building(&rooms)})
        }
        "school_time.beijing_day" => {
            let request: school_time::DayRequest = decode(input)?;
            serde_json::to_value(school_time::beijing_day(&request.instant)?)
                .map_err(|_| AppError::changed())?
        }
        "schedule.snapshot_retained_weeks" => {
            let request: schedule::MergeRequest = decode(input)?;
            let probe_week = request.previous.as_ref().map(|s| s.week_number);
            let snapshot = schedule::retain_weeks(request)?;
            let weeks = snapshot
                .term_courses
                .as_ref()
                .ok_or_else(AppError::changed)?;
            let ids: std::collections::BTreeMap<_, _> = weeks
                .iter()
                .map(|(week, courses)| {
                    (
                        week.clone(),
                        courses.iter().map(|c| &c.id).collect::<Vec<_>>(),
                    )
                })
                .collect();
            let selectable = probe_week
                .and_then(|week| snapshot.select_week(week))
                .map(|s| s.week_number);
            json!({"courseIDsByWeek": ids, "selectableCachedWeek": selectable})
        }
        "bykc.course_filter" => {
            serde_json::to_value(bykc::filter(decode(input)?)?).map_err(|_| AppError::changed())?
        }
        "auth.cas_login_page" => {
            #[derive(Deserialize)]
            struct LoginPageInput {
                html: String,
            }
            let input: LoginPageInput = decode(input)?;
            let captcha = cas::detect_captcha(&input.html).map(|challenge| {
                json!({
                    "type": challenge.captcha_type,
                    "id": challenge.id,
                    "imageURL": challenge.image_url,
                })
            });
            json!({
                "execution": cas::extract_execution(&input.html),
                "formAction": cas::extract_login_form_action(&input.html),
                "captcha": captcha,
            })
        }
        "auth.uc_status" => {
            #[derive(Deserialize)]
            struct UcStatusInput {
                body: String,
            }
            let input: UcStatusInput = decode(input)?;
            match crate::auth::uc::parse_uc_status(&input.body) {
                Ok(profile) => json!({
                    "valid": true,
                    "schoolID": profile.school_id,
                    "name": profile.name,
                }),
                Err(error) if error.code == ErrorCode::ChangedResponse => {
                    json!({"error": error.code})
                }
                Err(_) => json!({"valid": false}),
            }
        }
        "schedule.terms"
        | "schedule.weeks"
        | "schedule.undergraduate_courses"
        | "schedule.exams" => {
            #[derive(Deserialize)]
            struct BodyInput {
                body: Value,
            }
            let input: BodyInput = decode(input)?;
            match contract {
                "schedule.terms" => json!({"terms": schedule::parse_terms(input.body)?}),
                "schedule.weeks" => json!({"weeks": schedule::parse_weeks(input.body)?}),
                "schedule.undergraduate_courses" => json!({
                    "courses": schedule::parse_undergraduate_courses(input.body)?
                }),
                _ => json!({"exams": schedule::parse_exams(input.body)?}),
            }
        }
        "grades.buaa_score" => {
            #[derive(Deserialize)]
            struct BodyInput {
                body: Value,
            }
            let input: BodyInput = decode(input)?;
            json!({"courses": grades::parse_courses(input.body)?})
        }
        "grades.term_parts" => {
            #[derive(Deserialize)]
            struct CodeInput {
                code: String,
            }
            let input: CodeInput = decode(input)?;
            let (year, semester) = grades::term_parts(&input.code)?;
            json!({"year": year, "semester": semester})
        }
        "schedule.today_courses" => {
            #[derive(Deserialize)]
            struct BodyInput {
                body: Value,
            }
            let input: BodyInput = decode(input)?;
            json!({"courses": today::parse_courses(input.body)?})
        }
        "homework.spoc_page" => {
            #[derive(Deserialize)]
            struct BodyInput {
                body: Value,
            }
            let input: BodyInput = decode(input)?;
            json!({"page": homework::parse_page(input.body)?})
        }
        "homework.spoc_encrypt" => {
            #[derive(Deserialize)]
            struct PlainInput {
                plain: String,
            }
            let input: PlainInput = decode(input)?;
            json!({"encoded": homework::encrypt_page_param(&input.plain)})
        }
        _ => return Err(AppError::new(ErrorCode::UnsupportedContract)),
    };
    Ok(value)
}
