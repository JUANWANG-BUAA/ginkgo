//! Cookie-only business-route migration. The target UC identity is verified
//! before committing; password authentication is never initiated here.
use super::*;
use crate::{
    auth::{uc, UserProfile},
    ErrorCode,
};
use std::time::{Duration, Instant};

pub(super) type VerifiedRouteHandler = dyn Fn(&str, u64, &UserProfile) -> bool + Send + Sync;

#[derive(Clone, PartialEq, Eq)]
pub(super) struct AutomaticRouteOwner {
    account: String,
    generation: u64,
}

#[derive(Default)]
pub(super) struct AutomaticRouteState {
    pub epoch: u64,
    pub webvpn_revision: u64,
    owner: Option<AutomaticRouteOwner>,
    handler: Option<Arc<VerifiedRouteHandler>>,
    failure: Option<(Instant, AppError)>,
}

impl AutomaticRouteState {
    pub fn revoke(&mut self) {
        self.epoch = self.epoch.wrapping_add(1);
        self.owner = None;
        self.failure = None;
    }
}

pub(super) fn can_migrate(
    request: &HttpRequest,
    response: &Result<HttpResponse, AppError>,
) -> bool {
    let business = url::Url::parse(&request.url).is_ok_and(|url| {
        url.scheme() == "https"
            && webvpn::should_route(url.as_str())
            && !matches!(
                url.host_str(),
                Some("sso.buaa.edu.cn" | "uc.buaa.edu.cn" | "d.buaa.edu.cn")
            )
            && !url
                .query_pairs()
                .any(|(key, _)| key.eq_ignore_ascii_case("ticket"))
    });
    request.method == HttpMethod::Get
        && business
        && match response {
            Err(error) => error.code == ErrorCode::NetworkUnreachable,
            Ok(response) => response.status == 483 || cas::is_access_policy_denied(&response.body),
        }
}

fn has_module_credentials(request: &HttpRequest) -> bool {
    request.headers.keys().any(|name| {
        ["sessionid", "authorization", "token"]
            .iter()
            .any(|credential| name.eq_ignore_ascii_case(credential))
    }) || url::Url::parse(&request.url).is_ok_and(|url| {
        url.query_pairs().any(|(key, _)| {
            ["phone", "password", "loginname"]
                .iter()
                .any(|credential| key.eq_ignore_ascii_case(credential))
        })
    })
}

impl<T: HttpTransport> Session<T> {
    pub(crate) fn set_verified_route_handler(
        &self,
        handler: impl Fn(&str, u64, &UserProfile) -> bool + Send + Sync + 'static,
    ) {
        self.automatic_route.lock().handler = Some(Arc::new(handler));
    }

    pub(crate) fn allow_automatic_business_route(&self, account: String, generation: u64) {
        let mut automatic = self.automatic_route.lock();
        let owner = Some(AutomaticRouteOwner {
            account,
            generation,
        });
        if automatic.owner != owner {
            automatic.epoch = automatic.epoch.wrapping_add(1);
        }
        automatic.owner = owner;
        automatic.failure = None;
    }

    pub(super) fn route_attempt(&self) -> (RouteMode, u64, Option<AutomaticRouteOwner>) {
        let automatic = self.automatic_route.lock();
        (self.route(), automatic.epoch, automatic.owner.clone())
    }

