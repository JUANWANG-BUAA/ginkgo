import Foundation

enum TimetableLayout {
  struct Placement {
    let lane: Int
    let count: Int
  }

  static func placements(_ meetings: [CourseMeeting]) -> [String: Placement] {
    let sorted = meetings.sorted { $0.startSection == $1.startSection ? $0.id < $1.id : $0.startSection < $1.startSection }
    var result: [String: Placement] = [:]
    var group: [CourseMeeting] = []
    var end = 0
    func commit() {
      var laneEnds: [Int] = []
      var lanes: [String: Int] = [:]
      for meeting in group {
        let lane = laneEnds.firstIndex(where: { $0 < meeting.startSection }) ?? laneEnds.count
        if lane == laneEnds.count { laneEnds.append(meeting.endSection) } else { laneEnds[lane] = meeting.endSection }
        lanes[meeting.id] = lane
      }
      for meeting in group { result[meeting.id] = Placement(lane: lanes[meeting.id] ?? 0, count: max(1, laneEnds.count)) }
    }
    for meeting in sorted {
      if !group.isEmpty && meeting.startSection > end { commit(); group = []; end = 0 }
      group.append(meeting); end = max(end, meeting.endSection)
    }
    commit()
    return result
  }
}
