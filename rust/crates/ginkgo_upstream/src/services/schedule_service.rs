//! Real read-only schedule, today and grade use cases.
//!
//! The mirror keeps the Apple recovery rule: a confirmed expired session gets
//! exactly one silent re-login and one retry; refresh failures keep the last
//! snapshot instead of clearing the page.
use super::{cache::now_shanghai, session_service::SchoolClient};
use crate::{
    adapters::{
        grades_http, graduate_schedule_http,
        schedule_http::{self, Portal},
    },
    auth::CredentialVault,
    codecs::{
        grades::{self, GradeCourse},
        schedule::Term,
        today::TodayCourse,
    },
    foundation::{http::HttpTransport, school_time},
    AppError, ErrorCode,
};
use chrono::{Datelike, NaiveDate};
pub use ginkgo_domain::ports::ScheduleData;
use ginkgo_domain::ports::*;

pub use ginkgo_domain::ports::ScheduleQueryInput;

pub use ginkgo_domain::ports::ScheduleOutcome;

pub use ginkgo_domain::ports::TodayOutcome;

pub use ginkgo_domain::ports::GradeData;

pub use ginkgo_domain::ports::GradeOutcome;

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    async fn fetch_schedule(
        &self,
        term_id: Option<&str>,
        week: Option<i32>,
    ) -> Result<ScheduleData, AppError> {
        match schedule_http::detect_portal(&self.session).await? {
            Portal::Undergraduate => self.fetch_undergraduate_schedule(term_id, week).await,
            Portal::Graduate | Portal::Unconfirmed => {
                self.fetch_graduate_schedule(term_id, week).await
            }
        }
    }

    async fn fetch_undergraduate_schedule(
        &self,
        term_id: Option<&str>,
        week: Option<i32>,
    ) -> Result<ScheduleData, AppError> {
        let terms = schedule_http::load_terms(&self.session).await?;
        let Some(term) = terms
            .iter()
            .find(|term| Some(term.id.as_str()) == term_id)
            .or_else(|| terms.iter().find(|term| term.selected))
            .or_else(|| terms.first())
            .cloned()
        else {
            return Ok(ScheduleData {
                terms,
                weeks: vec![],
                term_id: String::new(),
                week_number: 0,
                courses: vec![],
                exams: vec![],
            });
        };
        let weeks = schedule_http::load_weeks(&self.session, &term.id).await?;
        let week_number = week
            .or_else(|| {
                weeks
                    .iter()
                    .find(|week| week.current)
                    .map(|week| week.number)
            })
            .or_else(|| weeks.first().map(|week| week.number))
            .unwrap_or(0);
        let courses = if weeks.iter().any(|item| item.number == week_number) {
            schedule_http::load_week_courses(&self.session, &term.id, week_number).await?
        } else {
            vec![]
        };
        // Exams are term-wide; a portal that forbids them must not hide the
        // weekly timetable.
        let exams = match schedule_http::load_exams(&self.session, &term.id).await {
            Ok(exams) => exams,
            Err(error) if error.code == ErrorCode::UnsupportedPortal => vec![],
            Err(error) => return Err(error),
        };
        Ok(ScheduleData {
            terms,
            weeks,
            term_id: term.id,
            week_number,
            courses,
            exams,
        })
    }

    async fn fetch_graduate_schedule(
        &self,
        term_id: Option<&str>,
        week: Option<i32>,
    ) -> Result<ScheduleData, AppError> {
        let terms = graduate_schedule_http::load_terms(&self.session)
            .await
            .map_err(|error| {
                if error.detail.is_some() {
                    error
                } else {
                    AppError::with_detail(error.code, "graduate_terms")
                }
            })?;
        let Some(term) = terms
            .iter()
            .find(|term| Some(term.id.as_str()) == term_id)
            .or_else(|| terms.iter().find(|term| term.selected))
            .or_else(|| terms.first())
            .cloned()
        else {
            return Ok(ScheduleData {
                terms,
                weeks: vec![],
                term_id: String::new(),
                week_number: 0,
                courses: vec![],
                exams: vec![],
            });
        };
        let graduate = graduate_schedule_http::load_schedule(&self.session, &term.id)
            .await
            .map_err(|error| {
                if error.detail.is_some() {
                    error
                } else {
                    AppError::with_detail(error.code, "graduate_schedule")
                }
            })?;
        let week_number = week
            .or_else(|| {
                graduate
                    .weeks
                    .iter()
                    .find(|week| week.current)
                    .map(|week| week.number)
            })
            .or_else(|| graduate.weeks.first().map(|week| week.number))
            .unwrap_or(0);
        let courses = graduate
            .courses_by_week
            .get(&week_number)
            .cloned()
            .unwrap_or_default();
        Ok(ScheduleData {
            terms,
            weeks: graduate.weeks,
            term_id: term.id,
            week_number,
            courses,
            // GSMIS exams are not exposed by the documented graduate portal.
            exams: vec![],
        })
    }

    async fn load_today_from_schedule(
        &self,
        date: &str,
        force_refresh: bool,
    ) -> Result<TodayOutcome, AppError> {
        let schedule = self
            .load_schedule(&ScheduleQueryInput {
                term_id: None,
                week: None,
                force_refresh,
            })
            .await?;
        let today = NaiveDate::parse_from_str(date, "%Y-%m-%d").map_err(|_| AppError::changed())?;
        let weekday = today.weekday().number_from_monday() as i32;
        let in_term = schedule
            .data
            .weeks
            .iter()
            .any(|week| week.start_date <= today && today <= week.end_date);
        let courses = if in_term {
            schedule
                .data
                .courses
                .into_iter()
                .filter(|course| course.day == weekday)
                .map(|course| TodayCourse {
                    name: course.name,
                    place: course.place,
                    time: match (course.start_time, course.end_time) {
                        (Some(start), Some(end)) => Some(format!("{start}-{end}")),
                        _ => Some(format!(
                            "第{}-{}节",
                            course.start_section, course.end_section
                        )),
                    },
                    short_name: None,
                })
                .collect()
        } else {
            Vec::new()
        };
        Ok(TodayOutcome {
            date: date.to_owned(),
            courses,
            fetched_at: schedule.fetched_at,
            from_cache: schedule.from_cache,
            stale: schedule.stale,
            failure: schedule.failure,
        })
    }

    async fn fetch_terms(&self) -> Result<Vec<Term>, AppError> {
        match schedule_http::detect_portal(&self.session).await? {
            Portal::Undergraduate => schedule_http::load_terms(&self.session).await,
            Portal::Graduate | Portal::Unconfirmed => {
                graduate_schedule_http::load_terms(&self.session).await
            }
        }
    }

    async fn fetch_grades(
        &self,
        term_code: Option<&str>,
    ) -> Result<(String, Vec<GradeCourse>), AppError> {
        let term_id = match term_code {
            Some(code) => code.trim().to_owned(),
            None => {
                let terms = self.fetch_terms().await?;
                terms
                    .iter()
                    .find(|term| term.selected)
                    .or_else(|| terms.first())
                    .map(|term| term.id.clone())
                    .ok_or_else(|| AppError::new(ErrorCode::ServiceUnavailable))?
            }
        };
        grades::term_parts(&term_id)?;
        let courses = grades_http::load_grades(&self.session, &term_id).await?;
        Ok((term_id, courses))
    }
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> GradeSource for SchoolClient<T, V> {
    async fn load_grades(
        &self,
        term_code: Option<&str>,
        force_refresh: bool,
    ) -> Result<GradeOutcome, AppError> {
        let account = self.current_account()?;
        if term_code.is_some_and(|code| code.trim().is_empty()) {
            return Err(AppError::invalid());
        }
        let cache_key = term_code
            .map(|code| code.trim().to_owned())
            .unwrap_or_else(|| "__current__".into());
        if !force_refresh {
            if let Some(entry) = self.snapshots.grades.lock().fresh(&cache_key) {
                return Ok(GradeOutcome {
                    term_id: entry.value.term_id.clone(),
                    courses: entry.value.courses.clone(),
                    summary: grades::summarize(&entry.value.courses),
                    fetched_at: entry.timestamp.clone(),
                    from_cache: true,
                    stale: false,
                    failure: None,
                });
            }
        }

        let ticket = self.snapshots.grades.lock().begin(&cache_key);
        let fetched = match self.fetch_grades(term_code).await {
            Err(error) if error.code == ErrorCode::SessionExpired => {
                match self.silent_login().await {
                    Ok(()) => self.fetch_grades(term_code).await,
                    Err(error) => Err(error),
                }
            }
            other => other,
        };
        if self.current_account()? != account {
            return Err(AppError::session_expired());
        }

        match fetched {
            Ok((term_id, courses)) => {
                let timestamp = self.snapshots.grades.lock().insert_if_current(
                    cache_key,
                    ticket,
                    GradeData {
                        term_id: term_id.clone(),
                        courses: courses.clone(),
                    },
                );
                Ok(GradeOutcome {
                    term_id,
                    summary: grades::summarize(&courses),
                    courses,
                    fetched_at: timestamp,
                    from_cache: false,
                    stale: false,
                    failure: None,
                })
            }
            Err(error) => {
                let cached = self.snapshots.grades.lock();
                match cached.any(&cache_key) {
                    Some(entry) => Ok(GradeOutcome {
                        term_id: entry.value.term_id.clone(),
                        summary: grades::summarize(&entry.value.courses),
                        courses: entry.value.courses.clone(),
                        fetched_at: entry.timestamp.clone(),
                        from_cache: true,
                        stale: true,
                        failure: Some(error),
                    }),
                    None => Err(error),
                }
            }
        }
    }

    async fn load_grade_terms(&self) -> Result<Vec<Term>, AppError> {
        let account = self.current_account()?;
        let fetched = match self.fetch_terms().await {
            Err(error) if error.code == ErrorCode::SessionExpired => {
                self.silent_login().await?;
                self.fetch_terms().await
            }
            other => other,
        };
        if self.current_account()? != account {
            return Err(AppError::session_expired());
        }
        fetched
    }
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> TodaySource for SchoolClient<T, V> {
    async fn load_today(&self, force_refresh: bool) -> Result<TodayOutcome, AppError> {
        let account = self.current_account()?;
        let day = school_time::beijing_day(&now_shanghai())?;
        let date = day.local_date;
        if !force_refresh {
            let cached = self.snapshots.today.lock();
            if let Some(entry) = cached.fresh(&date) {
                return Ok(TodayOutcome {
                    date,
                    courses: entry.value.clone(),
                    fetched_at: entry.timestamp.clone(),
                    from_cache: true,
                    stale: false,
                    failure: None,
                });
            }
        }

        let ticket = self.snapshots.today.lock().begin(&date);
        let portal = schedule_http::detect_portal(&self.session).await?;
        if portal != Portal::Undergraduate {
            let outcome = self.load_today_from_schedule(&date, force_refresh).await;
            if self.current_account()? != account {
                return Err(AppError::session_expired());
            }
            return outcome;
        }

        let fetched = match schedule_http::load_today(&self.session, &date).await {
            Err(error) if error.code == ErrorCode::SessionExpired => {
                match self.silent_login().await {
                    Ok(()) => schedule_http::load_today(&self.session, &date).await,
                    Err(error) => Err(error),
                }
            }
            other => other,
        };
        if self.current_account()? != account {
            return Err(AppError::session_expired());
        }

        match fetched {
            Ok(courses) => {
                let timestamp = self.snapshots.today.lock().insert_if_current(
                    date.clone(),
                    ticket,
                    courses.clone(),
                );
                Ok(TodayOutcome {
                    date,
                    courses,
                    fetched_at: timestamp,
                    from_cache: false,
                    stale: false,
                    failure: None,
                })
            }
            Err(error) => {
                let cached = self.snapshots.today.lock();
                match cached.any(&date) {
                    Some(entry) => Ok(TodayOutcome {
                        date,
                        courses: entry.value.clone(),
                        fetched_at: entry.timestamp.clone(),
                        from_cache: true,
                        stale: true,
                        failure: Some(error),
                    }),
                    None => Err(error),
                }
            }
        }
    }
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> ScheduleSource for SchoolClient<T, V> {
    async fn load_schedule(&self, input: &ScheduleQueryInput) -> Result<ScheduleOutcome, AppError> {
        let account = self.current_account()?;
        if input.week.is_some_and(|week| !(1..=30).contains(&week)) {
            return Err(AppError::invalid());
        }
        let key = (input.term_id.clone(), input.week);
        if !input.force_refresh {
            let cached = self.snapshots.schedules.lock();
            if let Some(entry) = cached.fresh(&key) {
                return Ok(ScheduleOutcome {
                    data: entry.value.clone(),
                    fetched_at: entry.timestamp.clone(),
                    from_cache: true,
                    stale: false,
                    failure: None,
                });
            }
        }

        let ticket = self.snapshots.schedules.lock().begin(&key);

        let fetched = match self
            .fetch_schedule(input.term_id.as_deref(), input.week)
            .await
        {
            Err(error) if error.code == ErrorCode::SessionExpired => {
                match self.silent_login().await {
                    Ok(()) => {
                        self.fetch_schedule(input.term_id.as_deref(), input.week)
                            .await
                    }
                    Err(error) => Err(error),
                }
            }
            other => other,
        };
        if self.current_account()? != account {
            return Err(AppError::session_expired());
        }

        match fetched {
            Ok(data) => {
                let timestamp =
                    self.snapshots
                        .schedules
                        .lock()
                        .insert_if_current(key, ticket, data.clone());
                Ok(ScheduleOutcome {
                    data,
                    fetched_at: timestamp,
                    from_cache: false,
                    stale: false,
                    failure: None,
                })
            }
            Err(error) => {
                let cached = self.snapshots.schedules.lock();
                match cached.any(&key) {
                    Some(entry) => Ok(ScheduleOutcome {
                        data: entry.value.clone(),
                        fetched_at: entry.timestamp.clone(),
                        from_cache: true,
                        stale: true,
                        failure: Some(error),
                    }),
                    None => Err(error),
                }
            }
        }
    }
}
