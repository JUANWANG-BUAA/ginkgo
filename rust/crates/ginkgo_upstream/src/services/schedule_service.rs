//! Real read-only schedule, today and grade use cases.
//!
//! The mirror keeps the Apple recovery rule: a confirmed expired session gets
//! exactly one silent re-login and one retry; refresh failures keep the last
//! snapshot instead of clearing the page.
use super::{
    cache::now_shanghai,
    session_service::{AccountOwner, SchoolClient},
};
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
        let owner = self.account_owner()?;
        let graduate = self.identity.lock().graduate_schedule;
        if !graduate
            && matches!(
                schedule_http::detect_portal(&self.session).await,
                Ok(Portal::Undergraduate)
            )
        {
            let data = self.fetch_undergraduate_schedule(term_id, week).await?;
            self.check_account_owner(&owner)?;
            return Ok(data);
        }
        // Match UBAA withScheduleAccess: a failed undergraduate probe/query
        // must not block the documented GSMIS data source.
        let data = self.fetch_graduate_schedule(term_id, week).await?;
        self.remember_graduate_source(&owner)?;
        Ok(data)
    }

    fn remember_graduate_source(&self, owner: &AccountOwner) -> Result<(), AppError> {
        let mut identity = self.identity.lock();
        if identity.generation != owner.generation
            || !identity
                .authenticated
                .as_ref()
                .is_some_and(|user| user.account == owner.account)
        {
            return Err(AppError::session_expired());
        }
        identity.graduate_schedule = true;
        Ok(())
    }

    async fn fetch_undergraduate_schedule(
        &self,
        term_id: Option<&str>,
        week: Option<i32>,
    ) -> Result<ScheduleData, AppError> {
        let terms = schedule_http::load_terms(&self.session).await?;
        let preferred = beijing_today()
            .map(preferred_undergraduate_term_id)
            .unwrap_or_default();
        let Some(term) = terms
            .iter()
            .find(|term| Some(term.id.as_str()) == term_id)
            .or_else(|| terms.iter().find(|term| term.selected))
            .or_else(|| {
                terms
                    .iter()
                    .find(|term| !preferred.is_empty() && term.id <= preferred)
            })
            .or_else(|| terms.first())
            .cloned()
        else {
            // A signed-in student always has at least one term; an empty list
            // means the portal did not return data, not "no classes".
            return Err(AppError::with_detail(
                ErrorCode::ChangedResponse,
                "schedule_terms_empty",
            ));
        };
        let weeks = schedule_http::load_weeks(&self.session, &term.id).await?;
        if weeks.is_empty() {
            return Err(AppError::with_detail(
                ErrorCode::ChangedResponse,
                "schedule_weeks_empty",
            ));
        }
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
            let mut courses =
                schedule_http::load_week_courses(&self.session, &term.id, week_number).await?;
            if courses.is_empty() && schedule_http::activate_portal(&self.session).await.is_ok() {
                // BYXT can answer an uninitialised student context with an
                // empty list. One activation plus one repeat of the same read;
                // a genuinely empty week stays empty.
                courses =
                    schedule_http::load_week_courses(&self.session, &term.id, week_number).await?;
            }
            courses
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
        let mut terms = graduate_schedule_http::load_terms(&self.session)
            .await
            .map_err(|error| {
                if error.detail.is_some() {
                    error
                } else {
                    AppError::with_detail(error.code, "graduate_terms")
                }
            })?;
        if terms.is_empty() {
            return Err(AppError::with_detail(
                ErrorCode::ChangedResponse,
                "graduate_terms_empty",
            ));
        }
        let (term, graduate) = if let Some(requested) = term_id {
            let term = terms
                .iter()
                .find(|term| term.id == requested)
                .or_else(|| terms.first())
                .cloned()
                .expect("non-empty terms");
            let schedule = self.load_graduate_term_schedule(&term.id).await?;
            (term, schedule)
        } else {
            let preferred = beijing_today()
                .map(preferred_graduate_term_id)
                .unwrap_or_default();
            let primary_idx = terms
                .iter()
                .position(|term| !preferred.is_empty() && term.id <= preferred)
                .unwrap_or(0);
            let primary_term = terms[primary_idx].clone();
            let primary_schedule = self.load_graduate_term_schedule(&primary_term.id).await?;
            if !primary_schedule.weeks.is_empty() {
                (primary_term, primary_schedule)
            } else if let Some(fallback_term) = terms.get(primary_idx + 1).cloned() {
                // GSMIS opens next semester's term entry weeks before publishing
                // its timetable (and summer terms often have no courses). Probe
                // the immediately preceding term once before accepting empty.
                match self.load_graduate_term_schedule(&fallback_term.id).await {
                    Ok(fallback_schedule) if !fallback_schedule.weeks.is_empty() => {
                        (fallback_term, fallback_schedule)
                    }
                    _ => (primary_term, primary_schedule),
                }
            } else {
                (primary_term, primary_schedule)
            }
        };
        for item in &mut terms {
            item.selected = item.id == term.id;
        }
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

    async fn load_graduate_term_schedule(
        &self,
        term_id: &str,
    ) -> Result<graduate_schedule_http::GraduateSchedule, AppError> {
        graduate_schedule_http::load_schedule(&self.session, term_id)
            .await
            .map_err(|error| {
                if error.detail.is_some() {
                    error
                } else {
                    AppError::with_detail(error.code, "graduate_schedule")
                }
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
        let owner = self.account_owner()?;
        let graduate = self.identity.lock().graduate_schedule;
        if !graduate
            && matches!(
                schedule_http::detect_portal(&self.session).await,
                Ok(Portal::Undergraduate)
            )
        {
            let terms = schedule_http::load_terms(&self.session).await?;
            self.check_account_owner(&owner)?;
            return Ok(terms);
        }
        let data = self.fetch_graduate_schedule(None, None).await?;
        self.remember_graduate_source(&owner)?;
        Ok(data.terms)
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

        let snapshot = super::cache::read_with_snapshot_checked(
            &self.snapshots.grades,
            cache_key,
            force_refresh,
            async {
                let fetched = match self.fetch_grades(term_code).await {
                    Err(error) if error.code == ErrorCode::SessionExpired => {
                        match self.silent_login().await {
                            Ok(()) => self.fetch_grades(term_code).await,
                            Err(error) => Err(error),
                        }
                    }
                    other => other,
                };
                fetched.map(|(term_id, courses)| GradeData { term_id, courses })
            },
            || {
                if self.current_account()? == account {
                    Ok(())
                } else {
                    Err(AppError::session_expired())
                }
            },
        )
        .await?;
        Ok(GradeOutcome {
            term_id: snapshot.data.term_id,
            summary: grades::summarize(&snapshot.data.courses),
            courses: snapshot.data.courses,
            fetched_at: snapshot.fetched_at,
            from_cache: snapshot.from_cache,
            stale: snapshot.stale,
            failure: snapshot.failure,
        })
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

        let graduate = self.identity.lock().graduate_schedule;
        let undergraduate = !graduate
            && matches!(
                schedule_http::detect_portal(&self.session).await,
                Ok(Portal::Undergraduate)
            );
        if !undergraduate {
            let outcome = self.load_today_from_schedule(&date, force_refresh).await;
            if self.current_account()? != account {
                return Err(AppError::session_expired());
            }
            return outcome;
        }

        let snapshot = super::cache::read_with_snapshot_checked(
            &self.snapshots.today,
            date.clone(),
            force_refresh,
            async {
                match load_undergraduate_today(&self.session, &date).await {
                    Err(error) if error.code == ErrorCode::SessionExpired => {
                        match self.silent_login().await {
                            Ok(()) => load_undergraduate_today(&self.session, &date).await,
                            Err(error) => Err(error),
                        }
                    }
                    other => other,
                }
            },
            || {
                if self.current_account()? == account {
                    Ok(())
                } else {
                    Err(AppError::session_expired())
                }
            },
        )
        .await?;
        Ok(TodayOutcome {
            date,
            courses: snapshot.data,
            fetched_at: snapshot.fetched_at,
            from_cache: snapshot.from_cache,
            stale: snapshot.stale,
            failure: snapshot.failure,
        })
    }
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> ScheduleSource for SchoolClient<T, V> {
    async fn load_schedule(&self, input: &ScheduleQueryInput) -> Result<ScheduleOutcome, AppError> {
        let account = self.current_account()?;
        if input.week.is_some_and(|week| !(1..=30).contains(&week)) {
            return Err(AppError::invalid());
        }
        let key = (input.term_id.clone(), input.week);
        let snapshot = super::cache::read_with_snapshot_checked(
            &self.snapshots.schedules,
            key,
            input.force_refresh,
            async {
                match self
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
                }
            },
            || {
                if self.current_account()? == account {
                    Ok(())
                } else {
                    Err(AppError::session_expired())
                }
            },
        )
        .await?;
        Ok(snapshot)
    }
}

fn beijing_today() -> Option<NaiveDate> {
    let day = school_time::beijing_day(&now_shanghai()).ok()?;
    NaiveDate::parse_from_str(&day.local_date, "%Y-%m-%d").ok()
}

/// Active BUAA academic `(start_year, semester_index)` inferred from a Beijing
/// calendar date so pre-opened future semesters (e.g. `20262` opened in
/// November 2026) do not override the active autumn semester (`20261`).
pub(crate) fn preferred_academic_term(today: NaiveDate) -> (i32, u8) {
    match today.month() {
        9..=12 => (today.year(), 1),
        8 if today.day() >= 20 => (today.year(), 1),
        1 => (today.year() - 1, 1),
        2..=6 => (today.year() - 1, 2),
        _ => (today.year() - 1, 3),
    }
}

fn preferred_graduate_term_id(today: NaiveDate) -> String {
    let (year, sem) = preferred_academic_term(today);
    format!("{year}{sem}")
}

fn preferred_undergraduate_term_id(today: NaiveDate) -> String {
    let (year, sem) = preferred_academic_term(today);
    format!("{year}-{}-{sem}", year + 1)
}

async fn load_undergraduate_today<T: HttpTransport>(
    session: &crate::auth::session::Session<T>,
    date: &str,
) -> Result<Vec<TodayCourse>, AppError> {
    let mut courses = schedule_http::load_today(session, date).await?;
    if courses.is_empty() && schedule_http::activate_portal(session).await.is_ok() {
        courses = schedule_http::load_today(session, date).await?;
    }
    Ok(courses)
}
