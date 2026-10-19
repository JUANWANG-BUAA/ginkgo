#if os(macOS)

import SwiftUI

private enum GraduateSection: String, CaseIterable, Identifiable {
  case overview = "学分地图"
  case plan = "课程与原文"
  case records = "成绩与考试"
  case profile = "学籍信息"

  var id: String { rawValue }
  var symbol: String {
    switch self {
    case .overview: "chart.bar.xaxis"
    case .plan: "list.clipboard"
    case .records: "doc.text.magnifyingglass"
    case .profile: "person.text.rectangle"
    }
  }
}

/// 研究生教务页。先给培养进度，再按标签页展开培养方案、成绩与学籍，
/// 避免把 59 门课程、成绩和 46 个应用目录一次性铺满页面。
struct GraduateAcademicView: View {
  @EnvironmentObject private var model: GraduateAcademicViewModel
  @EnvironmentObject private var schedule: ScheduleViewModel
  @EnvironmentObject private var appState: AppState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var section: GraduateSection = .overview
  @State private var planSearch = ""
  @State private var planStatus = "全部"
  @State private var planCategory = "全部类别"
  @State private var showPlanSections = false
  @State private var planSectionsPage = 0
  @State private var expandedPlanCategories: Set<String> = []
  @State private var planPageByCategory: [String: Int] = [:]
  @State private var gradePage = 0

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        PageHeading(
          eyebrow: "ACADEMIC / GRADUATE",
          title: "研究生教务",
          subtitle: "看清每一层要求，安排接下来的修读。"
        )
        toolbar
        if let snapshot = model.snapshot {
          sectionPicker
          if let issues = snapshot.issues, !issues.isEmpty {
            DisclosureGroup("部分数据未更新 · \(issues.count) 项") {
              ForEach(issues, id: \.section) { issue in
                Text("\(issue.section.title)：\(issue.usesPreviousData ? "保留上次数据" : "本次未获取") · \(issue.message)")
                  .font(.caption).foregroundStyle(.secondary)
              }
            }
          }
          if model.isLoading && model.isShowingCachedData == false {
            loadingHint
          }
          if let error = model.errorMessage {
            StatusNotice(message: error, kind: .warning)
          }
          switch section {
          case .overview:
            overview(snapshot)
          case .plan:
            planContent(snapshot)
          case .records:
            recordsContent(snapshot)
          case .profile:
            profileContent(snapshot)
          }
        } else if model.isLoading {
          loadingCard
        } else {
          unavailableCard
        }
      }
      .ginkgoPagePadding()
      .frame(maxWidth: 1100, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(Color.ginkgoWindowBackground)
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: section)
    .onChange(of: planSearch) { _, _ in planPageByCategory.removeAll() }
    .onChange(of: planStatus) { _, _ in planPageByCategory.removeAll() }
    .onChange(of: planCategory) { _, _ in planPageByCategory.removeAll() }
    .task(id: appState.user?.schoolid) {
      await load()
    }
  }

  private var toolbar: some View {
    HStack(spacing: 12) {
      if let snapshot = model.snapshot {
        Label(
          "\(model.isShowingCachedData ? "缓存" : "更新")于 \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))",
          systemImage: model.isShowingCachedData ? "clock.arrow.circlepath" : "clock"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      if model.isLoading {
        ProgressView().controlSize(.small)
      }
      Spacer()
      Button {
        guard let account = appState.user?.schoolid else { return }
        Task {
          await model.refresh(account: account)
          await schedule.refreshIfStale(queueIfLoading: true)
        }
      } label: {
        Label("刷新", systemImage: "arrow.clockwise")
      }
      .buttonStyle(.bordered)
      .disabled(model.isLoading)
      .accessibilityLabel("刷新研究生教务与课表")
    }
  }

  private var sectionPicker: some View {
    Picker("查看", selection: $section) {
      ForEach(GraduateSection.allCases) { item in
        Label(item.rawValue, systemImage: item.symbol).tag(item)
      }
    }
    .pickerStyle(.segmented)
    .frame(maxWidth: 620)
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

  // MARK: - 进度

  private func overview(_ snapshot: GraduateAcademicSnapshot) -> some View {
    GraduateRequirementDashboard(snapshot: snapshot, progress: progress(snapshot))
  }

  // MARK: - 培养方案

  private func planContent(_ snapshot: GraduateAcademicSnapshot) -> some View {
    let value = progress(snapshot)
    return VStack(alignment: .leading, spacing: 16) {
      planHeaderCard(snapshot.plan)
      planFilterBar(value)
      planCourseList(value)
    }
  }

  private func planHeaderCard(_ plan: GraduatePlan?) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Label("培养方案", systemImage: "list.clipboard")
        .font(.headline)
      if let plan {
        HStack(alignment: .top, spacing: 16) {
          VStack(alignment: .leading, spacing: 5) {
            Text(plan.title.isEmpty ? "我的培养方案" : plan.title)
              .font(.callout.weight(.semibold))
            HStack(spacing: 12) {
              if let credits = plan.totalCredits { Text("总学分 \(GraduateCredit.text(credits))") }
              if let credits = plan.degreeCourseCredits { Text("学位课 \(GraduateCredit.text(credits))") }
              if let credits = plan.jointCourseCredits { Text("校企课程 \(GraduateCredit.text(credits))") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack(spacing: 12) {
              if let college = plan.college { Text(college) }
              if let major = plan.major { Text(major) }
              if let review = plan.reviewStatus { Text("审核：\(review)") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 3) {
            Text("\(plan.sections.count) 个章节").font(.caption.monospacedDigit())
            Text("\(plan.courses.count) 门课程池").font(.caption.monospacedDigit())
          }
          .foregroundStyle(.secondary)
        }
        if plan.sections.isEmpty == false {
          DisclosureGroup(isExpanded: $showPlanSections) {
            VStack(alignment: .leading, spacing: 10) {
              ForEach(Array(plan.sections.dropFirst(planSectionsPage * 5).prefix(5))) { item in
                VStack(alignment: .leading, spacing: 3) {
                  Text(item.title).font(.callout.weight(.medium))
                  if let content = item.content, content.isEmpty == false {
                    Text(content).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                  } else {
                    Text("该章节未返回正文。").font(.caption).foregroundStyle(.secondary)
                  }
                }
              }
              if plan.sections.count > 5 {
                sectionPager(total: plan.sections.count, page: $planSectionsPage, pageSize: 5)
              }
            }
            .padding(.top, 6)
          } label: {
            Text("方案说明").font(.caption.weight(.medium))
          }
        }
      } else {
        Text("当前账号未返回培养方案。").font(.callout).foregroundStyle(.secondary)
      }
    }
    .graduateCard()
  }

  private func planFilterBar(_ progress: GraduateProgressSummary) -> some View {
    HStack(spacing: 12) {
      SearchField(prompt: "搜索课程、代码或类别", text: $planSearch)
        .frame(maxWidth: .infinity)
      Picker("类别", selection: $planCategory) {
        Text("全部类别").tag("全部类别")
        ForEach(progress.categories) { category in
          Text(category.category).tag(category.category)
        }
      }
      .pickerStyle(.menu)
      .frame(maxWidth: 170)
      Picker("状态", selection: $planStatus) {
      ForEach(["全部", "已修", "在修", "未通过", "待核对", "课程池候选"], id: \.self) { status in
          Text(status).tag(status)
        }
      }
      .pickerStyle(.menu)
      .frame(maxWidth: 130)
    }
  }

  private func planCourseList(_ progress: GraduateProgressSummary) -> some View {
    let filtered = filteredCourses(progress)
    let grouped = Dictionary(grouping: filtered, by: \.category)
    let orderedCategories = progress.categories.map(\.category)
    let order = orderedCategories + grouped.keys.filter { !orderedCategories.contains($0) }.sorted()
    return VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("计划课程池 · \(filtered.count)")
          .font(.headline)
        Spacer()
        Text("课程池不等同于待修清单；状态按成绩、执行报告和本学期课表匹配")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      if filtered.isEmpty {
        ContentUnavailableView.search(text: planSearch)
          .frame(maxWidth: .infinity, minHeight: 180)
      } else {
        ForEach(order.filter { grouped[$0] != nil }, id: \.self) { category in
          let courses = grouped[category] ?? []
          let page = min(planPageByCategory[category] ?? 0, max(0, (courses.count - 1) / 20))
          DisclosureGroup(isExpanded: planCategoryBinding(category)) {
            VStack(alignment: .leading, spacing: 8) {
              ForEach(Array(courses.dropFirst(page * 20).prefix(20))) { course in
                GraduateCourseRow(course: course)
              }
              if courses.count > 20 {
                paginationControls(total: courses.count, page: page, pageSize: 20) { nextPage in
                  planPageByCategory[category] = nextPage
                }
              }
            }
            .padding(.top, 10)
          } label: {
            HStack {
              Label(category, systemImage: "square.stack.3d.up")
                .font(.callout.weight(.semibold))
              Spacer()
              Text("\(courses.count) 门")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
          }
          .padding(14)
          .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 12))
          .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.ginkgoSeparator.opacity(0.55)))
        }
      }
    }
    .graduateCard()
  }

  private func filteredCourses(_ progress: GraduateProgressSummary) -> [GraduateCourseProgress] {
    let query = planSearch.trimmingCharacters(in: .whitespacesAndNewlines)
    return progress.courses.filter { course in
      let categoryMatch = planCategory == "全部类别" || course.category == planCategory
      let statusMatch: Bool
      switch planStatus {
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
        || (course.planCourse.category?.localizedCaseInsensitiveContains(query) ?? false)
      return categoryMatch && statusMatch && searchMatch
    }
  }

  private func planCategoryBinding(_ category: String) -> Binding<Bool> {
    Binding(
      get: { !planSearch.isEmpty || expandedPlanCategories.contains(category) },
      set: { isExpanded in
        if isExpanded { expandedPlanCategories.insert(category) }
        else { expandedPlanCategories.remove(category) }
      }
    )
  }

  private func paginationControls(
    total: Int, page: Int, pageSize: Int, setPage: @escaping (Int) -> Void
  ) -> some View {
    let pages = max(1, Int(ceil(Double(total) / Double(pageSize))))
    return HStack(spacing: 10) {
      Button { setPage(max(0, page - 1)) } label: {
        Label("上一页", systemImage: "chevron.left")
      }
      .disabled(page == 0)
      Button { setPage(min(pages - 1, page + 1)) } label: {
        Label("下一页", systemImage: "chevron.right")
          .labelStyle(.titleAndIcon)
      }
      .disabled(page >= pages - 1)
      Text("第 \(page + 1) / \(pages) 页 · 共 \(total) 条")
        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
    }
    .buttonStyle(.borderless).controlSize(.small)
    .padding(.top, 5)
  }

  private func sectionPager(total: Int, page: Binding<Int>, pageSize: Int) -> some View {
    let pages = max(1, Int(ceil(Double(total) / Double(pageSize))))
    let current = min(page.wrappedValue, pages - 1)
    return HStack(spacing: 10) {
      Button("上一组") { page.wrappedValue = max(0, current - 1) }
        .disabled(current == 0)
      Text("第 \(current + 1) / \(pages) 组")
        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
      Button("下一组") { page.wrappedValue = min(pages - 1, current + 1) }
        .disabled(current >= pages - 1)
    }
    .buttonStyle(.borderless).controlSize(.small)
  }

  // MARK: - 成绩与考试

  private func recordsContent(_ snapshot: GraduateAcademicSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      if let issue = snapshot.issue(for: .exams), !issue.usesPreviousData {
        StatusNotice(message: "考试数据未获取，请刷新重试。", kind: .warning)
      } else {
        VStack(alignment: .leading, spacing: 12) {
          Label("考试安排", systemImage: "calendar.badge.exclamationmark")
            .font(.headline)
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            examTile("考试", snapshot.examSummary.examCount, symbol: "doc.text")
            examTile("考查课程", snapshot.examSummary.quizCourseCount, symbol: "checklist")
            examTile("监考", snapshot.examSummary.invigilationCount, symbol: "person.badge.clock")
          }
          Text(snapshot.examSummary.total == 0
            ? "当前学期没有考试、考查或监考记录。"
            : "数量来自研究生教务我的考试接口；当前只展示汇总。")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .graduateCard()

      }
      if let issue = snapshot.issue(for: .grades), !issue.usesPreviousData {
        StatusNotice(message: "成绩数据未获取，请刷新重试。", kind: .warning)
      } else {
        gradesCard(snapshot.grades)
      }
    }
  }

  private func examTile(_ title: String, _ value: Int, symbol: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
      Text("\(value)").font(.title3.monospacedDigit().weight(.semibold))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color.accentColor.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.ginkgoSeparator.opacity(0.45)))
  }

  private func gradesCard(_ grades: [GraduateGradeRecord]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Label("研究生成绩 · \(grades.count)", systemImage: "chart.bar.doc.horizontal")
          .font(.headline)
        Spacer()
        if grades.isEmpty {
          Text("教务系统当前返回 0 条").font(.caption).foregroundStyle(.secondary)
        }
      }
      if grades.isEmpty {
        Text("当前没有成绩记录。培养方案认定学分请查看学分地图。")
          .font(.callout)
          .foregroundStyle(.secondary)
      } else {
        ForEach(Array(grades.dropFirst(gradePage * 25).prefix(25))) { grade in
          HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(grade.courseName).font(.callout.weight(.medium))
            if let code = grade.courseCode {
              Text(code).font(.caption2.monospaced()).foregroundStyle(.secondary)
            }
            if let category = grade.category {
              Text(category).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if let credits = grade.credits {
              Text("\(GraduateCredit.text(credits)) 学分").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            if let point = grade.gradePoint {
              Text("绩点 \(point)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Text(grade.score ?? "—")
              .font(.callout.monospacedDigit().weight(.semibold))
              .frame(minWidth: 46, alignment: .trailing)
          }
          .padding(.vertical, 3)
          if grade.id != grades.dropFirst(gradePage * 25).prefix(25).last?.id { Divider().opacity(0.45) }
        }
        if grades.count > 25 {
          paginationControls(total: grades.count, page: gradePage, pageSize: 25) { gradePage = $0 }
        }
      }
    }
    .graduateCard()
  }

  // MARK: - 学籍信息

  private func profileContent(_ snapshot: GraduateAcademicSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      statusCard(snapshot.status)
      if let url = GraduateAcademicDestination.portal.url {
        Link(destination: url) {
          Label("前往研究生平台办理其他事项", systemImage: "arrow.up.right.square")
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private func statusCard(_ status: GraduateStatusSummary) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Label("学籍摘要", systemImage: "person.text.rectangle").font(.headline)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], alignment: .leading, spacing: 12) {
        statusRow("学院", status.college)
        statusRow("专业", status.major)
        statusRow("培养层次", status.degreeLevel)
        statusRow("学籍状态", status.status)
        statusRow("年级", status.grade)
        statusRow("学生类别", status.studentType)
        statusRow("班级", status.className)
        statusRow("校区", status.campus)
        statusRow("学习方式", status.studyMode)
        statusRow("入学日期", status.enrollmentDate)
        statusRow("预计毕业", status.expectedGraduation)
      }
      if status.college == nil && status.major == nil && status.status == nil {
        ContentUnavailableView("暂无学籍摘要", systemImage: "person.text.rectangle",
          description: Text("学校当前没有返回可展示的学籍信息。"))
      }
    }
    .graduateCard()
  }

  @ViewBuilder
  private func statusRow(_ title: String, _ value: String?) -> some View {
    if let value, value.isEmpty == false {
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.caption2).foregroundStyle(.secondary)
        Text(value).font(.callout).lineLimit(2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: - 状态

  private var loadingCard: some View {
    HStack(spacing: 12) {
      ProgressView()
      Text("正在读取研究生教务…").foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
    .graduateCard()
  }

  private var loadingHint: some View {
    HStack(spacing: 8) {
      ProgressView().controlSize(.small)
      Text("正在更新，先显示上次缓存").font(.caption).foregroundStyle(.secondary)
    }
  }

  private var unavailableCard: some View {
    VStack(spacing: 12) {
      PageEmptyState(
        symbol: "building.columns",
        title: "暂时无法读取研究生教务",
        detail: model.errorMessage ?? "请检查网络后重试。"
      )
      Button("重试") {
        guard let account = appState.user?.schoolid else { return }
        Task { await model.refresh(account: account) }
      }
      .buttonStyle(.borderedProminent)
    }
  }

}

private struct GraduateCourseRow: View {
  let course: GraduateCourseProgress

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(course.planCourse.name)
          .font(.callout.weight(.medium))
          .lineLimit(1)
        if course.isRequired {
          Text("必修")
            .font(.caption2)
            .foregroundStyle(.orange)
        }
        Spacer()
        statusChip(course.status)
      }
      HStack(spacing: 10) {
        if let code = course.planCourse.code, code.isEmpty == false {
          Text(code).font(.caption2.monospaced())
        }
        if let credits = course.planCourse.credits {
          Text("\(credits.rounded() == credits ? "\(Int(credits))" : String(format: "%.1f", credits)) 学分")
            .font(.caption2.monospacedDigit())
        }
        if let term = course.planCourse.term, term.isEmpty == false {
          Text(term)
        }
        if let examMode = course.planCourse.examMode, examMode.isEmpty == false {
          Text(examMode)
        }
        Spacer()
      }
      .font(.caption)
      .foregroundStyle(.secondary)
      if let note = course.note {
        Text(note)
          .font(.caption2)
          .foregroundStyle(course.status == .needsReview ? Color.orange : Color.secondary)
      }
    }
    .padding(.vertical, 5)
    .accessibilityElement(children: .combine)
  }

  private func statusChip(_ status: GraduateCourseProgressStatus) -> some View {
    Text(status.title)
      .font(.caption2.weight(.medium))
      .padding(.horizontal, 7)
      .padding(.vertical, 2)
      .background(status.tint.opacity(0.12), in: Capsule())
      .foregroundStyle(status.tint)
  }

}

private extension View {
  func graduateCard() -> some View {
    padding(18)
      .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.ginkgoSeparator.opacity(0.55)))
  }
}

#endif
