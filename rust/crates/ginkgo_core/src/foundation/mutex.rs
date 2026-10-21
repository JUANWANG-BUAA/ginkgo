//! Short-lived locks for disposable in-memory state.
//!
//! A panic may interrupt a compound update. Recover by replacing the entire
//! value with its safe default, rather than exposing partially updated state
//! or making every later request panic. Do not use this for durable storage or
//! a value whose default would grant access. Guards must not cross an await.
use std::sync::{Mutex as StdMutex, MutexGuard};

pub(crate) struct Mutex<T>(StdMutex<T>);

impl<T: Default> Mutex<T> {
    pub(crate) const fn new(value: T) -> Self {
        Self(StdMutex::new(value))
    }

    pub(crate) fn lock(&self) -> MutexGuard<'_, T> {
        match self.0.lock() {
            Ok(guard) => guard,
            Err(poisoned) => {
                let mut guard = poisoned.into_inner();
                *guard = T::default();
                self.0.clear_poison();
                guard
            }
        }
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
pub(crate) fn lock_value<T: Copy>(mutex: &StdMutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(|poisoned| {
        let guard = poisoned.into_inner();
        mutex.clear_poison();
        guard
    })
}

#[cfg(test)]
mod tests {
    use super::{lock_value, Mutex};
    use std::{
        panic::catch_unwind,
        sync::{Arc, Mutex as StdMutex},
    };

    #[test]
    fn poisoned_value_keeps_explicit_route_policy() {
        use crate::auth::session::RouteMode;
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
    fn interrupted_update_is_reset_once_and_other_threads_can_use_the_lock() {
        let state = Arc::new(Mutex::new(vec![1]));
        let interrupted = Arc::clone(&state);
        assert!(std::thread::spawn(move || {
            interrupted.lock().push(2);
            let _guard = interrupted.lock();
            panic!("synthetic interrupted update");
        })
        .join()
        .is_err());
        assert!(state.lock().is_empty());
        state.lock().push(3);
        assert_eq!(*state.lock(), vec![3]);
        assert!(catch_unwind(|| state.lock().push(4)).is_ok());
        assert_eq!(*state.lock(), vec![3, 4]);
    }
}
