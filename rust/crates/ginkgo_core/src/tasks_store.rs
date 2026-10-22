//! Private application-support storage; hashed account namespace, atomic replacement.
use crate::{
    features::tasks::{self, Document, Task},
    AppError,
};
use sha1::{Digest, Sha1};
use std::{
    path::{Path, PathBuf},
    sync::Mutex,
};
static STORAGE: Mutex<()> = Mutex::new(());
fn path(root: &Path, account: &str) -> PathBuf {
    root.join(format!("tasks-{:x}.json", Sha1::digest(account.as_bytes())))
}
pub fn transact(
    root: &Path,
    account: &str,
    change: impl FnOnce(&mut Vec<Task>) -> Result<(), AppError>,
) -> Result<Vec<Task>, AppError> {
    let _lock = STORAGE.lock().map_err(|_| AppError::unavailable())?;
    std::fs::create_dir_all(root).map_err(|_| AppError::unavailable())?;
    let file = path(root, account);
    let mut tasks = match std::fs::read(&file) {
        Ok(bytes) => tasks::parse_bytes(&bytes)?,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => Vec::new(),
        Err(_) => return Err(AppError::unavailable()),
    };
    let previous = tasks.clone();
    change(&mut tasks)?;
    if tasks != previous {
        let bytes = serde_json::to_vec(&Document {
            // Valid v1 documents migrate only after a successful local change.
            version: 2,
            tasks: tasks.clone(),
        })
        .map_err(|_| AppError::changed())?;
        let temporary = file.with_extension("tmp");
        let mut output = std::fs::File::create(&temporary).map_err(|_| AppError::unavailable())?;
        use std::io::Write;
        output
            .write_all(&bytes)
            .and_then(|_| output.sync_all())
            .map_err(|_| AppError::unavailable())?;
        std::fs::rename(&temporary, &file).map_err(|_| AppError::unavailable())?;
    }
    tasks.sort_by(|a, b| {
        a.completed
            .cmp(&b.completed)
            .then_with(|| tasks::compare_due(&a.due, &b.due))
            .then(a.id.cmp(&b.id))
    });
    Ok(tasks)
}
