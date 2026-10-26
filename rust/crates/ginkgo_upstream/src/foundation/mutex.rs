//! Short-lived locks for disposable in-memory state.
//!
//! A panic may interrupt a compound update. Recovery keeps the value that was
//! under the lock instead of replacing it with a safe default: this lock
//! guards the session `Identity` (the authenticated flag, the session token
//! and the account generation), the read snapshots and the CGYY safety
//! journal. Resetting those to their defaults would silently sign the user
//! out and drop their state without any trace.
//!
//! Recovery is therefore observable rather than silent:
//!
//! * the guard reports whether it was handed a poisoned lock,
//! * every mutex counts its own recoveries,
//! * the crate counts every recovery so a caller that only holds a service
//!   handle can still see that a panic interrupted an update.
//!
//! A recovered value may be partially updated, because the panic happened in
//! the middle of a compound update. Keeping it is still the safer choice: the
//! caller can observe the recovery and decide, while a reset would discard
//! state the user can never recover. Guards must not cross an await.
use std::sync::{
    atomic::{AtomicU64, Ordering},
    Mutex as StdMutex, MutexGuard,
};

/// Crate-wide count of poisoned-lock recoveries.
static POISON_EVENTS: AtomicU64 = AtomicU64::new(0);

/// How many poisoned locks were recovered across this crate.
///
/// A non-zero value means a panic interrupted a state update somewhere. The
/// protected values were kept, so the session survives, but the event is not
/// hidden from the caller.
pub fn poison_events() -> u64 {
    POISON_EVENTS.load(Ordering::Relaxed)
}

/// Guard returned by [`Mutex::lock`].
///
/// It derefs to the protected value and reports whether the lock was poisoned
/// when the guard was acquired.
pub struct Guard<'a, T> {
    inner: MutexGuard<'a, T>,
    poisoned: bool,
}

impl<T> Guard<'_, T> {
    /// Whether this guard was acquired from a poisoned lock.
    ///
    /// A poisoned lock means a previous holder panicked while updating the
    /// value. The value was kept, but it may be partially updated.
    pub fn was_poisoned(&self) -> bool {
        self.poisoned
    }
}

impl<T> std::ops::Deref for Guard<'_, T> {
    type Target = T;
    fn deref(&self) -> &T {
        &self.inner
    }
}

impl<T> std::ops::DerefMut for Guard<'_, T> {
    fn deref_mut(&mut self) -> &mut T {
        &mut self.inner
    }
}

/// A `std::sync::Mutex` that recovers from poisoning without losing data.
pub struct Mutex<T> {
    inner: StdMutex<T>,
    poison_count: AtomicU64,
}

impl<T> Mutex<T> {
    pub const fn new(value: T) -> Self {
        Self {
            inner: StdMutex::new(value),
            poison_count: AtomicU64::new(0),
        }
    }

    /// Acquire the lock.
    ///
    /// A poisoned lock is recovered in place: the value is kept, the poison
    /// flag is cleared and the recovery is counted. The returned guard reports
    /// the recovery through [`Guard::was_poisoned`].
    pub fn lock(&self) -> Guard<'_, T> {
        match self.inner.lock() {
            Ok(guard) => Guard {
                inner: guard,
                poisoned: false,
            },
            Err(poisoned) => {
                let guard = poisoned.into_inner();
                self.inner.clear_poison();
                self.poison_count.fetch_add(1, Ordering::Relaxed);
                POISON_EVENTS.fetch_add(1, Ordering::Relaxed);
                Guard {
                    inner: guard,
                    poisoned: true,
                }
            }
        }
    }

    /// How often this lock was recovered from a poisoned state.
    pub fn poison_count(&self) -> u64 {
        self.poison_count.load(Ordering::Relaxed)
    }

    /// Whether this lock was ever recovered from a poisoned state.
    pub fn was_poisoned(&self) -> bool {
        self.poison_count() > 0
    }
}

impl<T: Default> Default for Mutex<T> {
    fn default() -> Self {
        Self::new(T::default())
    }
}

/// Preserve a single Copy value (used for route enums) after poisoning.
/// Assigning an enum cannot leave a partial value; resetting it instead would
/// silently change the user's explicit direct/WebVPN policy.
pub fn lock_value<T: Copy>(mutex: &StdMutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(|poisoned| {
        let guard = poisoned.into_inner();
        mutex.clear_poison();
        POISON_EVENTS.fetch_add(1, Ordering::Relaxed);
        guard
    })
}

#[cfg(test)]
mod tests {
    use super::{lock_value, poison_events, Guard, Mutex};
    use crate::auth::session::RouteMode;
    use std::{
        panic::catch_unwind,
        sync::{Arc, Mutex as StdMutex},
    };

    #[test]
    fn poisoned_value_keeps_explicit_route_policy() {
        let route = StdMutex::new(RouteMode::WebVpn);
        assert!(catch_unwind(|| {
            let _guard = route.lock().unwrap();
            panic!("synthetic interrupted route update");
        })
        .is_err());
        assert_eq!(*lock_value(&route), RouteMode::WebVpn);
        assert!(!route.is_poisoned());
    }

    #[test]
    fn a_poisoned_lock_keeps_its_value_and_reports_the_recovery() {
        let state = Mutex::new(String::from("synthetic-session"));
        assert!(catch_unwind(|| {
            let _guard = state.lock();
            panic!("synthetic interrupted session update");
        })
        .is_err());
        // The next acquisition recovers the poisoned lock, keeps the value and
        // reports the recovery.
        let guard = state.lock();
        assert!(guard.was_poisoned(), "the recovery must be observable");
        assert_eq!(guard.as_str(), "synthetic-session");
        drop(guard);
        assert_eq!(state.poison_count(), 1);
        assert!(state.was_poisoned());
        // The poison flag is cleared, so a later acquisition is clean.
        assert!(!state.lock().was_poisoned());
        assert_eq!(state.poison_count(), 1);
    }

    #[test]
    fn interrupted_update_keeps_the_previous_value_and_other_threads_can_use_the_lock() {
        let state = Arc::new(Mutex::new(vec![1]));
        let interrupted = Arc::clone(&state);
        assert!(std::thread::spawn(move || {
            interrupted.lock().push(2);
            let _guard = interrupted.lock();
            panic!("synthetic interrupted update");
        })
        .join()
        .is_err());
        // The interrupted update is not silently discarded.
        assert_eq!(*state.lock(), vec![1, 2]);
        state.lock().push(3);
        assert_eq!(*state.lock(), vec![1, 2, 3]);
        assert!(catch_unwind(|| state.lock().push(4)).is_ok());
        assert_eq!(*state.lock(), vec![1, 2, 3, 4]);
        assert!(state.was_poisoned());
    }

    #[test]
    fn crate_wide_poison_events_count_every_recovery() {
        let before = poison_events();
        let state = Mutex::new(0_u32);
        assert!(catch_unwind(|| {
            let _guard = state.lock();
            panic!("synthetic interrupted update");
        })
        .is_err());
        let _recovered = state.lock();
        assert!(poison_events() > before);
    }

    #[test]
    fn the_guard_exposes_the_protected_value_through_deref() {
        let state = Mutex::new(vec![1]);
        let mut guard: Guard<'_, Vec<i32>> = state.lock();
        assert!(!guard.was_poisoned());
        guard.push(2);
        assert_eq!(guard.len(), 2);
        drop(guard);
        assert_eq!(*state.lock(), vec![1, 2]);
    }
}
