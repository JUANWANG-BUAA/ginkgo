import SwiftUI

private enum IOSGraduateSection: String, CaseIterable, Identifiable {
  case overview = "学分地图"
  case plan = "课程与原文"
  case records = "成绩与考试"
  case profile = "学籍信息"

  var id: String { rawValue }
}

struct IOSGraduateAcademicView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var schedule: ScheduleViewModel
  @EnvironmentObject private var model: GraduateAcademicViewModel

  @State private var section: IOSGraduateSection = .overview
  @State private var planSectionsPage = 0
  @State private var gradePage = 0

  var body: some View {
    List {
      Section {
        Picker("查看", selection: $section) {
          ForEach(IOSGraduateSection.allCases) { item in
            Text(item.rawValue).tag(item)
          }
        }
        .pickerStyle(.segmented)
      }

      if let snapshot = model.snapshot {
        if let issues = snapshot.issues, !issues.isEmpty {
          Section {
            DisclosureGroup("部分数据未更新 · \(issues.count) 项") {
              ForEach(issues, id: \.section) { issue in
                Text("\(issue.section.title)：\(issue.usesPreviousData ? "保留上次数据" : "本次未获取") · \(issue.message)")
                  .font(.caption).foregroundStyle(.secondary)
              }
            }
          }
        }
        if model.isShowingCachedData && model.isLoading {
          Section {
            HStack(spacing: 8) {
              ProgressView().controlSize(.small)
              Text("正在更新，先显示上次缓存").font(.caption).foregroundStyle(.secondary)
            }
          }
        }
        if let error = model.errorMessage {
          Section {
            Label(error, systemImage: "exclamationmark.triangle")
              .font(.caption)
              .foregroundStyle(.orange)
          }
        }
        switch section {
        case .overview:
          overview(snapshot)
        case .plan:
          planOverview(snapshot)
        case .records:
          records(snapshot)
        case .profile:
          profile(snapshot)
        }
      } else if model.isLoading {
        Section {
          HStack(spacing: 12) {
            ProgressView()
            Text("正在读取研究生教务…").foregroundStyle(.secondary)
          }
          .frame(minHeight: 180)
        }
      } else {
        Section {
          ContentUnavailableView(
            "暂时无法读取研究生教务",
            systemImage: "building.columns",
            description: Text(model.errorMessage ?? "请检查网络后重试。")
          )
          Button("重试") { Task { await load() } }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("研究生教务")
    .refreshable { await load() }
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          guard let account = appState.user?.schoolid else { return }
          Task {
            await model.refresh(account: account)
            await schedule.refreshIfStale(queueIfLoading: true)
          }
        } label: {
          if model.isLoading {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: "arrow.clockwise")
          }
        }
        .disabled(model.isLoading)
        .accessibilityLabel("刷新研究生教务与课表")
      }
    }
    .task(id: appState.user?.schoolid) {
      await load()
    }
  }

  private func load() async {
    guard let account = appState.user?.schoolid else { return }
    await model.start(account: account)
    await model.refreshIfStale(account: account)
    await schedule.start(account: account)
    await schedule.refreshIfStale(queueIfLoading: true)
  }

  private func progress(_ snapshot: GraduateAcademicSnapshot) -> GraduateProgressSummary {
    GraduateProgressBuilder.build(academic: snapshot, schedule: schedule.snapshot)
  }

  @ViewBuilder
  private func overview(_ snapshot: GraduateAcademicSnapshot) -> some View {
    Section {
      GraduateRequirementDashboard(snapshot: snapshot, progress: progress(snapshot))
        .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
    }
  }

  private func planOverview(_ snapshot: GraduateAcademicSnapshot) -> some View {
    let value = progress(snapshot)
    return Group {
      if let plan = snapshot.plan {
        Section("培养方案") {
          Text(plan.title.isEmpty ? "我的培养方案" : plan.title).font(.headline)
          if let credits = plan.totalCredits {
            LabeledContent("总学分", value: GraduateCredit.text(credits))
          }
          if let credits = plan.degreeCourseCredits {
            LabeledContent("学位课学分", value: GraduateCredit.text(credits))
          }
          if let credits = plan.jointCourseCredits {
            LabeledContent("校企课程学分", value: GraduateCredit.text(credits))
          }
          if let college = plan.college { LabeledContent("学院", value: college) }
          if let major = plan.major { LabeledContent("专业", value: major) }
          if let review = plan.reviewStatus { LabeledContent("审核状态", value: review) }
        }

        if plan.sections.isEmpty == false {
          Section("方案说明") {
            ForEach(Array(plan.sections.dropFirst(planSectionsPage * 5).prefix(5))) { item in
              DisclosureGroup {
                if let content = item.content, content.isEmpty == false {
                  Text(content).font(.caption).textSelection(.enabled)
                } else {
                  Text("该章节未返回正文。").font(.caption).foregroundStyle(.secondary)
                }
              } label: {
                Text(item.title).font(.callout)
              }
            }
            if plan.sections.count > 5 {
              sectionPager(total: plan.sections.count, page: $planSectionsPage, pageSize: 5)
            }
          }
        }

        Section {
          NavigationLink {
            IOSGraduatePlanProgressView(plan: plan, progress: value)
          } label: {
            Label("查看全部计划课程与进度", systemImage: "list.clipboard")
          }
        } footer: {
          Text("方案已认定 \(GraduateCredit.text(value.completedCredits))；本学期在修 \(value.currentTermInProgressCredits.map(GraduateCredit.text) ?? "待核对")；距离总要求 \(GraduateCredit.text(value.remainingCredits))。")
        }
      } else {
        Section("培养方案") {
          Text("当前账号未返回培养方案。").foregroundStyle(.secondary)
        }
      }
    }
  }

  private func records(_ snapshot: GraduateAcademicSnapshot) -> some View {
    Group {
      if let issue = snapshot.issue(for: .exams), !issue.usesPreviousData {
          Section("考试安排") { Text("本次未能获取考试数据，请刷新重试。").foregroundStyle(.secondary) }
        } else {
        Section("考试安排") {
          LabeledContent("考试", value: "\(snapshot.examSummary.examCount)")
          LabeledContent("考查课程", value: "\(snapshot.examSummary.quizCourseCount)")
          LabeledContent("监考", value: "\(snapshot.examSummary.invigilationCount)")
          Text(snapshot.examSummary.total == 0
            ? "当前学期没有考试、考查或监考记录。"
            : "数量来自研究生教务我的考试接口。")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

      }
      if let issue = snapshot.issue(for: .grades), !issue.usesPreviousData {
        Section("研究生成绩") { Text("本次未能获取成绩数据，请刷新重试。").foregroundStyle(.secondary) }
      } else {
        Section("研究生成绩 · \(snapshot.grades.count)") {
          if snapshot.grades.isEmpty {
            ContentUnavailableView(
              "暂无研究生成绩",
              systemImage: "chart.bar.doc.horizontal",
              description: Text("教务系统当前返回 0 条成绩记录；培养方案认定学分请查看学分地图。")
            )
          } else {
            ForEach(Array(snapshot.grades.dropFirst(gradePage * 25).prefix(25))) { grade in
              VStack(alignment: .leading, spacing: 4) {
                HStack {
                  Text(grade.courseName).font(.body.weight(.medium))
                  Spacer()
                  if let score = grade.score {
                    Text(score).font(.body.monospacedDigit().weight(.semibold))
                  }
                }
                HStack(spacing: 10) {
                  if let code = grade.courseCode { Text(code).font(.caption2.monospaced()) }
                  if let credits = grade.credits { Text("\(GraduateCredit.text(credits)) 学分") }
                  if let point = grade.gradePoint { Text("绩点 \(point)") }
                  if let category = grade.category { Text(category) }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
              }
            }
            if snapshot.grades.count > 25 {
              sectionPager(total: snapshot.grades.count, page: $gradePage, pageSize: 25)
            }
          }
        }
      }
    }
  }

  private func profile(_ snapshot: GraduateAcademicSnapshot) -> some View {
    Group {
      Section {
        optionalRow("学院", snapshot.status.college)
        optionalRow("专业", snapshot.status.major)
        optionalRow("年级", snapshot.status.grade)
        optionalRow("培养层次", snapshot.status.degreeLevel)
        optionalRow("学生类别", snapshot.status.studentType)
        optionalRow("学籍状态", snapshot.status.status)
        optionalRow("班级", snapshot.status.className)
        optionalRow("校区", snapshot.status.campus)
        optionalRow("学习方式", snapshot.status.studyMode)
        optionalRow("入学日期", snapshot.status.enrollmentDate)
        optionalRow("预计毕业", snapshot.status.expectedGraduation)
      } header: {
        Text("学籍摘要")
      } footer: {
        if let url = GraduateAcademicDestination.portal.url {
          Link("前往研究生平台办理其他事项", destination: url)
        }
      }
    }
  }

  @ViewBuilder
  private func optionalRow(_ title: String, _ value: String?) -> some View {
    if let value, value.isEmpty == false {
      LabeledContent(title, value: value)
    }
  }

  private func percent(_ value: Double) -> String {
    "\(Int((value * 100).rounded()))%"
  }

  private func sectionPager(total: Int, page: Binding<Int>, pageSize: Int) -> some View {
    let pages = max(1, Int(ceil(Double(total) / Double(pageSize))))
    let current = min(page.wrappedValue, pages - 1)
    return HStack(spacing: 12) {
      Button("上一页") { page.wrappedValue = max(0, current - 1) }
        .disabled(current == 0)
      Text("第 \(current + 1) / \(pages) 页 · 共 \(total) 条")
        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
      Button("下一页") { page.wrappedValue = min(pages - 1, current + 1) }
        .disabled(current >= pages - 1)
    }
    .buttonStyle(.borderless)
  }

}

private struct IOSGraduatePlanProgressView: View {
  let plan: GraduatePlan
  let progress: GraduateProgressSummary

  @State private var searchText = ""
  @State private var statusFilter = "全部"
  @State private var categoryFilter = "全部类别"
  @State private var sectionPage = 0
  @State private var expandedCategories: Set<String> = []
  @State private var pageByCategory: [String: Int] = [:]

  private var filteredCourses: [GraduateCourseProgress] {
    let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    return progress.courses.filter { course in
      let categoryMatch = categoryFilter == "全部类别" || course.category == categoryFilter
      let statusMatch: Bool
      switch statusFilter {
      case "已修": statusMatch = course.status == .completed
      case "在修": statusMatch = course.status == .inProgress
      case "未通过": statusMatch = course.status == .notPassed
      case "课程池候选": statusMatch = course.status == .remaining
      case "待核对": statusMatch = course.status == .needsReview
      default: statusMatch = true
      }
      let searchMatch = query.isEmpty
        || course.planCourse.name.localizedCaseInsensitiveContains(query)
        || (course.planCourse.code?.localizedCaseInsensitiveContains(query) ?? false)
      return categoryMatch && statusMatch && searchMatch
    }
  }

  var body: some View {
    List {
      Section("筛选") {
        Picker("类别", selection: $categoryFilter) {
          Text("全部类别").tag("全部类别")
          ForEach(progress.categories) { category in
            Text(category.category).tag(category.category)
          }
        }
        Picker("状态", selection: $statusFilter) {
          ForEach(["全部", "已修", "在修", "未通过", "待核对", "课程池候选"], id: \.self) { status in
            Text(status).tag(status)
          }
        }
        .pickerStyle(.segmented)
      }

      if plan.sections.isEmpty == false {
        Section("方案说明") {
          ForEach(Array(plan.sections.dropFirst(sectionPage * 5).prefix(5))) { item in
            DisclosureGroup {
              if let content = item.content, content.isEmpty == false {
                Text(content).font(.caption).textSelection(.enabled)
              } else {
                Text("该章节未返回正文。").font(.caption).foregroundStyle(.secondary)
              }
            } label: {
              Text(item.title).font(.callout)
            }
          }
        }
        if plan.sections.count > 5 {
          Section {
            let pages = max(1, Int(ceil(Double(plan.sections.count) / 5)))
            let page = min(sectionPage, pages - 1)
            HStack {
              Button("上一组") { sectionPage = max(0, page - 1) }.disabled(page == 0)
              Spacer()
              Text("第 \(page + 1) / \(pages) 组").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
              Spacer()
              Button("下一组") { sectionPage = min(pages - 1, page + 1) }.disabled(page >= pages - 1)
            }
          }
        }
      }

      let grouped = Dictionary(grouping: filteredCourses, by: \.category)
      let categoryOrder = progress.categories.map(\.category)
      let order = categoryOrder.filter { grouped[$0] != nil }
        + grouped.keys.filter { !categoryOrder.contains($0) }.sorted()
      ForEach(order, id: \.self) { category in
        Section {
          let courses = grouped[category] ?? []
          let pages = max(1, Int(ceil(Double(courses.count) / 20)))
          let page = min(pageByCategory[category] ?? 0, pages - 1)
          DisclosureGroup(isExpanded: categoryBinding(category)) {
            ForEach(Array(courses.dropFirst(page * 20).prefix(20))) { course in
              IOSGraduateCourseRow(course: course)
            }
            if courses.count > 20 {
              HStack {
                Button("上一页") { pageByCategory[category] = max(0, page - 1) }
                  .disabled(page == 0)
                Spacer()
                Text("第 \(page + 1) / \(pages) 页 · 共 \(courses.count) 门")
                  .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Spacer()
                Button("下一页") { pageByCategory[category] = min(pages - 1, page + 1) }
                  .disabled(page >= pages - 1)
              }
              .buttonStyle(.borderless)
            }
          } label: {
            LabeledContent(category, value: "\(courses.count) 门")
          }
        } header: {
          Text(category)
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("培养方案")
    .navigationBarTitleDisplayMode(.inline)
    .searchable(text: $searchText, prompt: "搜索课程或代码")
  }

  private func categoryBinding(_ category: String) -> Binding<Bool> {
    Binding(
      get: { !searchText.isEmpty || expandedCategories.contains(category) },
      set: { isExpanded in
        if isExpanded { expandedCategories.insert(category) }
        else { expandedCategories.remove(category) }
      }
    )
  }
}

private struct IOSGraduateCourseRow: View {
  let course: GraduateCourseProgress

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(course.planCourse.name).font(.callout.weight(.medium))
        if course.isRequired {
          Text("必修").font(.caption2).foregroundStyle(.orange)
        }
        Spacer()
        Text(course.status.title)
          .font(.caption2.weight(.medium))
          .padding(.horizontal, 7)
          .padding(.vertical, 2)
          .background(course.status.tint.opacity(0.12), in: Capsule())
          .foregroundStyle(course.status.tint)
      }
      HStack(spacing: 10) {
        if let code = course.planCourse.code, code.isEmpty == false {
          Text(code).font(.caption2.monospaced())
        }
        if let credits = course.planCourse.credits {
          Text("\(GraduateCredit.text(credits)) 学分").font(.caption2.monospacedDigit())
        }
        if let term = course.planCourse.term { Text(term) }
        if let examMode = course.planCourse.examMode { Text(examMode) }
        Spacer()
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      if let note = course.note {
        Text(note).font(.caption2).foregroundStyle(course.status == .needsReview ? Color.orange : Color.secondary)
      }
    }
    .padding(.vertical, 3)
  }

}
