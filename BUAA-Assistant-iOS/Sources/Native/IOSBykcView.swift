import SwiftUI

struct IOSBykcView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var model: BykcViewModel
  @State private var mode = "课程"

  var body: some View {
    List {
      if let snapshot = model.snapshot {
        summary(snapshot)
        Section {
          Picker("查看", selection: $mode) {
            Text("课程").tag("课程")
            Text("已选").tag("已选")
            Text("统计").tag("统计")
          }
          .pickerStyle(.segmented)
        }
        if model.isLoading {
          Section {
            HStack(spacing: 10) {
              ProgressView()
              Text("正在刷新博雅数据…").foregroundStyle(.secondary)
            }
          }
        }
        if let message = model.errorMessage {
          Section {
            Label(message, systemImage: "exclamationmark.triangle")
              .foregroundStyle(.orange)
          }
        }
        switch mode {
        case "已选":
          chosenContent(snapshot)
        case "统计":
          statisticsContent(snapshot)
        default:
          courseContent(snapshot)
        }
      } else if model.isLoading {
        Section {
          HStack(spacing: 12) {
            ProgressView()
            Text("正在读取博雅课程…").foregroundStyle(.secondary)
          }
          .frame(minHeight: 180)
        }
      } else {
        Section {
          ContentUnavailableView(
            "暂时无法读取博雅",
            systemImage: "graduationcap",
            description: Text(model.errorMessage ?? "请检查网络后重试。")
          )
          Button("重试") {
            guard let account = appState.user?.schoolid else { return }
            Task { await model.refresh(account: account) }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("博雅")
    .searchable(text: $model.searchText, prompt: "搜索课程、教师或地点")
    .refreshable {
      guard let account = appState.user?.schoolid else { return }
      await model.refreshIfStale(account: account, maxAge: 0)
    }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          guard let account = appState.user?.schoolid else { return }
          Task { await model.refresh(account: account) }
        } label: {
          if model.isLoading {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: "arrow.clockwise")
          }
        }
        .disabled(model.isLoading)
        .accessibilityLabel("刷新博雅")
      }
    }
    .task(id: appState.user?.schoolid) {
      guard let account = appState.user?.schoolid else { return }
      await model.start(account: account)
      await model.refreshIfStale(account: account)
    }
  }

  @ViewBuilder
  private func summary(_ snapshot: BykcSnapshot) -> some View {
    Section {
      LabeledContent("课程库", value: "\(snapshot.courses.count) 门")
      LabeledContent("已选课程", value: "\(snapshot.chosen.count) 门")
      LabeledContent("有效课程", value: "\(snapshot.validCourseCount) 门")
      if let semester = snapshot.currentSemester {
        LabeledContent("当前学期", value: semester.name)
      }
      if let termName = snapshot.profile.termName, termName.isEmpty == false {
        LabeledContent("博雅学期", value: termName)
      }
      if let college = snapshot.profile.collegeName, college.isEmpty == false {
        LabeledContent("学院", value: college)
      }
      if let studentType = snapshot.profile.studentType, studentType.isEmpty == false {
        LabeledContent("学生类型", value: studentType)
      }
      if let className = snapshot.profile.className, className.isEmpty == false {
        LabeledContent("班级", value: className)
      }
      if let semester = snapshot.currentSemester,
         let start = BykcDate.display(semester.startDate),
         let end = BykcDate.display(semester.endDate) {
        LabeledContent("学期范围", value: "\(start) – \(end)")
      }
      LabeledContent(
        model.isShowingCachedData ? "缓存于" : "更新于",
        value: snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened)
      )
    } header: {
      Text("概览")
    } footer: {
      Text("这里仅读取博雅课程、已选记录和统计，不执行选课、退选或签到。")
    }
  }

  @ViewBuilder
  private func courseContent(_ snapshot: BykcSnapshot) -> some View {
    Section {
      if snapshot.courses.isEmpty {
        ContentUnavailableView(
          "当前学期暂无课程",
          systemImage: "books.vertical",
          description: Text("学校尚未返回该学期的博雅课程库。")
        )
      } else if model.filteredCourses.isEmpty {
        ContentUnavailableView.search(text: model.searchText)
      } else {
        ForEach(model.filteredCourses) { course in
          NavigationLink {
            IOSBykcCourseDetailView(course: course)
          } label: {
            IOSBykcCourseRow(course: course)
          }
        }
      }
    } header: {
      HStack {
        Text("课程库 · \(model.filteredCourses.count)")
        Spacer()
        Menu {
          ForEach(model.categories) { category in
            Button {
              model.selectedCategory = category
            } label: {
              if category == model.selectedCategory {
                Label(BykcCoursePresentation.categoryTitle(category), systemImage: "checkmark")
              } else {
                Text(BykcCoursePresentation.categoryTitle(category))
              }
            }
          }
        } label: {
          Label(
            BykcCoursePresentation.categoryTitle(model.selectedCategory),
            systemImage: "line.3.horizontal.decrease.circle"
          )
            .font(.caption)
        }
      }
    }
  }

  @ViewBuilder
  private func chosenContent(_ snapshot: BykcSnapshot) -> some View {
    Section("已选课程 · \(snapshot.chosen.count)") {
      if snapshot.chosen.isEmpty {
        ContentUnavailableView(
          "尚未选择博雅课程",
          systemImage: "checkmark.circle",
          description: Text("当前学期返回 0 条已选记录。")
        )
      } else {
        ForEach(snapshot.chosen) { chosen in
          NavigationLink {
            IOSBykcCourseDetailView(course: chosen.course)
          } label: {
            VStack(alignment: .leading, spacing: 6) {
              Text(chosen.course.name).font(.body.weight(.medium))
              if let selectedAt = chosen.selectedAt {
                Label(
                  "选择于 \(BykcDate.display(selectedAt) ?? selectedAt)",
                  systemImage: "calendar.badge.checkmark"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
              }
              HStack(spacing: 12) {
                if let checkin = chosen.checkin {
                  Text(checkin == 1 ? "已签到" : "考勤 \(checkin)")
                }
                if let passed = chosen.passed {
                  Text(passed == 1 ? "已通过" : "未通过")
                }
                if let score = chosen.score {
                  Text("成绩 \(score)")
                }
              }
              .font(.caption)
              .foregroundStyle(.secondary)
            }
          }
        }
      }
    }
  }

  @ViewBuilder
  private func statisticsContent(_ snapshot: BykcSnapshot) -> some View {
    Section {
      if snapshot.statistics.isEmpty {
        ContentUnavailableView(
          "暂无博雅统计",
          systemImage: "chart.bar",
          description: Text("当前学期尚未返回应完成/已完成统计。")
        )
      } else {
        ForEach(snapshot.statistics) { item in
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              VStack(alignment: .leading, spacing: 3) {
                Text(item.category).font(.body.weight(.medium))
                Text(item.subcategory).font(.caption).foregroundStyle(.secondary)
              }
              Spacer()
              Text("\(item.completed)/\(item.required)")
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(item.isComplete ? .green : .secondary)
            }
            ProgressView(value: item.progress)
              .tint(item.isComplete ? .green : .accentColor)
            Text(item.isComplete ? "已完成" : "还差 \(max(0, item.required - item.completed)) 项")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 3)
        }
      }
    } header: {
      Text("博雅完成情况")
    } footer: {
      Text("统计字段来自博雅 queryStatisticByUserId；0/0 表示当前学期没有要求。")
    }
  }
}

