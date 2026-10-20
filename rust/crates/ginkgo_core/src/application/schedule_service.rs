//! Real read-only schedule, today and grade use cases.
//!
//! The mirror keeps the Apple recovery rule: a confirmed expired session gets
//! exactly one silent re-login and one retry; refresh failures keep the last
//! snapshot instead of clearing the page.
use super::{
    cache::now_shanghai,
    session_service::{is_recoverable, SessionService},
};
use crate::{
    adapters::{
        grades_http,
        schedule_http::{self, Portal},
    },
    auth::CredentialVault,
    features::{
        grades::{self, GradeCourse, GradeSummary},
        schedule::{CourseMeeting, Exam, Term, Week},
        today::TodayCourse,
    },
    foundation::{http::HttpTransport, school_time},
    AppError, ErrorCode,
};
#[derive(Clone)]
pub struct ScheduleData {
    pub terms: Vec<Term>,
    pub weeks: Vec<Week>,
    pub term_id: String,
    pub week_number: i32,
    pub courses: Vec<CourseMeeting>,
    pub exams: Vec<Exam>,
}

pub struct ScheduleQueryInput {
    pub week: Option<i32>,
    pub force_refresh: bool,
}

pub struct ScheduleOutcome {
    pub data: ScheduleData,
    pub fetched_at: String,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<AppError>,
}

pub struct TodayOutcome {
    pub date: String,
    pub courses: Vec<TodayCourse>,
    pub fetched_at: String,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<AppError>,
}

#[derive(Clone)]
pub struct GradeData {
    pub term_id: String,
    pub courses: Vec<GradeCourse>,
}

pub struct GradeOutcome {
    pub term_id: String,
    pub courses: Vec<GradeCourse>,
    pub summary: GradeSummary,
    pub fetched_at: String,
    pub from_cache: bool,
    pub stale: bool,
    pub failure: Option<AppError>,
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SessionService<T, V> {
    pub async fn load_schedule(
        &self,
        input: &ScheduleQueryInput,
    ) -> Result<ScheduleOutcome, AppError> {
        self.current_account()?;
        if input.week.is_some_and(|week| !(1..=30).contains(&week)) {
            return Err(AppError::invalid());
        }
        let key = input.week;
        if !input.force_refresh {
            let cached = self.schedules.lock().expect("schedule cache");
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

        let fetched = match self.fetch_schedule(input.week).await {
            Err(error) if error.code == ErrorCode::SessionExpired => {
                self.silent_login().await?;
                self.fetch_schedule(input.week).await
            }
            other => other,
        };

        match fetched {
            Ok(data) => {
                let timestamp = self
                    .schedules
                    .lock()
                    .expect("schedule cache")
                    .insert(key, data.clone());
                Ok(ScheduleOutcome {
                    data,
                    fetched_at: timestamp,
                    from_cache: false,
                    stale: false,
                    failure: None,
                })
            }
            Err(error) if is_recoverable(&error) => {
                let cached = self.schedules.lock().expect("schedule cache");
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
            Err(error) => Err(error),
        }
    }

    async fn fetch_schedule(&self, week: Option<i32>) -> Result<ScheduleData, AppError> {
        if schedule_http::detect_portal(&self.session).await? == Portal::Graduate {
            return Err(AppError::new(ErrorCode::UnsupportedPortal));
        }
        let terms = schedule_http::load_terms(&self.session).await?;
        let Some(term) = terms
            .iter()
            .find(|term| term.selected)
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

    pub async fn load_today(&self, force_refresh: bool) -> Result<TodayOutcome, AppError> {
        self.current_account()?;
        let day = school_time::beijing_day(&now_shanghai())?;
        let date = day.local_date;
        if !force_refresh {
            let cached = self.today.lock().expect("today cache");
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

        let fetched = match schedule_http::load_today(&self.session, &date).await {
            Err(error) if error.code == ErrorCode::SessionExpired => {
                self.silent_login().await?;
                schedule_http::load_today(&self.session, &date).await
            }
            other => other,
        };

        match fetched {
            Ok(courses) => {
                let timestamp = self
                    .today
                    .lock()
                    .expect("today cache")
                    .insert(date.clone(), courses.clone());
                Ok(TodayOutcome {
                    date,
                    courses,
                    fetched_at: timestamp,
                    from_cache: false,
                    stale: false,
                    failure: None,
                })
            }
            Err(error) if is_recoverable(&error) => {
                let cached = self.today.lock().expect("today cache");
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
            Err(error) => Err(error),
        }
    }

    pub async fn load_grades(
        &self,
        term_code: Option<&str>,
        force_refresh: bool,
    ) -> Result<GradeOutcome, AppError> {
        self.current_account()?;
        if term_code.is_some_and(|code| code.trim().is_empty()) {
            return Err(AppError::invalid());
        }
        let cache_key = term_code
            .map(|code| code.trim().to_owned())
            .unwrap_or_else(|| "__current__".into());
        if !force_refresh {
            if let Some(entry) = self.grades.lock().expect("grade cache").fresh(&cache_key) {
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

        let fetched = match self.fetch_grades(term_code).await {
            Err(error) if error.code == ErrorCode::SessionExpired => {
                self.silent_login().await?;
                self.fetch_grades(term_code).await
            }
            other => other,
        };

        match fetched {
            Ok((term_id, courses)) => {
                let timestamp = self.grades.lock().expect("grade cache").insert(
                    cache_key,
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
            Err(error) if is_recoverable(&error) => {
                let cached = self.grades.lock().expect("grade cache");
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
            Err(error) => Err(error),
        }
    }

    async fn fetch_grades(
        &self,
        term_code: Option<&str>,
    ) -> Result<(String, Vec<GradeCourse>), AppError> {
        let term_id = match term_code {
            Some(code) => code.trim().to_owned(),
            None => {
                if schedule_http::detect_portal(&self.session).await? == Portal::Graduate {
                    return Err(AppError::new(ErrorCode::UnsupportedPortal));
                }
                let terms = schedule_http::load_terms(&self.session).await?;
                terms
                    .iter()
                    .find(|term| term.selected)
                    .or_else(|| terms.first())
                    .map(|term| term.id.clone())
                    .ok_or_else(|| AppError::new(ErrorCode::UnsupportedPortal))?
            }
        };
        grades::term_parts(&term_id)?;
        let courses = grades_http::load_grades(&self.session, &term_id).await?;
        Ok((term_id, courses))
    }
}
