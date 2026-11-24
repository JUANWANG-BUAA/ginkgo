//! On-demand portal metrics & campus network traffic service: memory-only, no disk persistence.
use super::{session_service::SchoolClient, AppError};
use crate::{
    adapters::network_account_http, auth::CredentialVault, foundation::http::HttpTransport,
};
use ginkgo_domain::{features::network_account::NetworkAccountReport, ports::NetworkAccountSource};

impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    async fn read_portal_with_recovery(
        &self,
        owner: &super::session_service::AccountOwner,
    ) -> Result<network_account_http::PortalMetricsSnapshot, AppError> {
        let first = network_account_http::fetch_portal_metrics(&self.session, || {
            self.check_account_owner(owner)
        })
        .await;
        match first {
            Err(err) if err.detail.as_deref() == Some("webvpn_login_required") => {
                self.ensure_webvpn_session().await?;
                self.check_account_owner(owner)?;
                network_account_http::fetch_portal_metrics(&self.session, || {
                    self.check_account_owner(owner)
                })
                .await
            }
            Err(err) if err.detail.is_none() && err.code == crate::ErrorCode::SessionExpired => {
                self.silent_login().await?;
                self.check_account_owner(owner)?;
                network_account_http::fetch_portal_metrics(&self.session, || {
                    self.check_account_owner(owner)
                })
                .await
            }
            other => other,
        }
    }

    async fn read_traffic_with_recovery(
        &self,
        owner: &super::session_service::AccountOwner,
    ) -> Result<Vec<ginkgo_domain::features::network_account::NetworkTrafficProduct>, AppError>
    {
        let first =
            network_account_http::fetch_traffic(&self.session, || self.check_account_owner(owner))
                .await;
        match first {
            Err(err) if err.detail.as_deref() == Some("webvpn_login_required") => {
                self.ensure_webvpn_session().await?;
                self.check_account_owner(owner)?;
                network_account_http::fetch_traffic(&self.session, || {
                    self.check_account_owner(owner)
                })
                .await
            }
            Err(err) if err.detail.is_none() && err.code == crate::ErrorCode::SessionExpired => {
                self.silent_login().await?;
                self.check_account_owner(owner)?;
                network_account_http::fetch_traffic(&self.session, || {
                    self.check_account_owner(owner)
                })
                .await
            }
            other => other,
        }
    }
}

impl<T: HttpTransport + Send + Sync, V: CredentialVault> NetworkAccountSource
    for SchoolClient<T, V>
{
    async fn network_account(&self) -> Result<NetworkAccountReport, AppError> {
        let owner = self.account_owner()?;
        let portal_res = self.read_portal_with_recovery(&owner).await;
        self.check_account_owner(&owner)?;
        let traffic_res = self.read_traffic_with_recovery(&owner).await;
        self.check_account_owner(&owner)?;

        match (portal_res, traffic_res) {
            (Err(portal_err), Err(traffic_err)) => {
                if portal_err.code == crate::ErrorCode::ServiceUnavailable
                    && traffic_err.code != crate::ErrorCode::ServiceUnavailable
                {
                    Err(traffic_err)
                } else {
                    Err(portal_err)
                }
            }
            (Ok(portal), Ok(traffic_products)) => Ok(NetworkAccountReport {
                net_fee_minor: portal.net_fee_minor,
                net_fee_failure: portal.net_fee_failure,
                unreturned_books: portal.unreturned_books,
                unread_mail: portal.unread_mail,
                cloud_drive_free: portal.cloud_drive_free,
                portal_failure: None,
                traffic_products,
                traffic_failure: None,
                fetched_at: super::cache::now_shanghai(),
            }),
            (Ok(portal), Err(traffic_err)) => Ok(NetworkAccountReport {
                net_fee_minor: portal.net_fee_minor,
                net_fee_failure: portal.net_fee_failure,
                unreturned_books: portal.unreturned_books,
                unread_mail: portal.unread_mail,
                cloud_drive_free: portal.cloud_drive_free,
                portal_failure: None,
                traffic_products: Vec::new(),
                traffic_failure: Some(traffic_err.code),
                fetched_at: super::cache::now_shanghai(),
            }),
            (Err(portal_err), Ok(traffic_products)) => {
                let code = portal_err.code;
                Ok(NetworkAccountReport {
                    net_fee_minor: None,
                    net_fee_failure: Some(code.clone()),
                    unreturned_books: None,
                    unread_mail: None,
                    cloud_drive_free: None,
                    portal_failure: Some(code),
                    traffic_products,
                    traffic_failure: None,
                    fetched_at: super::cache::now_shanghai(),
                })
            }
        }
    }
}