private struct IOSBykcCourseRow: View {
  let course: BykcCourse

  var body: some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(alignment: .firstTextBaseline) {
        Text(course.name).font(.body.weight(.medium))
        Spacer(minLength: 8)
        if course.selected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
            .accessibilityLabel("已选")
        }
      }
      HStack(spacing: 6) {
        if let category = course.category {
          IOSDataTag(text: category, color: .accentColor)
        }
        if let subcategory = course.subcategory {
          IOSDataTag(text: subcategory, color: .orange)
        }
        if course.hasSignConfig {
          IOSDataTag(text: "含签到", color: .blue)
        }
      }
      if let teacher = course.teacher {
        Label(teacher, systemImage: "person")
      }
      if let position = course.position {
        Label(position, systemImage: "mappin.and.ellipse")
      }
      HStack(spacing: 12) {
        if let availability = BykcCoursePresentation.availabilityText(for: course) {
          Label(availability, systemImage: "person.2")
        }
        if course.campuses.isEmpty == false {
          Label(course.campuses.joined(separator: "、"), systemImage: "building.2")
        }
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(.vertical, 4)
    .accessibilityElement(children: .combine)
  }
}

private struct IOSBykcCourseDetailView: View {
  let course: BykcCourse

  var body: some View {
    List {
      Section {
        Text(course.name).font(.title2.weight(.semibold))
        if let category = course.category {
          LabeledContent("类别", value: category)
        }
        if let subcategory = course.subcategory {
          LabeledContent("方向", value: subcategory)
        }
        if let teacher = course.teacher {
          LabeledContent("教师", value: teacher)
        }
        if let position = course.position {
          LabeledContent("地点", value: position)
        }
        if course.campuses.isEmpty == false {
          LabeledContent("校区", value: course.campuses.joined(separator: "、"))
        }
        if let availability = BykcCoursePresentation.availabilityText(for: course) {
          LabeledContent("人数", value: availability)
        }
        LabeledContent("签到", value: course.hasSignConfig ? "含签到配置" : "无签到配置")
      }

      Section("课程时间") {
        dateRow("开始", course.startDate)
        dateRow("结束", course.endDate)
      }

      Section("选择窗口") {
        dateRow("开放", course.selectStartDate)
        dateRow("截止", course.selectEndDate)
        dateRow("退选截止", course.cancelEndDate)
      }

      if let summary = course.summary {
        Section("课程简介") {
          Text(summary)
            .textSelection(.enabled)
        }
      }

      Section {
        Label(
          course.selected ? "已选入当前学期" : "尚未选择该课程",
          systemImage: course.selected ? "checkmark.circle.fill" : "circle"
        )
        .foregroundStyle(course.selected ? .green : .secondary)
      } footer: {
        Text("Ginkgo 当前只读取博雅数据，选课、退选和签到请前往学校原系统操作。")
      }
    }
    .navigationTitle("博雅课程")
    .navigationBarTitleDisplayMode(.inline)
  }

  @ViewBuilder
  private func dateRow(_ title: String, _ raw: String?) -> some View {
    if let raw {
      LabeledContent(title, value: BykcDate.display(raw) ?? raw)
    }
  }
}

struct IOSDataTag: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text)
      .font(.caption2.weight(.medium))
      .padding(.horizontal, 7)
      .padding(.vertical, 2)
      .background(color.opacity(0.12), in: Capsule())
      .foregroundStyle(color)
  }
}
