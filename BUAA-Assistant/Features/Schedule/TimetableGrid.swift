import SwiftUI

struct TimetableGrid: View {
  let snapshot: ScheduleSnapshot
  @State private var selected: CourseMeeting?
  private let sectionColumnWidth: CGFloat = 80
  private var sections: Int { max(12, snapshot.courses.map(\.endSection).max() ?? 12) }
  private var rowHeight: CGFloat { max(44, min(64, 600 / CGFloat(sections))) }

  var body: some View {
    GeometryReader { geometry in
      let columnWidth = min(150, max(124, (geometry.size.width - sectionColumnWidth) / 7))
      ScrollView(.horizontal) {
        VStack(spacing: 0) {
          HStack(spacing: 0) {
            Text("节次 / 时间").font(.caption).frame(width: sectionColumnWidth, height: 52)
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
                VStack(spacing: 2) {
                  Text("第 \(section) 节").font(.system(size: 11, weight: .medium))
                  if let time = snapshot.courses.first(where: { $0.startSection == section })?.startTime {
                    Text(time).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                  }
                }.frame(width: sectionColumnWidth, height: rowHeight).overlay(alignment: .bottom) { Divider() }
              }
            }
            ForEach(1...7, id: \.self) { day in
              dayColumn(day, columnWidth: columnWidth)
            }
          }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08)))
      }
    }
    .frame(height: CGFloat(sections) * rowHeight + 52)
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

  private func dayColumn(_ day: Int, columnWidth: CGFloat) -> some View {
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
        let span = meeting.endSection - meeting.startSection + 1
        let place = meeting.place.flatMap { $0.isEmpty ? nil : $0 } ?? "地点待公布"
        let detail = meeting.startTime.map { "\(place) · \($0)" } ?? place
        Button { selected = meeting } label: {
          VStack(alignment: .leading, spacing: 1) {
            Text(meeting.name)
              .font(.system(size: 14, weight: .semibold))
              .lineLimit(span > 1 ? 2 : 1)
            Text(detail)
              .font(.system(size: 11))
              .lineLimit(1)
              .minimumScaleFactor(0.85)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
          .padding(6)
          .background(CoursePalette.color(for: meeting.name).opacity(0.17), in: RoundedRectangle(cornerRadius: 7))
          .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(CoursePalette.color(for: meeting.name)).frame(width: 3) }
        }
        .buttonStyle(.plain)
        .frame(width: width - 6, height: CGFloat(span) * rowHeight - 6)
        .offset(x: CGFloat(lane) * width + 3, y: CGFloat(meeting.startSection - 1) * rowHeight + 3)
        .help("\(meeting.name) · \(meeting.place ?? "地点待公布")")
      }
    }
    .frame(width: columnWidth, height: CGFloat(sections) * rowHeight)
    .overlay(alignment: .leading) { Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 1) }
  }

}

/// 课程稳定配色：同一门课在周网格与学期总览使用同一颜色，避免总览一片单色。
enum CoursePalette {
  private static let colors: [Color] = [.blue, .teal, .indigo, .orange, .purple, .pink, .green, .red]

  static func color(for name: String) -> Color {
    var hash = 5381
    for scalar in name.unicodeScalars { hash = (hash &* 33) &+ Int(scalar.value) }
    return colors[abs(hash) % colors.count]
  }
}

struct SemesterOverview: View {
  let snapshot: ScheduleSnapshot
  let selectWeek: (Int) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        Text("已查询 \(snapshot.termCourses?.count ?? 1) / \(snapshot.weeks.count) 周 · 点击周次查看时间与地点")
          .font(.caption).foregroundStyle(.secondary)
        Spacer()
        HStack(spacing: 6) {
          Circle().fill(Color.accentColor).frame(width: 6, height: 6)
          Text("本周").font(.caption).foregroundStyle(.secondary)
        }
      }
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
              Button { selectWeek(week.number) } label: {
                VStack(spacing: 4) {
                  Text("第 \(week.number) 周").font(.caption.weight(.semibold))
                  if week.isCurrent {
                    Text("本周").font(.system(size: 9, weight: .semibold))
                      .padding(.horizontal, 5).padding(.vertical, 1)
                      .background(Color.accentColor, in: Capsule())
                      .foregroundStyle(.white)
                  }
                }
                .frame(width: 76, height: 76)
              }
              .buttonStyle(.plain)
              .background(week.isCurrent ? Color.accentColor.opacity(0.08) : Color.clear)
              ForEach(1...7, id: \.self) { day in
                SemesterDayCell(courses: snapshot.termCourses?[String(week.number)], day: day, isCurrent: week.isCurrent)
              }
            }
          }
        }.background(Color(nsColor: .separatorColor)).clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.06)))
      }
    }
  }
}

private struct SemesterDayCell: View {
  let courses: [CourseMeeting]?
  let day: Int
  let isCurrent: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let courses {
        let meetings = courses.filter { $0.day == day }
        if meetings.isEmpty { Text("无课").font(.caption2).foregroundStyle(.tertiary) }
        ForEach(meetings) { course in
          let color = CoursePalette.color(for: course.name)
          VStack(alignment: .leading, spacing: 2) {
            Text(course.name).font(.caption2.weight(.semibold)).lineLimit(2)
            Text("第 \(course.startSection)–\(course.endSection) 节").font(.system(size: 9))
            Text(course.place ?? "地点待公布").font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
          }
          .padding(.vertical, 3).padding(.horizontal, 5)
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
          .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3) }
        }
      } else { Text("未查询").font(.caption2).foregroundStyle(.tertiary) }
    }
    .frame(width: 116, alignment: .topLeading)
    .frame(minHeight: 60, alignment: .topLeading)
    .padding(8)
    .background(isCurrent ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
  }
}
