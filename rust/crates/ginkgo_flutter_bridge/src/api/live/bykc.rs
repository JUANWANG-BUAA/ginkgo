//! Feature implementation behind the stable live API.
use super::*;

pub(super) async fn load_bykc(force_refresh: bool) -> BykcCatalogResponse {
    let result = match service() {
        Ok(service) => with_session_read(|| service.load_bykc(force_refresh)).await,
        Err(error) => Err(error),
    };
    let result = result.and_then(|outcome| {
        Ok(ginkgo_core::application::DataOutcome {
            data: ginkgo_core::application::project_catalog(outcome.data)?,
            failure: outcome.failure,
        })
    });
    bykc_catalog_response(result)
}

pub(super) fn load_demo_bykc() -> BykcCatalogResponse {
    bykc_catalog_response(
        ginkgo_runtime::demo::demo_campus::load_demo_bykc()
            .and_then(ginkgo_core::application::project_catalog)
            .map(no_failure),
    )
}

pub(super) async fn load_bykc_chosen(force_refresh: bool) -> BykcChosenResponse {
    let result = match service() {
        Ok(service) => with_session_read(|| service.load_bykc_chosen(force_refresh)).await,
        Err(error) => Err(error),
    };
    bykc_chosen_response(result)
}

pub(super) async fn load_bykc_statistics(force_refresh: bool) -> BykcStatisticsResponse {
    let result = match service() {
        Ok(service) => with_session_read(|| service.load_bykc_statistics(force_refresh)).await,
        Err(error) => Err(error),
    };
    bykc_statistics_response(result)
}

pub(super) fn load_demo_bykc_chosen() -> BykcChosenResponse {
    bykc_chosen_response(ginkgo_runtime::demo::demo_campus::load_demo_bykc_chosen().map(no_failure))
}

pub(super) fn load_demo_bykc_statistics() -> BykcStatisticsResponse {
    bykc_statistics_response(
        ginkgo_runtime::demo::demo_campus::load_demo_bykc_statistics().map(no_failure),
    )
}

fn no_failure<T>(data: T) -> ginkgo_core::application::DataOutcome<T> {
    ginkgo_core::application::DataOutcome {
        data,
        failure: None,
    }
}

fn bykc_catalog_response(
    result: Result<
        ginkgo_core::application::DataOutcome<ginkgo_core::application::BykcCatalogView>,
        AppError,
    >,
) -> BykcCatalogResponse {
    match result {
        Ok(outcome) => BykcCatalogResponse {
            data: Some(BykcCatalogDto {
                terms: outcome
                    .data
                    .catalog
                    .terms
                    .into_iter()
                    .map(bykc_semester_dto)
                    .collect(),
                courses: outcome
                    .data
                    .catalog
                    .courses
                    .into_iter()
                    .map(bykc_course_dto)
                    .collect(),
                current_term: outcome.data.current_term.map(bykc_semester_dto),
            }),
            failure: outcome.failure.map(|error| error.code.into()),
        },
        Err(error) => BykcCatalogResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
}

fn bykc_chosen_response(
    result: Result<
        ginkgo_core::application::DataOutcome<ginkgo_core::features::bykc::ChosenCourses>,
        AppError,
    >,
) -> BykcChosenResponse {
    match result {
        Ok(outcome) => BykcChosenResponse {
            data: Some(BykcChosenCoursesDto {
                term: outcome.data.term.map(bykc_semester_dto),
                // `None` stays `None`: an unusable semester range is not zero
                // selections.
                courses: outcome.data.courses.map(|courses| {
                    courses
                        .into_iter()
                        .map(|record| BykcChosenRecordDto {
                            id: record.id,
                            course: bykc_course_dto(record.course),
                            selected_at: record.selected_at,
                            checkin: record.checkin,
                            passed: record.passed,
                            score: record.score,
                        })
                        .collect()
                }),
            }),
            failure: outcome.failure.map(|error| error.code.into()),
        },
        Err(error) => BykcChosenResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
}

fn bykc_statistics_response(
    result: Result<
        ginkgo_core::application::DataOutcome<ginkgo_core::features::bykc::LearningStatistics>,
        AppError,
    >,
) -> BykcStatisticsResponse {
    match result {
        Ok(outcome) => BykcStatisticsResponse {
            data: Some(BykcStatisticsDto {
                valid_course_count: outcome.data.valid_course_count,
                entries: outcome
                    .data
                    .entries
                    .into_iter()
                    .map(|entry| BykcStatisticsEntryDto {
                        category: entry.category,
                        subcategory: entry.subcategory,
                        required: entry.required,
                        completed: entry.completed,
                    })
                    .collect(),
            }),
            failure: outcome.failure.map(|error| error.code.into()),
        },
        Err(error) => BykcStatisticsResponse {
            data: None,
            failure: Some(error.code.into()),
        },
    }
}

fn bykc_semester_dto(semester: ginkgo_core::features::bykc::Semester) -> BykcSemesterDto {
    BykcSemesterDto {
        id: semester.id,
        name: semester.name,
        start: semester.start,
        end: semester.end,
    }
}

fn bykc_course_dto(course: ginkgo_core::features::bykc::Course) -> BykcCourseDto {
    BykcCourseDto {
        id: course.id,
        name: course.name,
        teacher: course.teacher,
        position: course.position,
        category: course.category,
        subcategory: course.subcategory,
        details: course.details.map(|details| BykcCourseDetailsDto {
            start: details.start,
            end: details.end,
            select_start: details.select_start,
            select_end: details.select_end,
            cancel_end: details.cancel_end,
            capacity: details.capacity,
            enrolled: details.enrolled,
            campuses: details.campuses,
            summary: details.summary,
            selected: details.selected,
            has_sign_config: details.has_sign_config,
        }),
    }
}

#[cfg(test)]
mod bykc_tests {
    use super::*;

    #[test]
    fn chosen_courses_keep_missing_results_and_missing_pages_distinct() {
        use ginkgo_core::features::bykc::{ChosenCourse, ChosenCourses, Course, Semester};
        let response = bykc_chosen_response(Ok(ginkgo_core::application::DataOutcome {
            data: ChosenCourses {
                term: Some(Semester {
                    id: "1".into(),
                    name: "2026 秋".into(),
                    start: None,
                    end: None,
                }),
                courses: Some(vec![ChosenCourse {
                    id: 7,
                    course: Course {
                        id: 1,
                        name: "合成已选课程".into(),
                        teacher: None,
                        position: None,
                        category: None,
                        subcategory: None,
                        details: None,
                    },
                    selected_at: Some("2026-09-01".into()),
                    checkin: None,
                    passed: None,
                    score: None,
                }]),
            },
            failure: None,
        }));
        let data = response.data.expect("chosen");
        assert_eq!(data.term.as_ref().map(|t| t.name.as_str()), Some("2026 秋"));
        let record = &data.courses.as_ref().expect("courses")[0];
        // An undisclosed attendance/pass state stays absent, never "failed".
        assert!(record.checkin.is_none());
        assert!(record.passed.is_none());

        // An unusable semester range stays `None`, not an empty selection list.
        let unknown = bykc_chosen_response(Ok(ginkgo_core::application::DataOutcome {
            data: ChosenCourses {
                term: None,
                courses: None,
            },
            failure: None,
        }));
        assert!(unknown.data.expect("chosen").courses.is_none());
    }
}
