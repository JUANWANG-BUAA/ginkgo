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
#[derive(Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub(super) struct Record {
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
/// One validated journal row, safe to move across threads.
pub(super) struct Recovered {
    pub handle: String,
    pub assignment: String,
    pub course: String,
    pub file: String,
    pub name: String,
    pub size: u64,
    pub baseline: u32,
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
/// Disk phase of [`configure`]: validate the directory without holding a lock.
pub(super) fn prepare_root(root: &str) -> Result<PathBuf, AppError> {
    let path = Path::new(root);
    if !path.is_absolute() {
        return Err(AppError::invalid());
    }
    private_directory(path)?;
    Ok(path.to_path_buf())
}

/// Memory phase of [`configure`]: adopt an already-validated root.
pub(super) fn adopt_root(files: &mut HomeworkFiles, path: &Path) -> Result<(), AppError> {
    match &files.root {
        Some(existing) if existing != path => Err(AppError::invalid()),
        _ => {
            files.root = Some(path.to_path_buf());
            Ok(())
        }
    }
}
/// The configured journal root, copied so callers can do disk work unlocked.
pub(super) fn root_of(files: &HomeworkFiles) -> Result<PathBuf, AppError> {
    Ok(root(files)?.to_path_buf())
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
/// Read and validate this account's restart journal. **Disk only**: no lock is
/// held, so it may run on a blocking thread. Apply the result with
/// [`apply_restore`].
pub(super) fn read_records(root: &Path, owner: &(String, u64)) -> Result<Vec<Recovered>, AppError> {
    let directory = account_directory(root, &owner.0)?;
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
        recovered.push(Recovered {
            handle: record.handle,
            assignment: record.assignment,
            course: record.course,
            file: record.file,
            name: record.name,
            size: record.size,
            baseline: record.baseline,
        });
    }
    Ok(recovered)
}

/// Merge journal records into memory. **Memory only**: callers hold the lock
/// for exactly this step and nothing else.
pub(super) fn apply_restore(
    files: &mut HomeworkFiles,
    owner: &(String, u64),
    recovered: Vec<Recovered>,
) -> Result<(), AppError> {
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
/// Snapshot one upload into a durable record. **Memory only**, cheap.
pub(super) fn record(
    files: &HomeworkFiles,
    handle: &str,
    baseline: u32,
) -> Result<Record, AppError> {
    let upload = files.uploads.get(handle).ok_or_else(AppError::invalid)?;
    Ok(Record {
        version: 1,
        account_digest: digest(&upload.owner.0),
        handle: handle.into(),
        assignment: upload.assignment.clone(),
        course: upload.course.clone(),
        file: upload.file.clone(),
        name: upload.name.clone(),
        size: upload.size,
        baseline,
    })
}

/// Persist before sending. A partial write remains as a fail-closed guard.
/// **Disk only**: callers do not hold the lock.
pub(super) fn write_record(root: &Path, account: &str, record: &Record) -> Result<(), AppError> {
    let path = path(root, account, &record.assignment)?;
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
/// The facts `clear` needs, snapshotted under the lock so the deletion itself
/// can run outside it.
pub(super) fn clear_target(
    files: &HomeworkFiles,
    handle: &str,
) -> Result<(PathBuf, String, String), AppError> {
    let upload = files.uploads.get(handle).ok_or_else(AppError::invalid)?;
    Ok((
        path(root(files)?, &upload.owner.0, &upload.assignment)?,
        upload.file.clone(),
        upload.assignment.clone(),
    ))
}

/// Delete only the exact positive-verified record, never acknowledge a negative/unknown read.
/// **Disk only**: callers do not hold the lock.
pub(super) fn clear_record(
    path: &Path,
    handle: &str,
    file: &str,
    assignment: &str,
) -> Result<(), AppError> {
    let metadata = fs::symlink_metadata(path).map_err(|_| AppError::unavailable())?;
    if !metadata.is_file() || metadata.file_type().is_symlink() || metadata.len() > LIMIT {
        return Err(AppError::changed());
    }
    let mut bytes = Vec::new();
    fs::File::open(path)
        .and_then(|file| file.take(LIMIT + 1).read_to_end(&mut bytes))
        .map_err(|_| AppError::unavailable())?;
    let record: Record = serde_json::from_slice(&bytes).map_err(|_| AppError::changed())?;
    if record.handle != handle || record.file != file || record.assignment != assignment {
        return Err(AppError::changed());
    }
    fs::remove_file(path).map_err(|_| AppError::unavailable())?;
    sync_directory(path.parent().ok_or_else(AppError::invalid)?)
}

#[cfg(test)]
mod phase_tests {
    //! The disk phase must work without the journal lock: that split is what
    //! keeps a directory fsync off the async worker's critical section.
    use super::*;

    fn scratch() -> PathBuf {
        let root = std::env::temp_dir().join(format!(
            "ginkgo-journal-phase-{:032x}",
            rand::random::<u128>()
        ));
        fs::create_dir_all(&root).unwrap();
        fs::canonicalize(&root).unwrap()
    }

    fn row(account: &str, handle: &str) -> Record {
        Record {
            version: 1,
            account_digest: digest(account),
            handle: handle.into(),
            assignment: "work-a".into(),
            course: "course-a".into(),
            file: "file-a".into(),
            name: "answer.pdf".into(),
            size: 3,
            baseline: 1,
        }
    }

    #[test]
    fn the_disk_phase_runs_without_the_journal_lock() {
        let root = scratch();
        let owner = ("sy2501001".to_owned(), 7_u64);

        // prepare_root validates the directory with no shared state at all.
        let prepared = prepare_root(root.to_str().unwrap()).unwrap();
        assert_eq!(prepared, root);

        // write_record / read_records take a plain path, never HomeworkFiles.
        let record = row(&owner.0, &"a".repeat(64));
        write_record(&prepared, &owner.0, &record).unwrap();
        let rows = read_records(&prepared, &owner).unwrap();
        assert_eq!(rows.len(), 1);
        assert_eq!(rows[0].handle, record.handle);
        assert_eq!(rows[0].assignment, "work-a");

        // A second identity sees nothing, and nothing of the first is lost.
        let other = ("sy2501002".to_owned(), 8_u64);
        assert!(read_records(&prepared, &other).unwrap().is_empty());
        assert_eq!(read_records(&prepared, &owner).unwrap().len(), 1);

        // clear_record deletes exactly the verified row, also without the lock.
        let (path, file, assignment) = (
            prepared
                .join(format!("homework-pending-{}", digest(&owner.0)))
                .join(format!("{}.json", digest("work-a"))),
            "file-a".to_owned(),
            "work-a".to_owned(),
        );
        clear_record(&path, &record.handle, &file, &assignment).unwrap();
        assert!(read_records(&prepared, &owner).unwrap().is_empty());

        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn a_relative_root_is_rejected_before_any_lock() {
        assert!(prepare_root("relative/path").is_err());
        assert!(prepare_root("").is_err());
    }

    #[cfg(unix)]
    #[test]
    fn a_symlinked_root_is_rejected_before_any_lock() {
        let root = scratch();
        let link = root.join("link");
        std::os::unix::fs::symlink(&root, &link).unwrap();
        assert!(prepare_root(link.to_str().unwrap()).is_err());
        fs::remove_dir_all(root).unwrap();
    }
}
