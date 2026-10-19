import SwiftUI

struct IOSScheduleView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var model: ScheduleViewModel
  @EnvironmentObject private var exams: ExamViewModel
  @State private var mode = "课程"
  @State private var search = ""

  var body: some View {
    List {
      if let snapshot = model.snapshot {
        controls(snapshot)

        switch mode {
        case "考试" where snapshot.portal == .undergraduate:
          examContent(snapshot)
        case "学期":
          semesterContent(snapshot)
        default:
          courseContent(snapshot)
        }

        if let error = model.errorMessage {
          Section {
            IOSInlineMessage(error, systemImage: "exclamationmark.triangle.fill", tint: .orange)
          }
        }
      } else if model.isLoading {
        Section {
          HStack(spacing: 10) {
            ProgressView()
            Text("正在读取课表…")
          }
        }
      } else {
        Section {
          ContentUnavailableView(
            "课表尚未确认",
            systemImage: "wifi.exclamationmark",
            description: Text(model.errorMessage ?? "请检查网络后重试。")
          )
          Button("重试") { Task { await model.refresh() } }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("课表")
    .searchable(text: $search, prompt: "搜索课程、教师或地点")
    .refreshable { await refresh() }
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        if let snapshot = model.snapshot {
          Menu {
            Section("学期") {
              ForEach(snapshot.terms) { term in
                Button {
                  Task { await model.refresh(termID: term.id) }
                } label: {
                  if term.id == snapshot.termID {
                    Label(term.name, systemImage: "checkmark")
                  } else {
                    Text(term.name)
                  }
                }
              }
            }
          } label: {
            Label("选择学期", systemImage: "building.columns")
          }

          Menu {
            ForEach(snapshot.weeks) { week in
              Button {
                Task { await model.refresh(week: week.number) }
              } label: {
                if week.number == snapshot.weekNumber {
                  Label("第 \(week.number) 周", systemImage: "checkmark")
                } else {
                  Text("第 \(week.number) 周\(week.isCurrent ? " · 本周" : "")")
                }
              }
            }
          } label: {
            Label("第 \(snapshot.weekNumber) 周", systemImage: "calendar")
          }
        }

        Button {
          Task { await refresh() }
        } label: {
          if model.isLoading {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: "arrow.clockwise")
          }
        }
        .disabled(model.isLoading)
        .accessibilityLabel("刷新课表")
      }
    }
    .task(id: appState.user?.schoolid) {
      guard let account = appState.user?.schoolid else { return }
      await model.start(account: account)
    }
    .onChange(of: model.snapshot?.termID) { _, _ in
      if mode == "考试" { Task { await loadExams() } }
    }
    .onChange(of: model.needsSessionCheck) { _, needed in
      guard needed else { return }
      Task { _ = try? await appState.confirmSessionAfterAuthFailure() }
    }
    .onChange(of: exams.needsSessionCheck) { _, needed in
      guard needed else { return }
      Task { _ = try? await appState.confirmSessionAfterAuthFailure() }
    }
  }

  @ViewBuilder
  private func controls(_ snapshot: ScheduleSnapshot) -> some View {
    Section {
      Picker("查看", selection: $mode) {
        Text("课程").tag("课程")
        Text("学期").tag("学期")
        if snapshot.portal == .undergraduate {
          Text("考试").tag("考试")
        }
      }
      .pickerStyle(.segmented)

      LabeledContent("当前周", value: "第 \(snapshot.weekNumber) 周")
      if let week = snapshot.weeks.first(where: { $0.number == snapshot.weekNumber }) {
        LabeledContent("日期", value: "\(week.start.formatted(date: .abbreviated, time: .omitted)) – \(week.end.formatted(date: .abbreviated, time: .omitted))")
      }
      LabeledContent("教务系统", value: snapshot.portal == .graduate ? "研究生教务" : "本科教务")
    } header: {
      Text("课表范围")
    } footer: {
      Text("更新于 \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
    }
    .onChange(of: mode) { _, value in
      if value == "考试" { Task { await loadExams() } }
    }
  }

  @ViewBuilder
  private func courseContent(_ snapshot: ScheduleSnapshot) -> some View {
    let courses = filteredCourses(snapshot.courses)
    if snapshot.weeks.isEmpty {
      Section {
        ContentUnavailableView(
          "该学期暂无课表",
          systemImage: "calendar.badge.exclamationmark",
          description: Text("学校尚未为该学期发布排课数据，可以切换到其他学期查看。")
        )
      }
    } else if courses.isEmpty {
      Section {
        ContentUnavailableView(
          search.isEmpty ? "本周没有课程" : "没有匹配的课程",
          systemImage: search.isEmpty ? "calendar.badge.checkmark" : "magnifyingglass",
          description: Text(search.isEmpty ? "可以切换其他周次查看。" : "请尝试其他关键词。")
        )
      }
    } else {
      ForEach(1...7, id: \.self) { day in
        let dayCourses = courses.filter { $0.day == day }.sorted { $0.startSection < $1.startSection }
        if dayCourses.isEmpty == false {
          Section {
            ForEach(dayCourses) { meeting in
              NavigationLink {
                IOSCourseDetailView(meeting: meeting, week: snapshot.weeks.first(where: { $0.number == snapshot.weekNumber }))
              } label: {
                HStack(alignment: .top, spacing: 12) {
                  RoundedRectangle(cornerRadius: 2)
                    .fill(CoursePalette.color(for: meeting.name))
                    .frame(width: 4)
                    .padding(.vertical, 2)
                  IOSCourseTime(meeting: meeting)
                  VStack(alignment: .leading, spacing: 4) {
                    Text(meeting.name).font(.body.weight(.medium))
                    if let place = meeting.place, place.isEmpty == false {
                      Label(place, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                  }
                }
                .padding(.vertical, 3)
              }
            }
          } header: {
            Text(dayTitle(day, snapshot: snapshot))
          }
        }
      }
    }
  }

  @ViewBuilder
  private func semesterContent(_ snapshot: ScheduleSnapshot) -> some View {
    Section("学期周次") {
      if snapshot.weeks.isEmpty {
        ContentUnavailableView(
          "暂无学期周次",
          systemImage: "calendar.badge.exclamationmark",
          description: Text("学校尚未发布该学期的排课与周次数据。")
        )
      }
      ForEach(snapshot.weeks) { week in
        let courses = week.number == snapshot.weekNumber
          ? snapshot.courses
          : snapshot.termCourses?[String(week.number)] ?? []
        Button {
          mode = "课程"
          Task { await model.refresh(week: week.number) }
        } label: {
          HStack {
            VStack(alignment: .leading, spacing: 3) {
              Text("第 \(week.number) 周\(week.isCurrent ? " · 本周" : "")")
              Text("\(week.start.formatted(date: .abbreviated, time: .omitted)) – \(week.end.formatted(date: .abbreviated, time: .omitted))")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if courses.isEmpty == false {
              Text("\(courses.count) 门")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
        .foregroundStyle(.primary)
      }
    }
  }

  @ViewBuilder
  private func examContent(_ snapshot: ScheduleSnapshot) -> some View {
    Section("考试安排") {
      if exams.isLoading {
        HStack(spacing: 10) {
          ProgressView()
          Text("正在读取考试安排…")
        }
      } else if let list = exams.exams {
        if list.isEmpty {
          ContentUnavailableView("暂无考试安排", systemImage: "calendar.badge.checkmark", description: Text("学校已返回当前学期的空列表。"))
        } else {
          ForEach(list) { exam in
            VStack(alignment: .leading, spacing: 5) {
              Text(exam.courseName).font(.body.weight(.medium))
              Label(
                [exam.examDate, exam.examTimeDescription ?? [exam.startTime, exam.endTime].compactMap { $0 }.joined(separator: "–")]
                  .compactMap { $0 }.filter { $0.isEmpty == false }.joined(separator: " · "),
                systemImage: "clock"
              )
              .font(.caption)
              .foregroundStyle(.secondary)
              if let place = exam.examPlace, place.isEmpty == false {
                Label(place, systemImage: "mappin.and.ellipse")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .padding(.vertical, 2)
          }
        }
      } else if let error = exams.errorMessage {
        IOSInlineMessage(error, systemImage: "exclamationmark.triangle.fill", tint: .orange)
        Button("重试") { Task { await loadExams(force: true) } }
      } else {
        Button("查询考试安排") { Task { await loadExams(force: true) } }
      }
    }
    .onAppear {
      Task { await loadExams() }
    }
    .onChange(of: exams.needsSessionCheck) { _, needed in
      guard needed else { return }
      Task { _ = try? await appState.confirmSessionAfterAuthFailure() }
    }
    .task(id: snapshot.termID) {
      await loadExams()
    }
  }

  private func filteredCourses(_ courses: [CourseMeeting]) -> [CourseMeeting] {
    let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
    guard term.isEmpty == false else { return courses }
    return courses.filter {
      $0.name.localizedCaseInsensitiveContains(term)
        || ($0.teacher?.localizedCaseInsensitiveContains(term) == true)
        || ($0.place?.localizedCaseInsensitiveContains(term) == true)
    }
  }

  private func dayTitle(_ day: Int, snapshot: ScheduleSnapshot) -> String {
    let name = SchoolTime.weekdayName(day)
    guard let week = snapshot.weeks.first(where: { $0.number == snapshot.weekNumber }),
          let date = SchoolTime.calendar.date(byAdding: .day, value: day - 1, to: week.start) else {
      return name
    }
    return "\(name) · \(date.formatted(.dateTime.month().day()))"
  }

  private func refresh() async {
    await model.refresh()
    if mode == "考试" { await loadExams(force: true) }
  }

  private func loadExams(force: Bool = false) async {
    guard let termID = model.snapshot?.termID else { return }
    await exams.load(termID: termID, force: force, account: appState.user?.schoolid)
  }
}

private struct IOSCourseDetailView: View {
  let meeting: CourseMeeting
  let week: SchoolWeek?

  var body: some View {
    List {
      Section {
        Text(meeting.name)
          .font(.title2.weight(.semibold))
      }
      Section("课程信息") {
        LabeledContent("星期", value: ["周一", "周二", "周三", "周四", "周五", "周六", "周日"][max(0, min(6, meeting.day - 1))])
        LabeledContent("节次", value: "第 \(meeting.startSection)–\(meeting.endSection) 节")
        if let start = meeting.startTime {
          LabeledContent("开始时间", value: start)
        }
        if let end = meeting.endTime {
          LabeledContent("结束时间", value: end)
        }
        if let place = meeting.place, place.isEmpty == false {
          LabeledContent("地点", value: place)
        }
        if let teacher = meeting.teacher, teacher.isEmpty == false {
          LabeledContent("教师", value: teacher)
        }
      }
      if let week {
        Section("周次") {
          LabeledContent("当前周", value: "第 \(week.number) 周")
          LabeledContent("日期", value: "\(week.start.formatted(date: .abbreviated, time: .omitted)) – \(week.end.formatted(date: .abbreviated, time: .omitted))")
        }
      }
    }
    .navigationTitle("课程详情")
    .navigationBarTitleDisplayMode(.inline)
  }
}
