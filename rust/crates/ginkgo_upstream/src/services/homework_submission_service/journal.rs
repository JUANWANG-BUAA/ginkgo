//! Private restart journal, not an upload cache. Only uncertain final writes are retained.
//! No credentials, file bytes or submission text. A malformed record locks new writes.
//! Application workflows are process-serialized; create_new also prevents duplicate dispatch
//! from separate processes. This is not a cross-process cache or general document store.
use super::*;
use serde::{Deserialize, Serialize};
use sha1::{Digest, Sha1};
use std::{
    fs::{self, OpenOptions},
    io::{Read, Write},
    path::{Path, PathBuf},
};
const LIMIT: u64 = 16 * 1024;
#[derive(Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
struct Record {
    version: u8,
    account_digest: String,
    handle: String,
    assignment: String,
    course: String,
    file: String,
    name: String,
    size: u64,
    baseline: u32,
}
fn digest(value: &str) -> String {
    format!("{:x}", Sha1::digest(value.as_bytes()))
}
fn private_directory(path: &Path) -> Result<(), AppError> {
    let metadata = fs::symlink_metadata(path).map_err(|_| AppError::unavailable())?;
    if !metadata.is_dir() || metadata.file_type().is_symlink() {
        return Err(AppError::invalid());
    }
    // Requiring canonical spelling rejects symlinked parent components too.
    if fs::canonicalize(path).map_err(|_| AppError::unavailable())? != path {
        return Err(AppError::invalid());
    }
    Ok(())
}
fn account_directory(root: &Path, account: &str) -> Result<PathBuf, AppError> {
    private_directory(root)?;
    let path = root.join(format!("homework-pending-{}", digest(account)));
    match fs::create_dir(&path) {
        Ok(()) => {
            #[cfg(unix)]
            {
                use std::os::unix::fs::PermissionsExt;
                fs::set_permissions(&path, fs::Permissions::from_mode(0o700))
                    .map_err(|_| AppError::unavailable())?;
            }
            sync_directory(root)?;
        }
        Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {}
        Err(_) => return Err(AppError::unavailable()),
    }
    private_directory(&path)?;
    Ok(path)
}
fn sync_directory(path: &Path) -> Result<(), AppError> {
    #[cfg(unix)]
    fs::File::open(path)
        .and_then(|directory| directory.sync_all())
        .map_err(|_| AppError::unavailable())?;
    #[cfg(not(unix))]
    let _ = path;
    Ok(())
}
pub(super) fn configure(files: &mut HomeworkFiles, root: &str) -> Result<(), AppError> {
    let path = Path::new(root);
    if !path.is_absolute() {
        return Err(AppError::invalid());
    }
    private_directory(path)?;
    match &files.root {
        Some(existing) if existing != path => Err(AppError::invalid()),
        _ => {
            files.root = Some(path.into());
            Ok(())
        }
    }
}
fn root(files: &HomeworkFiles) -> Result<&Path, AppError> {
    files.root.as_deref().ok_or_else(|| {
        AppError::with_detail(
            ErrorCode::ServiceUnavailable,
            "homework_recovery_unconfigured",
        )
    })
}
fn path(root: &Path, account: &str, assignment: &str) -> Result<PathBuf, AppError> {
    Ok(account_directory(root, account)?.join(format!("{}.json", digest(assignment))))
}
fn valid_id(value: &str) -> bool {
    !value.trim().is_empty() && value.len() <= 256 && !value.chars().any(char::is_control)
}
/// Rehydrate only Sent records. Ready receipts deliberately expire with process/identity.
/// Recovered handles permit read-only reconciliation by the same account at its new generation.
pub(super) fn restore(files: &mut HomeworkFiles, owner: &(String, u64)) -> Result<(), AppError> {
    let directory = account_directory(root(files)?, &owner.0)?;
    let mut recovered = Vec::new();
    for (index, entry) in fs::read_dir(&directory)
        .map_err(|_| AppError::unavailable())?
        .enumerate()
    {
        if index >= 256 {
            return Err(AppError::changed());
        }
        let path = entry.map_err(|_| AppError::unavailable())?.path();
        let metadata = fs::symlink_metadata(&path).map_err(|_| AppError::unavailable())?;
        if !metadata.is_file() || metadata.file_type().is_symlink() || metadata.len() > LIMIT {
            return Err(AppError::changed());
        }
        let mut bytes = Vec::new();
        fs::File::open(&path)
            .and_then(|file| file.take(LIMIT + 1).read_to_end(&mut bytes))
            .map_err(|_| AppError::unavailable())?;
        let record: Record = serde_json::from_slice(&bytes).map_err(|_| AppError::changed())?;
        if record.version != 1
            || record.account_digest != digest(&owner.0)
            || !valid_id(&record.assignment)
            || !valid_id(&record.course)
            || !valid_id(&record.file)
            || record.handle.len() != 64
            || !record.handle.bytes().all(|c| c.is_ascii_hexdigit())
            || record.size > HOMEWORK_FILE_LIMIT as u64
            || validate_homework_file(&record.name, record.size as usize).is_err()
            || path.file_name().and_then(|v| v.to_str())
                != Some(format!("{}.json", digest(&record.assignment)).as_str())
        {
            return Err(AppError::changed());
        }
        recovered.push(record);
    }
    // Do not clear another identity's durable guard; disk remains authoritative.
    files.uploads.retain(|_, u| u.owner == *owner);
    for record in recovered {
        let existing = files.uploads.get(&record.handle);
        if existing.is_some_and(|u| {
            u.assignment != record.assignment || u.file != record.file || u.state == State::Ready
        }) {
            return Err(AppError::changed());
        }
        if existing.is_some() {
            continue;
        }
        files.uploads.insert(
            record.handle,
            Upload {
                owner: owner.clone(),
                assignment: record.assignment,
                course: record.course,
                file: record.file,
                name: record.name,
                size: record.size,
                created: Instant::now(),
                state: State::Sent,
                baseline: record.baseline,
            },
        );
    }
    Ok(())
}
/// Persist before sending. A partial write remains as a fail-closed guard.
pub(super) fn create(files: &HomeworkFiles, handle: &str, baseline: u32) -> Result<(), AppError> {
    let upload = files.uploads.get(handle).ok_or_else(AppError::invalid)?;
    let record = Record {
        version: 1,
        account_digest: digest(&upload.owner.0),
        handle: handle.into(),
        assignment: upload.assignment.clone(),
        course: upload.course.clone(),
        file: upload.file.clone(),
        name: upload.name.clone(),
        size: upload.size,
        baseline,
    };
    let path = path(root(files)?, &upload.owner.0, &upload.assignment)?;
    let mut options = OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    let bytes = serde_json::to_vec(&record).map_err(|_| AppError::invalid())?;
    let mut file = options.open(&path).map_err(|_| AppError::unavailable())?;
    file.write_all(&bytes)
        .and_then(|_| file.sync_all())
        .map_err(|_| AppError::unavailable())?;
    sync_directory(path.parent().ok_or_else(AppError::invalid)?)
}
/// Delete only the exact positive-verified record, never acknowledge a negative/unknown read.
pub(super) fn clear(files: &HomeworkFiles, handle: &str) -> Result<(), AppError> {
    let upload = files.uploads.get(handle).ok_or_else(AppError::invalid)?;
    let path = path(root(files)?, &upload.owner.0, &upload.assignment)?;
    let metadata = fs::symlink_metadata(&path).map_err(|_| AppError::unavailable())?;
    if !metadata.is_file() || metadata.file_type().is_symlink() || metadata.len() > LIMIT {
        return Err(AppError::changed());
    }
    let mut bytes = Vec::new();
    fs::File::open(&path)
        .and_then(|file| file.take(LIMIT + 1).read_to_end(&mut bytes))
        .map_err(|_| AppError::unavailable())?;
    let record: Record = serde_json::from_slice(&bytes).map_err(|_| AppError::changed())?;
    if record.handle != handle
        || record.file != upload.file
        || record.assignment != upload.assignment
    {
        return Err(AppError::changed());
    }
    fs::remove_file(&path).map_err(|_| AppError::unavailable())?;
    sync_directory(path.parent().ok_or_else(AppError::invalid)?)
}
