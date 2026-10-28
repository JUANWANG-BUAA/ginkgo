//! Module-local read-only evidence. Available means eligible candidate, not live write acceptance.
use super::*;
fn evidence(
    key: &str,
    state: HomeworkCapabilityState,
    reason: &str,
    source: &str,
) -> HomeworkCapabilityEvidence {
    HomeworkCapabilityEvidence {
        capability: key.into(),
        state,
        reason: reason.into(),
        evidence: source.into(),
    }
}
fn error_state(error: &AppError) -> HomeworkCapabilityState {
    match error.code {
        ErrorCode::SessionExpired | ErrorCode::InvalidCredentials | ErrorCode::CaptchaRequired => {
            HomeworkCapabilityState::AuthRequired
        }
        ErrorCode::ChangedResponse => HomeworkCapabilityState::ProtocolChanged,
        ErrorCode::ServiceUnavailable => HomeworkCapabilityState::TempUnavailable,
        _ => HomeworkCapabilityState::Unknown,
    }
}
impl<T: HttpTransport + Send + Sync, V: CredentialVault> SchoolClient<T, V> {
    pub(super) async fn diagnose_homework(&self, id: &str) -> Vec<HomeworkCapabilityEvidence> {
        let _gate = self.homework_file_gate.lock().await;
        let mut entries = vec![
            evidence(
                "textSubmit",
                HomeworkCapabilityState::Unknown,
                "已定位文本提交字段；尚缺后端正文处理和写后回查验证，未开放",
                "officialStaticFormOnly",
            ),
            evidence(
                "urlSubmit",
                HomeworkCapabilityState::Unknown,
                "已定位链接提交字段；尚缺后端链接处理和写后回查验证，未开放",
                "officialStaticFormOnly",
            ),
            evidence(
                "groupSubmit",
                HomeworkCapabilityState::Unsupported,
                "小组归属及代表成员提交协议未实现，请前往官网",
                "clientUnsupported",
            ),
        ];
        let result = async {
            let owner = self.homework_owner()?;
            let context = self
                .homework_context(id.strip_prefix("spoc:").unwrap_or(id))
                .await?;
            self.check_homework_owner(&owner)?;
            self.restore_journal(&owner).await?;
            let pending = {
                let files = self.homework_files.lock();
                files.uploads.values().any(|u| {
                    u.owner == owner
                        && u.assignment == id.strip_prefix("spoc:").unwrap_or(id)
                        && u.state == State::Sent
                })
            };
            self.check_homework_owner(&owner)?;
            Ok::<_, AppError>((context, pending))
        }
        .await;
        match result {
            Ok((context, pending)) => {
                let metadata_known = context.assignment.get("zylx").is_some()
                    && context.assignment.get("sfzysjn").is_some()
                    && context.assignment.get("bhtjlx").is_some()
                    && context.workspace.submission_limit.is_some()
                    && context.workspace.submitted_count.is_some();
                let state = if pending || !metadata_known {
                    HomeworkCapabilityState::Unknown
                } else if context.workspace.can_submit_file {
                    HomeworkCapabilityState::Available
                } else {
                    HomeworkCapabilityState::Unsupported
                };
                let reason = if pending {
                    "此作业已有待核实提交；仅允许回查，禁止再次上传或提交"
                } else {
                    context.workspace.blocked_reason.as_deref().unwrap_or(
                        "当前个人文件作业资格已复读；上传与提交仍需用户操作，真实写入尚未验收",
                    )
                };
                for key in ["fileUpload", "fileSubmit"] {
                    entries.push(evidence(
                        key,
                        state,
                        reason,
                        "officialStaticCandidateAndCurrentRead",
                    ));
                }
                entries.push(evidence(
                    "fileReconcile",
                    if context.student_owned {
                        HomeworkCapabilityState::Available
                    } else {
                        HomeworkCapabilityState::Unsupported
                    },
                    "仅回查当前账号的持久待核实记录；文件ID、方式和次数增加均匹配才确认",
                    "currentReadAndPrivateJournal",
                ));
            }
            Err(error) => {
                let reason = if error.detail.as_deref() == Some("homework_recovery_unconfigured") {
                    "本机待核实保护目录未初始化；不能上传或提交"
                } else {
                    "当前作业能力无法核实；可能需要登录、恢复网络或检查响应及本机保护记录"
                };
                for key in ["fileUpload", "fileSubmit", "fileReconcile"] {
                    let state = if error.detail.as_deref() == Some("homework_recovery_unconfigured")
                    {
                        HomeworkCapabilityState::Unknown
                    } else {
                        error_state(&error)
                    };
                    entries.push(evidence(key, state, reason, "boundedReadFailure"));
                }
            }
        }
        entries
    }
}
