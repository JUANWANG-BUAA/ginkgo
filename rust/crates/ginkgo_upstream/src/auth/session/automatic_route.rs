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
