#if os(macOS)

import SwiftUI

/// 博雅课程只读页：课程库、已选课程与完成统计。
/// 选课、退选和签到不在本页开放。
struct BykcView: View {
  @EnvironmentObject private var model: BykcViewModel
  @EnvironmentObject private var appState: AppState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var mode = "课程"
  @State private var selectedCourse: BykcCourse?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        AcademicPageHeader(
          section: "教务 · 通识课程",
          title: "博雅",
          subtitle: "课程库、已选记录与完成统计；仅读取学校数据",
          symbol: "books.vertical"
        )
        if let snapshot = model.snapshot {
          summary(snapshot)
          Picker("查看", selection: $mode) {
            Text("课程库").tag("课程")
            Text("已选课程").tag("已选")
            Text("完成统计").tag("统计")
          }
          .pickerStyle(.segmented)
          .frame(maxWidth: 360)
          if let error = model.errorMessage {
            StatusNotice(message: error, kind: .warning)
          }
          switch mode {
          case "已选":
            chosenContent(snapshot)
          case "统计":
            statisticsContent(snapshot)
          default:
            courseContent(snapshot)
          }
          Text("数据更新于 \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))。")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else if model.isLoading {
          HStack(spacing: 12) {
            ProgressView()
            Text("正在读取博雅课程…").foregroundStyle(.secondary)
          }
          .frame(maxWidth: .infinity, minHeight: 220, alignment: .center)
          .bykcCard()
        } else {
          VStack(spacing: 12) {
            PageEmptyState(
              symbol: "graduationcap",
              title: "暂时无法读取博雅",
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
      .ginkgoPagePadding()
      .frame(maxWidth: 1100, alignment: .leading)
      .frame(maxWidth: .infinity)
    }
    .background(Color.ginkgoWindowBackground)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button { Task { await model.refresh(account: appState.user?.schoolid) } } label: {
          if model.isLoading {
            ProgressView().controlSize(.small)
          } else {
            Label("刷新博雅", systemImage: "arrow.clockwise")
          }
        }
        .disabled(model.isLoading)
        .accessibilityLabel("刷新博雅")
        .keyboardShortcut("r", modifiers: .command)
      }
    }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: mode)
    .task(id: appState.user?.schoolid) {
      guard let account = appState.user?.schoolid else { return }
      await model.start(account: account)
      await model.refreshIfStale(account: account)
    }
    .sheet(item: $selectedCourse) { course in
      BykcCourseDetailSheet(course: course)
    }
  }

  private func summary(_ snapshot: BykcSnapshot) -> some View {
    let semesterRange: String? = {
      guard let semester = snapshot.currentSemester,
            let start = BykcDate.display(semester.startDate),
            let end = BykcDate.display(semester.endDate) else { return nil }
      return "\(start) – \(end)"
    }()
    let metrics = [
      AcademicMetric(id: "catalog", title: "课程库", value: "\(snapshot.courses.count) 门", symbol: "books.vertical", tint: .primary),
      AcademicMetric(id: "chosen", title: "已选课程", value: "\(snapshot.chosen.count) 门", symbol: "checkmark.circle", tint: .primary),
      AcademicMetric(id: "valid", title: "有效课程", value: "\(snapshot.validCourseCount) 门", symbol: "checkmark.seal", tint: .primary),
      AcademicMetric(
        id: "semester",
        title: "当前学期",
        value: snapshot.currentSemester?.name ?? "未确认",
        detail: semesterRange,
        symbol: "calendar",
        tint: .primary
      )
    ]
    let profileItems: [(String, String)] = [
      snapshot.profile.termName.map { ("博雅学期：\($0)", "calendar.badge.clock") },
      snapshot.profile.collegeName.map { ($0, "building.columns") },
      snapshot.profile.studentType.map { ($0, "person.text.rectangle") },
      snapshot.profile.className.map { ($0, "person.3") }
    ].compactMap { $0 }

    return VStack(alignment: .leading, spacing: 10) {
      AcademicMetricStrip(metrics: metrics)
      if !profileItems.isEmpty {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .leading)], alignment: .leading, spacing: 8) {
          ForEach(profileItems.indices, id: \.self) { index in
            Label(profileItems[index].0, systemImage: profileItems[index].1)
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
        .padding(.horizontal, 6)
      }
      HStack {
        Label(
          model.isShowingCachedData ? "显示缓存数据" : "数据已同步",
          systemImage: model.isShowingCachedData ? "clock.arrow.circlepath" : "checkmark.circle"
        )
        Spacer()
        Text("更新于 \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
  }

  private func courseContent(_ snapshot: BykcSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
        SearchField(prompt: "搜索课程、教师或地点", text: $model.searchText)
          .frame(maxWidth: .infinity)
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
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: 180)
      }
      .academicPanel(inset: 10)
      AcademicSectionHeading(title: "课程库", detail: "显示 \(model.filteredCourses.count) 门")
      if snapshot.courses.isEmpty {
        PageEmptyState(
          symbol: "books.vertical",
          title: "当前学期暂无课程",
          detail: "学校尚未返回该学期的博雅课程库。"
        )
      } else if model.filteredCourses.isEmpty {
        ContentUnavailableView.search(text: model.searchText)
          .frame(maxWidth: .infinity, minHeight: 220)
      } else {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
          ForEach(model.filteredCourses) { course in
            BykcCourseCard(course: course) {
              selectedCourse = course
            }
          }
        }
      }
    }
  }

  private func chosenContent(_ snapshot: BykcSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("已选课程 · \(snapshot.chosen.count)")
        .font(.headline)
      if snapshot.chosen.isEmpty {
        Text("当前学期返回 0 条已选记录。")
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
      } else {
        ForEach(snapshot.chosen) { chosen in
          Button {
            selectedCourse = chosen.course
          } label: {
            HStack(alignment: .top, spacing: 12) {
              VStack(alignment: .leading, spacing: 5) {
                Text(chosen.course.name).font(.callout.weight(.medium))
                HStack(spacing: 10) {
                  if let selectedAt = chosen.selectedAt {
                    Label(
                      "选择于 \(BykcDate.display(selectedAt) ?? selectedAt)",
                      systemImage: "calendar.badge.checkmark"
                    )
                  }
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
              Spacer()
              Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          if chosen.id != snapshot.chosen.last?.id {
            Divider().opacity(0.5)
          }
        }
      }
    }
    .bykcCard()
  }

  private func statisticsContent(_ snapshot: BykcSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("博雅完成情况").font(.headline)
      if snapshot.statistics.isEmpty {
        Text("当前学期尚未返回应完成/已完成统计。")
          .font(.callout)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
      } else {
        ForEach(snapshot.statistics) { item in
          VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
              VStack(alignment: .leading, spacing: 2) {
                Text(item.category).font(.callout.weight(.medium))
                Text(item.subcategory).font(.caption).foregroundStyle(.secondary)
              }
              Spacer()
              Text("\(item.completed)/\(item.required)")
                .font(.callout.monospacedDigit().weight(.semibold))
                .foregroundStyle(item.isComplete ? Color.green : Color.secondary)
            }
            ProgressView(value: item.progress)
              .tint(item.isComplete ? Color.green : Color.accentColor)
            Text(item.isComplete ? "已完成" : "还差 \(max(0, item.required - item.completed)) 项")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .padding(.vertical, 4)
        }
      }
      Text("统计字段来自博雅 queryStatisticByUserId；0/0 表示当前学期没有要求。")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .bykcCard()
  }
}

private struct BykcCourseCard: View {
  let course: BykcCourse
  let onOpen: () -> Void

  var body: some View {
    Button(action: onOpen) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline) {
          Text(course.name).font(.headline)
          Spacer(minLength: 6)
          if course.selected {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(.green)
              .accessibilityLabel("已选")
          }
        }
        HStack(spacing: 6) {
          if let category = course.category {
            tag(category, color: .accentColor)
          }
          if let subcategory = course.subcategory {
            tag(subcategory, color: .orange)
          }
          if course.hasSignConfig {
            tag("含签到", color: .blue)
          }
        }
        if let teacher = course.teacher {
          Label(teacher, systemImage: "person").font(.caption)
        }
        if let position = course.position {
          Label(position, systemImage: "mappin.and.ellipse").font(.caption)
        }
        HStack(spacing: 10) {
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
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.07)))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(course.name)，\(course.category ?? "")")
    .accessibilityHint("查看课程详情")
  }

  private func tag(_ text: String, color: Color) -> some View {
    Text(text)
      .font(.caption2.weight(.medium))
      .padding(.horizontal, 7)
      .padding(.vertical, 2)
      .background(color.opacity(0.12), in: Capsule())
      .foregroundStyle(color)
  }
}

