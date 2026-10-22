//! Minimal restart guard, not a booking cache. Hashing namespaces accounts; it is not encryption.
//! The synchronous lock covers filesystem transactions only, never an upstream await.
//! The FFI's global write gate must serialize complete workflows. create_new prevents a
//! second initial writer, but submit/ack/terminal cleanup are NOT multi-process transactions.
use crate::AppError;
use serde::Deserialize;
use sha1::{Digest, Sha1};
use std::{
    fs::{self, OpenOptions},
    io::{Read, Write},
    path::{Path, PathBuf},
    sync::Mutex,
};

static STORAGE: Mutex<()> = Mutex::new(());
const MARKER: &[u8] = br#"{"version":1,"pending":true}"#;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum Pending {
    Missing,
    Present,
    /// Malformed, unreadable, or not a regular file: never overwrite or dispatch a write.
    Locked,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
struct Marker {
    version: u8,
    pending: bool,
}

pub(crate) struct PendingStore {
    file: PathBuf,
}

impl PendingStore {
    pub(crate) fn new(root: &Path, account: &str) -> Result<Self, AppError> {
        if !root.is_absolute() || account.trim().is_empty() {
            return Err(AppError::invalid());
        }
        Ok(Self {
            file: root.join(format!(
                "cgyy-pending-{:x}.json",
                Sha1::digest(account.as_bytes())
            )),
        })
    }

    pub(crate) fn inspect(&self) -> Result<Pending, AppError> {
        let _lock = STORAGE.lock().map_err(|_| AppError::unavailable())?;
        Ok(self.inspect_unlocked())
    }

    fn inspect_unlocked(&self) -> Pending {
        match fs::symlink_metadata(&self.file) {
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Pending::Missing,
            Ok(metadata) if metadata.is_file() && metadata.len() <= 256 => {}
            _ => return Pending::Locked,
        }
        // Bound reads even if another process changes the file after metadata was read.
        let mut bytes = Vec::new();
        let read =
            fs::File::open(&self.file).and_then(|file| file.take(257).read_to_end(&mut bytes));
        if read.is_err() {
            return Pending::Locked;
        }
        match serde_json::from_slice::<Marker>(&bytes) {
            Ok(marker) if marker.version == 1 && marker.pending => Pending::Present,
            _ => Pending::Locked,
        }
    }

    /// Returns true only for the caller that created AND flushed the initial marker.
    /// Failed/partial creation stays on disk and locks future writes rather than being repaired.
    pub(crate) fn create(&self) -> Result<bool, AppError> {
        let _lock = STORAGE.lock().map_err(|_| AppError::unavailable())?;
        if self.inspect_unlocked() != Pending::Missing {
            return Ok(false);
        }
        let parent = self.file.parent().ok_or_else(AppError::invalid)?;
        fs::create_dir_all(parent).map_err(|_| AppError::unavailable())?;
        let mut options = OpenOptions::new();
        options.write(true).create_new(true);
        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt;
            options.mode(0o600);
        }
        let mut output = match options.open(&self.file) {
            Ok(file) => file,
            Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => return Ok(false),
            Err(_) => return Err(AppError::unavailable()),
        };
        output
            .write_all(MARKER)
            .and_then(|_| output.flush())
            .and_then(|_| output.sync_all())
            .map_err(|_| AppError::unavailable())?;
        // Persist the new directory entry on platforms supporting directory fsync.
        #[cfg(unix)]
        fs::File::open(parent)
            .and_then(|directory| directory.sync_all())
            .map_err(|_| AppError::unavailable())?;
        Ok(true)
    }

    /// Only after a proven terminal mutation or upstream-validated acknowledgment.
    /// In particular acknowledgment may remove an unreadable/malformed regular marker.
    pub(crate) fn clear(&self) -> Result<(), AppError> {
        let _lock = STORAGE.lock().map_err(|_| AppError::unavailable())?;
        match fs::remove_file(&self.file) {
            Ok(()) => Ok(()),
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
            Err(_) => Err(AppError::unavailable()),
        }
    }
}
