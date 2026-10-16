import SwiftUI

struct ExamScheduleSection: View {
  @EnvironmentObject private var appState: AppState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @EnvironmentObject private var model: ExamViewModel
  let termID: String

  private var account: String? { appState.user?.schoolid }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .center) {
        VStack(alignment: .leading, spacing: 4) {
          Text("考试安排").font(.title2.weight(.semibold))
          Text("时间、考场与座位信息以教务系统最新结果为准")
            .font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        Button { Task { await load(force: true) } } label: {
          if model.isLoading {
            ProgressView().controlSize(.small).frame(width: 18, height: 18)
          } else {
            Label("刷新", systemImage: "arrow.clockwise")
          }
        }
        .buttonStyle(.bordered)
        .disabled(model.isLoading)
        .accessibilityLabel(model.isLoading ? "正在刷新考试安排" : "刷新考试安排")
      }

      if let error = model.errorMessage {
        StatusNotice(message: model.exams == nil ? error : "刷新失败：\(error) · 保留上次查询结果", kind: .warning)
      }

      if let exams = model.exams {
        if exams.isEmpty {
          PageEmptyState(symbol: "checkmark.calendar", title: "暂无考试安排", detail: "教务系统已成功返回当前学期的考试列表。")
            .transition(.opacity)
        } else {
          HStack(spacing: 8) {
            Label("\(exams.count) 场考试", systemImage: "calendar.badge.clock")
              .font(.callout.weight(.semibold))
            if let fetchedAt = model.fetchedAt {
              Text("· \(model.resultsAreCached ? "缓存于" : "更新于") \(fetchedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
            }
          }
          LazyVStack(spacing: 10) {
            ForEach(exams) { exam in ExamCard(exam: exam) }
          }
          .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
        }
      } else if model.isLoading {
        HStack(spacing: 12) {
          ProgressView().controlSize(.small)
          VStack(alignment: .leading, spacing: 3) {
            Text("正在核对考试安排…").font(.callout.weight(.medium))
            Text("首次查询会先确认本科教务会话").font(.caption).foregroundStyle(.secondary)
          }
          Spacer()
        }
        .padding(18)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .transition(.opacity)
      } else {
        VStack(spacing: 10) {
          PageEmptyState(symbol: "wifi.exclamationmark", title: "考试安排尚未确认", detail: model.errorMessage ?? "连接教务系统后即可查询当前学期的考试时间与考场。")
          Button("重试") { Task { await load(force: true) } }
            .buttonStyle(.borderedProminent)
        }
        .transition(.opacity)
      }
    }
    .task(id: "\(account ?? ""):\(termID)") { await load() }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: model.exams?.count)
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: model.isLoading)
  }

  private func load(force: Bool = false) async {
    guard let account else { return }
    await model.load(termID: termID, force: force, account: account)
  }
}

private struct ExamCard: View {
  let exam: Exam

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      VStack(spacing: 2) {
        Text(monthDay).font(.caption.weight(.semibold)).monospacedDigit()
        Text(weekday).font(.caption2).foregroundStyle(.secondary)
      }
      .frame(width: 48, height: 48)
      .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))

      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(exam.courseName).font(.headline).fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 4)
          if let type = exam.examType, !type.isEmpty {
            Text(type).font(.caption2.weight(.medium)).padding(.horizontal, 7).padding(.vertical, 4)
              .background(Color.secondary.opacity(0.09), in: Capsule())
          }
        }
        HStack(spacing: 14) {
          Label(time, systemImage: "clock")
          if let place = exam.examPlace, !place.isEmpty { Label(place, systemImage: "mappin.and.ellipse") }
        }
        .font(.caption).foregroundStyle(.secondary)
        HStack(spacing: 8) {
          if let seat = exam.examSeatNo, !seat.isEmpty {
            Label("座位 \(seat)", systemImage: "chair.lounge")
              .font(.caption.weight(.semibold)).foregroundStyle(Color.accentColor)
          }
          if let status = exam.examStatus, !status.isEmpty {
            Text(status).font(.caption2).foregroundStyle(.secondary)
          }
          if let courseNo = exam.courseNo, !courseNo.isEmpty {
            Text(courseNo).font(.caption2.monospaced()).foregroundStyle(.tertiary)
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(14)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    .overlay(alignment: .leading) {
      RoundedRectangle(cornerRadius: 2).fill(Color.accentColor.opacity(0.7)).frame(width: 3).padding(.vertical, 12)
    }
    .accessibilityElement(children: .combine)
  }

  private var monthDay: String {
    guard let date = parsedDate else { return exam.examDate ?? "待定" }
    return date.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
  }

  private var weekday: String {
    guard let date = parsedDate else { return "日期" }
    return date.formatted(.dateTime.weekday(.wide))
  }

  private var time: String {
    if let description = exam.examTimeDescription, !description.isEmpty { return description }
    switch (exam.startTime, exam.endTime) {
    case let (start?, end?): return "\(start)–\(end)"
    case let (start?, nil): return start
    case let (nil, end?): return end
    default: return "时间待定"
    }
  }

  private var parsedDate: Date? {
    guard let value = exam.examDate else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
    for pattern in ["yyyy-MM-dd", "yyyy-MM-dd HH:mm:ss", "yyyy/MM/dd"] {
      formatter.dateFormat = pattern
      if let date = formatter.date(from: value) { return date }
    }
    return nil
  }
}
