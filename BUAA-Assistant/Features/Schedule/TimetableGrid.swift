import SwiftUI

struct TimetableGrid: View {
  let snapshot: ScheduleSnapshot
  @State private var selected: CourseMeeting?
  private let rowHeight: CGFloat = 64
  private let columnWidth: CGFloat = 150
  private var sections: Int { max(12, snapshot.courses.map(\.endSection).max() ?? 12) }

  var body: some View {
    ScrollView(.horizontal) {
      VStack(spacing: 0) {
        HStack(spacing: 0) {
          Text("节次 / 时间").font(.caption).frame(width: 86, height: 52)
          ForEach(1...7, id: \.self) { day in
            VStack(spacing: 3) {
              Text("周\(["一", "二", "三", "四", "五", "六", "日"][day - 1])").font(.headline)
              if let week = snapshot.weeks.first(where: { $0.number == snapshot.weekNumber }),
                 let date = ScheduleSnapshot.schoolCalendar.date(byAdding: .day, value: day - 1, to: week.start) {
                Text(date.formatted(.dateTime.month().day())).font(.caption).foregroundStyle(.secondary)
              }
            }.frame(width: columnWidth, height: 52)
          }
        }.background(Color(nsColor: .controlBackgroundColor))
        HStack(alignment: .top, spacing: 0) {
          VStack(spacing: 0) {
            ForEach(1...sections, id: \.self) { section in
              VStack(spacing: 3) {
                Text("第 \(section) 节").font(.caption.weight(.medium))
                if let time = snapshot.courses.first(where: { $0.startSection == section })?.startTime {
                  Text(time).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
              }.frame(width: 86, height: rowHeight).overlay(alignment: .bottom) { Divider() }
            }
          }
          ForEach(1...7, id: \.self) { day in
            dayColumn(day)
          }
        }
      }
      .background(Color(nsColor: .controlBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08)))
    }
    .sheet(item: $selected) { meeting in
      VStack(alignment: .leading, spacing: 16) {
        Text(meeting.name).font(.title2.weight(.semibold))
        Label("周\(["一", "二", "三", "四", "五", "六", "日"][meeting.day - 1]) · 第 \(meeting.startSection)–\(meeting.endSection) 节", systemImage: "calendar")
        if let start = meeting.startTime, let end = meeting.endTime { Label("\(start)–\(end)", systemImage: "clock") }
        Label(meeting.place ?? "地点待公布", systemImage: "mappin")
        Text(meeting.teacher ?? "教师信息未公布").foregroundStyle(.secondary)
        HStack { Spacer(); Button("完成") { selected = nil }.keyboardShortcut(.defaultAction) }
      }.padding(24).frame(width: 420)
    }
  }

  private func dayColumn(_ day: Int) -> some View {
    let meetings = snapshot.courses.filter { $0.day == day }
    let placements = TimetableLayout.placements(meetings)
    return ZStack(alignment: .topLeading) {
      VStack(spacing: 0) {
        ForEach(1...sections, id: \.self) { _ in
          Color.clear.frame(height: rowHeight).overlay(alignment: .bottom) { Divider() }
        }
      }
      ForEach(meetings) { meeting in
        let placement = placements[meeting.id]
        let lane = placement?.lane ?? 0
        let width = columnWidth / CGFloat(placement?.count ?? 1)
        Button { selected = meeting } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(meeting.name).font(.caption.weight(.semibold)).lineLimit(3)
            Text(meeting.place ?? "地点待公布").font(.caption2).lineLimit(2)
            if let start = meeting.startTime { Text(start).font(.caption2.monospacedDigit()) }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .padding(7)
          .background(courseColor(meeting.name).opacity(0.17), in: RoundedRectangle(cornerRadius: 7))
          .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(courseColor(meeting.name)).frame(width: 3) }
        }
        .buttonStyle(.plain)
        .frame(width: width - 6, height: CGFloat(meeting.endSection - meeting.startSection + 1) * rowHeight - 6)
        .offset(x: CGFloat(lane) * width + 3, y: CGFloat(meeting.startSection - 1) * rowHeight + 3)
        .help("\(meeting.name) · \(meeting.place ?? "地点待公布")")
      }
    }
    .frame(width: columnWidth, height: CGFloat(sections) * rowHeight)
    .overlay(alignment: .leading) { Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 1) }
  }

  private func courseColor(_ name: String) -> Color {
    let colors: [Color] = [.blue, .teal, .indigo, .orange, .purple, .pink]
    return colors[name.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % colors.count }]
  }
}

struct SemesterOverview: View {
  let snapshot: ScheduleSnapshot
  let selectWeek: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("已查询 \(snapshot.termCourses?.count ?? 1) / \(snapshot.weeks.count) 周 · 点击周次查看时间与地点")
        .font(.caption).foregroundStyle(.secondary)
      ScrollView(.horizontal) {
        Grid(horizontalSpacing: 1, verticalSpacing: 1) {
          GridRow {
            Text("周次").frame(width: 76)
            ForEach(1...7, id: \.self) { day in
              Text("周\(["一", "二", "三", "四", "五", "六", "日"][day - 1])").frame(width: 132)
            }
          }.font(.headline).padding(.vertical, 12)
          ForEach(snapshot.weeks) { week in
            GridRow(alignment: .top) {
              Button("第 \(week.number) 周") { selectWeek(week.number) }.frame(width: 76, height: 76)
              ForEach(1...7, id: \.self) { day in
                SemesterDayCell(courses: snapshot.termCourses?[String(week.number)], day: day, isCurrent: week.isCurrent)
              }
            }
          }
        }.background(Color.primary.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 10))
      }
    }
  }
}

private struct SemesterDayCell: View {
  let courses: [CourseMeeting]?
  let day: Int
  let isCurrent: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let courses {
        let meetings = courses.filter { $0.day == day }
        if meetings.isEmpty { Text("无课").foregroundStyle(.secondary) }
        ForEach(meetings) { course in
          VStack(alignment: .leading, spacing: 3) {
            Text(course.name).font(.caption.weight(.medium))
            Text("第 \(course.startSection)–\(course.endSection) 节").font(.caption2)
            Text(course.place ?? "地点待公布").font(.caption2).foregroundStyle(.secondary)
          }.fixedSize(horizontal: false, vertical: true)
        }
      } else { Text("未查询").foregroundStyle(.secondary) }
    }
    .frame(width: 116, alignment: .topLeading)
    .frame(minHeight: 60, alignment: .topLeading)
    .padding(8)
    .background(isCurrent ? Color.accentColor.opacity(0.09) : Color(nsColor: .controlBackgroundColor))
  }
}
