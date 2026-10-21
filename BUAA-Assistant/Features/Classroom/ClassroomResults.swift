import Foundation

enum ClassroomSort: String, CaseIterable, Identifiable, Codable, Sendable {
  case name
  case availability
  case consecutive

  var id: String { rawValue }
}

struct IndexedClassroom: Sendable {
  let room: FreeClassroom
  let normalizedName: String
}

struct ClassroomResultSummary: Sendable {
  var roomCount = 0
  var buildingCount = 0
  var freeSlotCount = 0
}

struct ClassroomFilterInput: Sendable {
  let sourceRooms: [String: [FreeClassroom]]?
  let indexedRooms: [String: [IndexedClassroom]]?
  let search: String
  let section: Int
  let minimumFreeSections: Int
  let minimumConsecutiveSections: Int
  let building: String?
  let sort: ClassroomSort
}

struct ClassroomFilterOutput: Sendable {
  let filtered: [String: [FreeClassroom]]
  let index: [String: [IndexedClassroom]]?
  let summary: ClassroomResultSummary
}

/// 只依赖教室模型与筛选条件的纯结果处理，不涉及 SwiftUI 状态或数据获取。
enum ClassroomResultProcessor {
  static func process(_ input: ClassroomFilterInput) -> ClassroomFilterOutput {
    let index: [String: [IndexedClassroom]]
    let shouldReturnIndex = input.indexedRooms == nil
    if let indexedRooms = input.indexedRooms {
      index = indexedRooms
    } else {
      var prepared: [String: [IndexedClassroom]] = [:]
      for (building, rooms) in input.sourceRooms ?? [:] {
        var entries: [IndexedClassroom] = []
        entries.reserveCapacity(rooms.count)
        for room in rooms {
          guard !Task.isCancelled else {
            return ClassroomFilterOutput(filtered: [:], index: nil, summary: ClassroomResultSummary())
          }
          entries.append(IndexedClassroom(room: room, normalizedName: normalizedSearch(room.name)))
        }
        prepared[building] = entries
      }
      index = prepared
    }

    let term = normalizedSearch(input.search.trimmingCharacters(in: .whitespacesAndNewlines))
    var filtered: [String: [FreeClassroom]] = [:]
    var summary = ClassroomResultSummary()

    for (building, entries) in index {
      guard !Task.isCancelled else {
        return ClassroomFilterOutput(filtered: [:], index: nil, summary: ClassroomResultSummary())
      }
      if let selectedBuilding = input.building, selectedBuilding != building { continue }
      let matchesBuilding = normalizedSearch(building).contains(term)
      var matches: [FreeClassroom] = []
      matches.reserveCapacity(entries.count)
      for entry in entries {
        guard !Task.isCancelled else {
          return ClassroomFilterOutput(filtered: [:], index: nil, summary: ClassroomResultSummary())
        }
        let room = entry.room
        let matchesSearch = term.isEmpty || matchesBuilding || entry.normalizedName.contains(term)
        let matchesSection = input.section == 0 || room.isAvailable(at: input.section)
        guard matchesSearch, matchesSection,
              room.availableSectionCount >= input.minimumFreeSections,
              room.longestFreeRun >= input.minimumConsecutiveSections else { continue }
        matches.append(room)
      }

      matches.sort { lhs, rhs in
        if input.sort == .availability, lhs.availableSectionCount != rhs.availableSectionCount {
          return lhs.availableSectionCount > rhs.availableSectionCount
        }
        if input.sort == .consecutive, lhs.longestFreeRun != rhs.longestFreeRun {
          return lhs.longestFreeRun > rhs.longestFreeRun
        }
        let order = lhs.name.localizedStandardCompare(rhs.name)
        return order == .orderedSame ? lhs.id < rhs.id : order == .orderedAscending
      }
      guard !Task.isCancelled else {
        return ClassroomFilterOutput(filtered: [:], index: nil, summary: ClassroomResultSummary())
      }
      guard !matches.isEmpty else { continue }
      filtered[building] = matches
      summary.roomCount += matches.count
      summary.buildingCount += 1
      summary.freeSlotCount += matches.reduce(0) { $0 + $1.availableSectionCount }
    }

    return ClassroomFilterOutput(
      filtered: filtered,
      index: shouldReturnIndex ? index : nil,
      summary: summary
    )
  }

  private static func normalizedSearch(_ value: String) -> String {
    let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    let scalars = folded.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
    return String(String.UnicodeScalarView(scalars))
  }
}
