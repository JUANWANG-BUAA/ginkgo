//! Learning business orchestration. Protocol modules can change without changing core/UI.
use super::{cache::SnapshotCache, session_service::SchoolClient};
use crate::{
    adapters::learning as protocol,
    auth::CredentialVault,
    foundation::{http::HttpTransport, mutex::Mutex},
    AppError,
};
use ginkgo_domain::ports::*;
#[derive(Default)]
pub(crate) struct LearningSnapshots {
    epoch: std::sync::atomic::AtomicU64,
    courses: Mutex<SnapshotCache<String, Vec<LearningCourse>>>,
    columns: Mutex<SnapshotCache<String, Vec<LearningColumn>>>,
    capabilities: Mutex<std::collections::BTreeMap<String, LearningCapabilities>>,
    announcements: Mutex<SnapshotCache<String, Vec<CourseAnnouncement>>>,
    resources: Mutex<SnapshotCache<String, CourseResourcePage>>,
    assessments: Mutex<SnapshotCache<String, Vec<CourseAssessment>>>,
}
impl LearningSnapshots {
    pub fn clear(&self) {
        self.epoch.fetch_add(1, std::sync::atomic::Ordering::AcqRel);
        self.courses.lock().clear();
        self.columns.lock().clear();
        self.capabilities.lock().clear();
        self.announcements.lock().clear();
        self.resources.lock().clear();
        self.assessments.lock().clear();
    }
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    fn learning_owner(&self) -> Result<(String, u64), AppError> {
        let i = self.identity.lock();
        Ok((
            i.authenticated
                .as_ref()
                .ok_or_else(AppError::session_expired)?
                .account
                .clone(),
            i.generation,
        ))
    }
    async fn learning_read<R, F, Fut>(&self, fetch: F) -> Result<R, AppError>
    where
        F: Fn() -> Fut,
        Fut: std::future::Future<Output = Result<R, AppError>>,
    {
        self.learning_read_owned(fetch).await.map(|(data, _)| data)
    }
    async fn learning_read_owned<R, F, Fut>(&self, fetch: F) -> Result<(R, (String, u64)), AppError>
    where
        F: Fn() -> Fut,
        Fut: std::future::Future<Output = Result<R, AppError>>,
    {
        let mut owner = self.learning_owner()?;
        let epoch = self
            .snapshots
            .learning
            .epoch
            .load(std::sync::atomic::Ordering::Acquire);
        let mut result = fetch().await;
        self.learning_check(&owner, epoch)?;
        if let Err(error) = &result {
            if error.detail.as_deref() == Some("webvpn_login_required") {
                self.ensure_webvpn_session().await?;
            } else if error.code == crate::ErrorCode::SessionExpired {
                self.silent_login().await?;
                // Existing silent recovery increments identity generation once, but a
                // logout/account switch or cache clear must still invalidate this read.
                owner.1 = owner.1.wrapping_add(1);
            } else {
                return result.map(|data| (data, owner));
            }
            self.learning_check(&owner, epoch)?;
            result = fetch().await;
        }
        self.learning_check(&owner, epoch)?;
        result.map(|data| (data, owner))
    }
    fn learning_check(&self, owner: &(String, u64), epoch: u64) -> Result<(), AppError> {
        if &self.learning_owner()? != owner
            || self
                .snapshots
                .learning
                .epoch
                .load(std::sync::atomic::Ordering::Acquire)
                != epoch
        {
            return Err(AppError::session_expired());
        }
        Ok(())
    }
    async fn learning_cached<R: Clone + Send, F, Fut>(
        &self,
        cache: &Mutex<SnapshotCache<String, R>>,
        key: String,
        force: bool,
        fetch: F,
    ) -> Result<DataOutcome<R>, AppError>
    where
        F: Fn() -> Fut,
        Fut: std::future::Future<Output = Result<R, AppError>>,
    {
        let owner = self.learning_owner()?;
        // Identity generation prevents even A -> B -> A cache reuse. Do not
        // trust callers to have cleared snapshots before publishing identity.
        let query = key;
        let key = serde_json::to_string(&(&owner, &query)).map_err(|_| AppError::invalid())?;
        let epoch = self
            .snapshots
            .learning
            .epoch
            .load(std::sync::atomic::Ordering::Acquire);
        if !force {
            if let Some(c) = cache.lock().fresh(&key) {
                return Ok(DataOutcome {
                    data: c.value.clone(),
                    failure: None,
                });
            }
        }
        let ticket = cache.lock().begin(&key);
        let owned = self.learning_read_owned(fetch).await;
        let accepted_owner = owned.as_ref().ok().map(|(_, owner)| owner.clone());
        let result = owned.map(|(data, _)| data);
        if self
            .snapshots
            .learning
            .epoch
            .load(std::sync::atomic::Ordering::Acquire)
            != epoch
        {
            return Err(AppError::session_expired());
        }
        if result
            .as_ref()
            .is_err_and(|e| e.code == crate::ErrorCode::SessionExpired)
        {
            return result.map(|data| DataOutcome {
                data,
                failure: None,
            });
        }
        // Hold identity through the cache commit: account publication cannot
        // slip between the post-await owner check and snapshot insertion.
        let identity = self.identity.lock();
        let current = identity
            .authenticated
            .as_ref()
            .ok_or_else(AppError::session_expired)?;
        let expected_owner = accepted_owner.as_ref().unwrap_or(&owner);
        if current.account != expected_owner.0
            || identity.generation != expected_owner.1
            || self
                .snapshots
                .learning
                .epoch
                .load(std::sync::atomic::Ordering::Acquire)
                != epoch
        {
            return Err(AppError::session_expired());
        }
        let mut cache = cache.lock();
        if identity.generation == owner.1 {
            cache.resolve_current(key, ticket, result)
        } else if result.is_ok() && identity.generation == owner.1.wrapping_add(1) {
            // The one accepted silent recovery rotates the identity generation.
            // Publish successful data only under its recovered-owner key.
            let recovered_key =
                serde_json::to_string(&((&current.account, identity.generation), query))
                    .map_err(|_| AppError::invalid())?;
            let recovered_ticket = cache.begin(&recovered_key);
            cache.resolve_current(recovered_key, recovered_ticket, result)
        } else {
            Err(AppError::session_expired())
        }
    }
    async fn learning_auth(
        &self,
        course: &str,
    ) -> Result<crate::adapters::homework_http::SpocAuth, AppError> {
        if course.is_empty() || course.len() > 256 {
            return Err(AppError::invalid());
        }
        let a = protocol::auth(&self.session).await?;
        protocol::ensure_course(&self.session, &a, course).await?;
        Ok(a)
    }
    fn learning_scope(&self) -> Result<((String, u64), u64), AppError> {
        Ok((
            self.learning_owner()?,
            self.snapshots
                .learning
                .epoch
                .load(std::sync::atomic::Ordering::Acquire),
        ))
    }
    fn learning_observe(
        &self,
        course: &str,
        scope: &((String, u64), u64),
        field: fn(&mut LearningCapabilities) -> &mut LearningCapabilityState,
        failure: Option<&AppError>,
    ) {
        // Observation is deliberately passive. No HEAD, synthetic query or writes.
        // A failed/late old-account call must not publish health for the new one.
        let identity = self.identity.lock();
        let Some(current) = identity.authenticated.as_ref() else {
            return;
        };
        if current.account != scope.0 .0
            || identity.generation != scope.0 .1
            || self
                .snapshots
                .learning
                .epoch
                .load(std::sync::atomic::Ordering::Acquire)
                != scope.1
        {
            return;
        }
        let state = match failure.map(|e| &e.code) {
            None => LearningCapabilityState::Available,
            Some(
                crate::ErrorCode::SessionExpired
                | crate::ErrorCode::CaptchaRequired
                | crate::ErrorCode::InvalidCredentials
                | crate::ErrorCode::PreLoginTip,
            ) => LearningCapabilityState::AuthRequired,
            Some(crate::ErrorCode::ChangedResponse | crate::ErrorCode::UnsupportedContract) => {
                LearningCapabilityState::ProtocolChanged
            }
            Some(crate::ErrorCode::AccessPolicyDenied) => LearningCapabilityState::AccessDenied,
            Some(crate::ErrorCode::InvalidRequest) => LearningCapabilityState::Unknown,
            Some(_) => LearningCapabilityState::TemporarilyUnavailable,
        };
        let Ok(key) = serde_json::to_string(&(scope, course)) else {
            return;
        };
        let mut observations = self.snapshots.learning.capabilities.lock();
        if !observations.contains_key(&key) && observations.len() >= 100 {
            observations.pop_first();
        }
        *field(observations.entry(key).or_default()) = state;
    }
    async fn learning_announcements_in(
        &self,
        course: &str,
        selected: Option<&str>,
        force: bool,
    ) -> Result<DataOutcome<Vec<CourseAnnouncement>>, AppError> {
        let _gate = self.learning_gate.lock().await;
        let scope = self.learning_scope()?;
        let key = serde_json::to_string(&(course, selected)).map_err(|_| AppError::invalid())?;
        let fetched = std::sync::atomic::AtomicBool::new(false);
        let result = self
            .learning_cached(
                &self.snapshots.learning.announcements,
                key,
                force,
                || async {
                    fetched.store(true, std::sync::atomic::Ordering::Relaxed);
                    let a = self.learning_auth(course).await?;
                    protocol::announcements::list_in(&self.session, &a, course, selected).await
                },
            )
            .await;
        if fetched.load(std::sync::atomic::Ordering::Relaxed) {
            self.learning_observe(
                course,
                &scope,
                |c| &mut c.announcements,
                outcome_failure(&result),
            );
        }
        result
    }
    async fn announcement_checked(
        &self,
        course: &str,
        selected: Option<&str>,
        id: &str,
    ) -> Result<
        (
            crate::adapters::homework_http::SpocAuth,
            CourseAnnouncementDetail,
        ),
        AppError,
    > {
        if id.is_empty() || id.len() > 256 {
            return Err(AppError::invalid());
        }
        let a = self.learning_auth(course).await?;
        let rows = protocol::announcements::list_in(&self.session, &a, course, selected).await?;
        if rows.iter().filter(|r| r.id == id).count() != 1 {
            return Err(AppError::invalid());
        }
        let detail = protocol::announcements::detail(&self.session, &a, id).await?;
        Ok((a, detail))
    }
    async fn learning_detail_in(
        &self,
        course: &str,
        selected: Option<&str>,
        id: &str,
    ) -> Result<CourseAnnouncementDetail, AppError> {
        let _gate = self.learning_gate.lock().await;
        self.learning_read(|| async {
            Ok(self.announcement_checked(course, selected, id).await?.1)
        })
        .await
    }
    async fn learning_attachment_in(
        &self,
        course: &str,
        selected: Option<&str>,
        id: &str,
        file: &str,
    ) -> Result<LearningDownload, AppError> {
        let _gate = self.learning_gate.lock().await;
        let scope = self.learning_scope()?;
        let result = self
            .learning_read(|| async {
                if file.is_empty() || file.len() > 256 {
                    return Err(AppError::invalid());
                }
                let (a, detail) = self.announcement_checked(course, selected, id).await?;
                let attachments: Vec<_> =
                    detail.attachments.iter().filter(|a| a.id == file).collect();
                if attachments.len() != 1 {
                    return Err(AppError::invalid());
                }
                let bytes = protocol::announcements::download(&self.session, &a, file).await?;
                Ok(LearningDownload {
                    name: attachments[0].name.clone(),
                    bytes,
                })
            })
            .await;
        self.learning_observe(
            course,
            &scope,
            |c| &mut c.announcement_download,
            result.as_ref().err(),
        );
        result
    }
    async fn learning_assessments_in(
        &self,
        course: &str,
        selected: Option<&str>,
        force: bool,
    ) -> Result<DataOutcome<Vec<CourseAssessment>>, AppError> {
        let _gate = self.learning_gate.lock().await;
        let scope = self.learning_scope()?;
        let key = serde_json::to_string(&(course, selected)).map_err(|_| AppError::invalid())?;
        let fetched = std::sync::atomic::AtomicBool::new(false);
        let result = self
            .learning_cached(&self.snapshots.learning.assessments, key, force, || async {
                fetched.store(true, std::sync::atomic::Ordering::Relaxed);
                let a = self.learning_auth(course).await?;
                protocol::assessments::list_in(&self.session, &a, course, selected).await
            })
            .await;
        if fetched.load(std::sync::atomic::Ordering::Relaxed) {
            self.learning_observe(
                course,
                &scope,
                |c| &mut c.assessments,
                outcome_failure(&result),
            );
        }
        result
    }
}
fn outcome_failure<R>(result: &Result<DataOutcome<R>, AppError>) -> Option<&AppError> {
    match result {
        Ok(outcome) => outcome.failure.as_ref(),
        Err(error) => Some(error),
    }
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> LearningCourseSource
    for SchoolClient<T, V>
{
    async fn learning_courses(
        &self,
        force: bool,
    ) -> Result<DataOutcome<Vec<LearningCourse>>, AppError> {
        let _gate = self.learning_gate.lock().await;
        self.learning_cached(
            &self.snapshots.learning.courses,
            "student".into(),
            force,
            || async {
                let a = protocol::auth(&self.session).await?;
                protocol::courses(&self.session, &a).await
            },
        )
        .await
    }
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> CourseAnnouncementSource
    for SchoolClient<T, V>
{
    async fn course_announcements(
        &self,
        course: &str,
        force: bool,
    ) -> Result<DataOutcome<Vec<CourseAnnouncement>>, AppError> {
        self.learning_announcements_in(course, None, force).await
    }
    async fn course_announcement_detail(
        &self,
        course: &str,
        id: &str,
    ) -> Result<CourseAnnouncementDetail, AppError> {
        self.learning_detail_in(course, None, id).await
    }
    async fn course_announcement_attachment(
        &self,
        course: &str,
        id: &str,
        file: &str,
    ) -> Result<LearningDownload, AppError> {
        self.learning_attachment_in(course, None, id, file).await
    }
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> CourseResourceSource
    for SchoolClient<T, V>
{
    async fn course_resources(
        &self,
        course: &str,
        folder: Option<&str>,
        page: u32,
        force: bool,
    ) -> Result<DataOutcome<CourseResourcePage>, AppError> {
        let path: Vec<String> = folder.into_iter().map(str::to_owned).collect();
        self.course_resources_at(course, &path, page, force).await
    }
    async fn course_resource_download(
        &self,
        course: &str,
        folder: Option<&str>,
        page: u32,
        id: &str,
    ) -> Result<LearningDownload, AppError> {
        let path: Vec<String> = folder.into_iter().map(str::to_owned).collect();
        self.course_resource_download_at(course, &path, page, id)
            .await
    }
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> CourseAssessmentSource
    for SchoolClient<T, V>
{
    async fn course_assessments(
        &self,
        course: &str,
        force: bool,
    ) -> Result<DataOutcome<Vec<CourseAssessment>>, AppError> {
        self.learning_assessments_in(course, None, force).await
    }
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> CourseLearningContextSource
    for SchoolClient<T, V>
{
    async fn course_learning_columns(
        &self,
        course: &str,
        force: bool,
    ) -> Result<DataOutcome<Vec<LearningColumn>>, AppError> {
        let _gate = self.learning_gate.lock().await;
        let scope = self.learning_scope()?;
        let fetched = std::sync::atomic::AtomicBool::new(false);
        let result = self
            .learning_cached(
                &self.snapshots.learning.columns,
                course.into(),
                force,
                || async {
                    fetched.store(true, std::sync::atomic::Ordering::Relaxed);
                    let a = self.learning_auth(course).await?;
                    protocol::columns(&self.session, &a, course).await
                },
            )
            .await;
        if fetched.load(std::sync::atomic::Ordering::Relaxed) {
            self.learning_observe(course, &scope, |c| &mut c.columns, outcome_failure(&result));
        }
        result
    }
    async fn course_announcements_in(
        &self,
        course: &str,
        column: &str,
        force: bool,
    ) -> Result<DataOutcome<Vec<CourseAnnouncement>>, AppError> {
        self.learning_announcements_in(course, Some(column), force)
            .await
    }
    async fn course_announcement_detail_in(
        &self,
        course: &str,
        column: &str,
        id: &str,
    ) -> Result<CourseAnnouncementDetail, AppError> {
        self.learning_detail_in(course, Some(column), id).await
    }
    async fn course_announcement_attachment_in(
        &self,
        course: &str,
        column: &str,
        id: &str,
        file: &str,
    ) -> Result<LearningDownload, AppError> {
        self.learning_attachment_in(course, Some(column), id, file)
            .await
    }
    async fn course_assessments_in(
        &self,
        course: &str,
        column: &str,
        force: bool,
    ) -> Result<DataOutcome<Vec<CourseAssessment>>, AppError> {
        self.learning_assessments_in(course, Some(column), force)
            .await
    }
    async fn course_resources_at(
        &self,
        course: &str,
        path: &[String],
        page: u32,
        force: bool,
    ) -> Result<DataOutcome<CourseResourcePage>, AppError> {
        let _gate = self.learning_gate.lock().await;
        let scope = self.learning_scope()?;
        let key = serde_json::to_string(&(course, path, page)).map_err(|_| AppError::invalid())?;
        let fetched = std::sync::atomic::AtomicBool::new(false);
        let result = self
            .learning_cached(&self.snapshots.learning.resources, key, force, || async {
                fetched.store(true, std::sync::atomic::Ordering::Relaxed);
                let a = self.learning_auth(course).await?;
                protocol::resources::page_at(&self.session, &a, course, path, page).await
            })
            .await;
        if fetched.load(std::sync::atomic::Ordering::Relaxed) {
            self.learning_observe(
                course,
                &scope,
                |c| &mut c.resources,
                outcome_failure(&result),
            );
        }
        result
    }
    async fn course_resource_download_at(
        &self,
        course: &str,
        path: &[String],
        page: u32,
        id: &str,
    ) -> Result<LearningDownload, AppError> {
        let _gate = self.learning_gate.lock().await;
        let scope = self.learning_scope()?;
        let result = self
            .learning_read(|| async {
                if id.is_empty() || id.len() > 256 {
                    return Err(AppError::invalid());
                }
                let a = self.learning_auth(course).await?;
                let listing =
                    protocol::resources::page_at(&self.session, &a, course, path, page).await?;
                let file = listing
                    .items
                    .iter()
                    .find(|r| r.id == id && r.downloadable && !r.folder)
                    .ok_or_else(AppError::invalid)?;
                let bytes = protocol::resources::download(&self.session, &a, id).await?;
                Ok(LearningDownload {
                    name: file.name.clone(),
                    bytes,
                })
            })
            .await;
        self.learning_observe(
            course,
            &scope,
            |c| &mut c.resource_download,
            result.as_ref().err(),
        );
        result
    }
    async fn course_learning_capabilities(
        &self,
        course: &str,
    ) -> Result<LearningCapabilities, AppError> {
        if course.is_empty() || course.len() > 256 {
            return Err(AppError::invalid());
        }
        let scope = self.learning_scope()?;
        let key = serde_json::to_string(&(scope, course)).map_err(|_| AppError::invalid())?;
        Ok(self
            .snapshots
            .learning
            .capabilities
            .lock()
            .get(&key)
            .cloned()
            .unwrap_or_default())
    }
}

mod persistence;

#[cfg(test)]
mod tests;