private struct BykcCourseDetailSheet: View {
  let course: BykcCourse
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 5) {
            Text(course.name).font(.title2.weight(.semibold))
            if let summary = course.summary, summary.isEmpty == false {
              Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
          }
          Spacer()
          Button("关闭") { dismiss() }.keyboardShortcut(.cancelAction)
        }

        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], alignment: .leading, spacing: 12) {
          row("类别", course.category)
          row("方向", course.subcategory)
          row("教师", course.teacher)
          row("地点", course.position)
          row("校区", course.campuses.isEmpty ? nil : course.campuses.joined(separator: "、"))
          row("人数", BykcCoursePresentation.availabilityText(for: course))
          row("签到", course.hasSignConfig ? "含签到配置" : "无签到配置")
        }
        .bykcCard()

        VStack(alignment: .leading, spacing: 10) {
          Text("课程时间").font(.headline)
          row("开始", BykcDate.display(course.startDate))
          row("结束", BykcDate.display(course.endDate))
        }
        .bykcCard()

        VStack(alignment: .leading, spacing: 10) {
          Text("选择窗口").font(.headline)
          row("开放", BykcDate.display(course.selectStartDate))
          row("截止", BykcDate.display(course.selectEndDate))
          row("退选截止", BykcDate.display(course.cancelEndDate))
        }
        .bykcCard()

        if let summary = course.summary, summary.isEmpty == false {
          VStack(alignment: .leading, spacing: 8) {
            Text("课程简介").font(.headline)
            Text(summary)
              .font(.callout)
              .textSelection(.enabled)
          }
          .bykcCard()
        }

        VStack(alignment: .leading, spacing: 8) {
          Label(
            course.selected ? "已选入当前学期" : "尚未选择该课程",
            systemImage: course.selected ? "checkmark.circle.fill" : "circle"
          )
          .foregroundStyle(course.selected ? Color.green : Color.secondary)
          Text("Ginkgo 当前只读取博雅数据；选课、退选和签到请前往学校原系统操作。")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .bykcCard()
      }
      .padding(22)
    }
    .frame(minWidth: 560, idealWidth: 680, minHeight: 520, idealHeight: 700)
    .background(Color.ginkgoWindowBackground)
  }

  @ViewBuilder
  private func row(_ title: String, _ value: String?) -> some View {
    if let value, value.isEmpty == false {
      VStack(alignment: .leading, spacing: 3) {
        Text(title).font(.caption2).foregroundStyle(.secondary)
        Text(value).font(.callout).lineLimit(2)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

private extension View {
  func bykcCard() -> some View {
    padding(18)
      .background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.07)))
  }
}

#endif
