/// ViewModels - adaptation layer between backend DTOs and UI
/// Purpose: Decouple UI from backend data structures
///
/// When backend changes field names, only these adapters need updates
/// Pages remain unchanged
library;

// Placeholder for HomeworkViewModel
// (Full implementation deferred to Phase 3-P1)

// Placeholder for CourseViewModel

// Placeholder for CheckInViewModel

// Placeholder for NoticeViewModel

// Placeholder for Demo data models

/// This framework allows:
/// 1. Backend can rename fields → update here only
/// 2. Pages use stable ViewModel interface → no changes
/// 3. Type safety maintained → compile-time errors
/// 4. Future optimization → add caching, computed fields

/// Example usage pattern (to be implemented Day 5):
/*
// In page: use ViewModel, not DTO
final homeworks = homeworkResponse.items.map(HomeworkViewModel.from).toList();

// In ViewModel: hide DTO complexity
class HomeworkViewModel {
  final String id;
  final String title;
  final DateTime deadline;

  factory HomeworkViewModel.from(HomeworkItem item) => HomeworkViewModel(
    id: item.id,
    title: item.title,
    deadline: DateTime.parse(item.deadline),
  );
}

// If backend changes: only HomeworkViewModel changes, not the page
*/

