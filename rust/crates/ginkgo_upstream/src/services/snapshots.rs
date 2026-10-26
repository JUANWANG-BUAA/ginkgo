//! Query snapshots share account lifetime and invalidation, not authentication policy.
use super::{
    cache::SnapshotCache,
    schedule_service::{GradeData, ScheduleData},
};
use crate::{
    features::{
        checkin::CheckInCourse,
        classroom::Room,
        library::{LibraryBooking, LibraryHistoryPage, LibraryVenue},
        today::TodayCourse,
    },
    foundation::mutex::Mutex,
};
use std::collections::BTreeMap;

pub(crate) type ClassroomCache = SnapshotCache<(i32, String), BTreeMap<String, Vec<Room>>>;
pub(crate) type ScheduleCache = SnapshotCache<(Option<String>, Option<i32>), ScheduleData>;
pub(crate) type TodayCache = SnapshotCache<String, Vec<TodayCourse>>;
pub(crate) type GradeCache = SnapshotCache<String, GradeData>;
pub(crate) type CheckInCache = SnapshotCache<String, Vec<CheckInCourse>>;
pub(crate) type LibraryVenueCache = SnapshotCache<String, Vec<LibraryVenue>>;
pub(crate) type LibraryBookingCache = SnapshotCache<String, Vec<LibraryBooking>>;

#[derive(Default)]
pub(crate) struct ReadSnapshots {
    pub(crate) learning: super::learning_service::LearningSnapshots,
    pub(crate) classrooms: Mutex<ClassroomCache>,
    pub(crate) schedules: Mutex<ScheduleCache>,
    pub(crate) cgyy: Mutex<SnapshotCache<String, ginkgo_domain::ports::CgyyData>>,
    pub(crate) notices: Mutex<SnapshotCache<String, Vec<crate::features::notices::Notice>>>,
    pub(crate) graduate: Mutex<SnapshotCache<String, crate::features::graduate::AcademicData>>,
    pub(crate) bykc: Mutex<SnapshotCache<String, crate::features::bykc::Catalog>>,
    pub(crate) bykc_chosen: Mutex<SnapshotCache<String, crate::features::bykc::ChosenCourses>>,
    pub(crate) bykc_statistics:
        Mutex<SnapshotCache<String, crate::features::bykc::LearningStatistics>>,
    pub(crate) homework: Mutex<super::homework_service::HomeworkCache>,
    pub(crate) homework_details: Mutex<super::homework_service::HomeworkDetailCache>,
    pub(crate) today: Mutex<TodayCache>,
    pub(crate) grades: Mutex<GradeCache>,
    pub(crate) checkin: Mutex<CheckInCache>,
    pub(crate) library_stats: Mutex<super::library_stats_service::LibraryStatsCache>,
    pub(crate) library_venues: Mutex<LibraryVenueCache>,
    pub(crate) library_bookings: Mutex<LibraryBookingCache>,
    pub(crate) library_history: Mutex<SnapshotCache<i32, LibraryHistoryPage>>,
}

impl ReadSnapshots {
    pub fn clear(&self) {
        self.learning.clear();
        self.classrooms.lock().clear();
        self.schedules.lock().clear();
        self.cgyy.lock().clear();
        self.notices.lock().clear();
        self.graduate.lock().clear();
        self.bykc.lock().clear();
        self.bykc_chosen.lock().clear();
        self.bykc_statistics.lock().clear();
        self.homework.lock().clear();
        self.homework_details.lock().clear();
        self.today.lock().clear();
        self.grades.lock().clear();
        self.checkin.lock().clear();
        self.library_venues.lock().clear();
        self.library_stats.lock().clear();
        self.library_history.lock().clear();
        self.library_bookings.lock().clear();
    }

    /// How often one of the snapshot locks was recovered from a poisoned state.
    ///
    /// A non-zero value means a panic interrupted a snapshot update. The
    /// snapshot was kept, but the event stays visible to the caller.
    pub fn poison_events(&self) -> u64 {
        self.classrooms.poison_count()
            + self.schedules.poison_count()
            + self.cgyy.poison_count()
            + self.notices.poison_count()
            + self.graduate.poison_count()
            + self.bykc.poison_count()
            + self.bykc_chosen.poison_count()
            + self.bykc_statistics.poison_count()
            + self.homework.poison_count()
            + self.homework_details.poison_count()
            + self.today.poison_count()
            + self.grades.poison_count()
            + self.checkin.poison_count()
            + self.library_stats.poison_count()
            + self.library_venues.poison_count()
            + self.library_bookings.poison_count()
            + self.library_history.poison_count()
    }
}