    /// Commit a requested preference and its owner together with the live
    /// route. A different route needs UC proof from its own existing cookies;
    /// neither the probe nor an abandoned response can mutate the live jars.
    pub(crate) async fn transition_saved_route<R>(
        &self,
        source: RouteMode,
        target: RouteMode,
        account: &str,
        publish: impl FnOnce(Option<UserProfile>) -> Result<(R, Option<u64>), AppError> + Send,
    ) -> Result<R, AppError> {
        let requested_epoch = self.automatic_route.lock().epoch;
        let _gate = self.automatic_route_gate.lock().await;
        let live_jar = match target {
            RouteMode::Direct => &self.direct_jar,
            RouteMode::WebVpn => &self.webvpn_jar,
            RouteMode::Automatic => return Err(AppError::invalid()),
        };
        let (epoch, candidate) = {
            let automatic = self.automatic_route.lock();
            if automatic.epoch != requested_epoch || self.route() != source {
                return Err(AppError::module_auth_required());
            }
            let candidate = (source != target).then(|| live_jar.lock().clone());
            (automatic.epoch, candidate)
        };
        let proof = if let Some(mut candidate) = candidate {
            let request = uc::status_request();
            let url = if target == RouteMode::WebVpn {
                webvpn::wrap(&request.url).map_err(|_| AppError::invalid())?
            } else {
                request.url.clone()
            };
            if candidate.header_for(&url, CookieJar::now_ms()).is_none() {
                return Err(AppError::module_auth_required());
            }
            let revision = candidate.revision();
            let staged = Mutex::new(candidate);
            let response = self
                .send_routed_using(request, target, epoch, Some(&staged))
                .await?;
            let profile = uc::validate_response(response).map_err(|error| {
                if error.code == ErrorCode::SessionExpired {
                    AppError::module_auth_required()
                } else {
                    error
                }
            })?;
            if !profile.school_id.eq_ignore_ascii_case(account) {
                return Err(AppError::module_auth_required());
            }
            Some((profile, staged, revision))
        } else {
            None // The current route was already verified for this owner.
        };
        let (result, committed_epoch) = {
            let mut automatic = self.automatic_route.lock();
            let mut route = lock_value(&self.route);
            if automatic.epoch != epoch || *route != source {
                return Err(AppError::module_auth_required());
            }
            let (profile, staged) = if let Some((profile, staged, revision)) = proof {
                if live_jar.lock().revision() != revision {
                    return Err(AppError::module_auth_required());
                }
                (Some(profile), Some(staged))
            } else {
                (None, None)
            };
            // Same lock order as verified_business_fallback. The callback checks
            // the identity generation before publishing and must not re-enter Session.
            let (result, automatic_generation) = publish(profile)?;
            if let Some(staged) = staged {
                std::mem::swap(&mut *live_jar.lock(), &mut *staged.lock());
                if target == RouteMode::WebVpn {
                    automatic.webvpn_revision = automatic.webvpn_revision.wrapping_add(1);
                }
            }
            *route = target;
            automatic.revoke();
            automatic.owner = automatic_generation.map(|generation| AutomaticRouteOwner {
                account: account.to_owned(),
                generation,
            });
            (result, automatic.epoch)
        };
        if target != source {
            // Serialize with earlier cookie writes. The persistor reads the
            // current owner and its original lifetime, never a cached secret.
            let gate = Arc::clone(&self.cookie_persist_gate).lock_owned().await;
            let write = self
                .cookie_persistor
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner)
                .as_ref()
                .and_then(|persist| persist(self.cookie_snapshot()));
            if let Some(write) = write {
                // A bridge deadline may drop the caller but cannot cancel a
                // vault write already running on a blocking worker. The task
                // holds the gate until that worker actually finishes.
                tokio::spawn(async move {
                    let _gate = gate;
                    write.await;
                })
                .await
                .map_err(|_| AppError::credential_store())?;
            }
            if self.automatic_route.lock().epoch != committed_epoch {
                return Err(AppError::module_auth_required());
            }
        }
        Ok(result)
    }

    /// Logout revokes in memory first. Drain a save already handed to the
    /// vault before deleting the durable record, so it cannot reappear later.
    pub(crate) async fn drain_cookie_writes(&self) {
        drop(self.cookie_persist_gate.lock().await);
    }

    pub(super) async fn verified_business_fallback(
        &self,
        request: HttpRequest,
        attempted_epoch: u64,
        owner: AutomaticRouteOwner,
    ) -> Result<HttpResponse, AppError> {
        let _gate = self.automatic_route_gate.lock().await;
        let epoch = {
            let automatic = self.automatic_route.lock();
            if automatic.owner.as_ref() != Some(&owner) {
                return Err(AppError::module_auth_required());
            }
            if self.route() == RouteMode::WebVpn {
                None // A peer already verified this owner's gateway session.
            } else {
                if automatic.epoch != attempted_epoch || self.route() != RouteMode::Direct {
                    return Err(AppError::module_auth_required());
                }
                if let Some((at, error)) = &automatic.failure {
                    if at.elapsed() < Duration::from_secs(60) {
                        return Err(error.clone());
                    }
                }
                Some(automatic.epoch)
            }
        };
        if let Some(epoch) = epoch {
            let (probe_jar, revision) = {
                let automatic = self.automatic_route.lock();
                (
                    Mutex::new(self.webvpn_jar.lock().clone()),
                    automatic.webvpn_revision,
                )
            };
            let result = self
                .send_routed_using(
                    uc::status_request(),
                    RouteMode::WebVpn,
                    epoch,
                    Some(&probe_jar),
                )
                .await
                .and_then(uc::validate_response);
            let result = result
                .and_then(|profile| {
                    if profile.school_id.eq_ignore_ascii_case(&owner.account) {
                        Ok(profile)
                    } else {
                        Err(AppError::module_auth_required())
                    }
                })
                .map_err(|error| {
                    if error.code == ErrorCode::SessionExpired {
                        AppError::with_detail(
                            ErrorCode::ModuleAuthRequired,
                            "webvpn_route_login_required",
                        )
                    } else {
                        error
                    }
                });
            {
                let mut automatic = self.automatic_route.lock();
                if automatic.epoch != epoch || automatic.owner.as_ref() != Some(&owner) {
                    return Err(AppError::module_auth_required());
                }
                let profile = match result {
                    Ok(profile) => profile,
                    Err(error) => {
                        automatic.failure = Some((Instant::now(), error.clone()));
                        return Err(error);
                    }
                };
                let mut route = lock_value(&self.route);
                if automatic.webvpn_revision != revision
                    || *route != RouteMode::Direct
                    || !automatic
                        .handler
                        .as_ref()
                        .is_some_and(|handler| handler(&owner.account, owner.generation, &profile))
                {
                    return Err(AppError::module_auth_required());
                }
                *route = RouteMode::WebVpn;
                *self.webvpn_jar.lock() = probe_jar.lock().clone();
                automatic.webvpn_revision = automatic.webvpn_revision.wrapping_add(1);
                automatic.epoch = automatic.epoch.wrapping_add(1);
                automatic.failure = None;
            }
            self.persist_cookie_update().await;
        }
        // One safe read on the committed route; no recursive fallback.
        let epoch = {
            let automatic = self.automatic_route.lock();
            if automatic.owner.as_ref() != Some(&owner) || self.route() != RouteMode::WebVpn {
                return Err(AppError::module_auth_required());
            }
            automatic.epoch
        };
        // The old route's app login handoff or token must be rebuilt by its
        // service. Cookie verification does not make module tokens portable.
        if has_module_credentials(&request) {
            return Err(AppError::with_detail(
                ErrorCode::ModuleAuthRequired,
                "route_changed",
            ));
        }
        self.send_routed_at(request, RouteMode::WebVpn, epoch).await
    }
}
