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
        PageHeading(
          eyebrow: "ACADEMIC / BYKC",
          title: "博雅",
          subtitle: "课程库、已选记录与完成统计；只读取学校数据，不执行选课、退选或签到"
        )
        toolbar
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

  private var toolbar: some View {
    HStack(spacing: 12) {
      if let snapshot = model.snapshot {
        Label(
          "\(model.isShowingCachedData ? "缓存" : "更新") · \(snapshot.courses.count) 门课程 · \(snapshot.chosen.count) 门已选",
          systemImage: model.isShowingCachedData ? "clock.arrow.circlepath" : "books.vertical"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      if let error = model.errorMessage, model.snapshot != nil {
        Label(error, systemImage: "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(.orange)
          .lineLimit(2)
      }
      Spacer()
      Button { Task { await model.refresh(account: appState.user?.schoolid) } } label: {
        if model.isLoading {
          ProgressView().controlSize(.small)
        } else {
          Label("刷新", systemImage: "arrow.clockwise")
        }
      }
      .buttonStyle(.bordered)
      .disabled(model.isLoading)
      .accessibilityLabel("刷新博雅")
    }
  }

  private func summary(_ snapshot: BykcSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
        metric("课程库", "\(snapshot.courses.count)", symbol: "books.vertical")
        metric("已选课程", "\(snapshot.chosen.count)", symbol: "checkmark.circle")
        metric("有效课程", "\(snapshot.validCourseCount)", symbol: "checkmark.seal")
        if let semester = snapshot.currentSemester {
          metric("当前学期", semester.name, symbol: "calendar")
        }
      }
      HStack(spacing: 16) {
        if let termName = snapshot.profile.termName, termName.isEmpty == false {
          Label("博雅学期：\(termName)", systemImage: "calendar.badge.clock")
        }
        if let college = snapshot.profile.collegeName, college.isEmpty == false {
          Label(college, systemImage: "building.columns")
        }
        if let studentType = snapshot.profile.studentType, studentType.isEmpty == false {
          Label(studentType, systemImage: "person.text.rectangle")
        }
        if let className = snapshot.profile.className, className.isEmpty == false {
          Label(className, systemImage: "person.3")
        }
        if let semester = snapshot.currentSemester,
           let start = BykcDate.display(semester.startDate),
           let end = BykcDate.display(semester.endDate) {
          Label("\(start) – \(end)", systemImage: "calendar")
        }
        Spacer()
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .bykcCard()
  }

  private func metric(_ title: String, _ value: String, symbol: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Label(title, systemImage: symbol)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.title3.monospacedDigit().weight(.semibold))
        .lineLimit(2)
        .minimumScaleFactor(0.8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
  }

  private func courseContent(_ snapshot: BykcSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
        SearchField(prompt: "搜索课程、教师或地点", text: $model.searchText)
          .frame(maxWidth: .infinity)
        Menu {
          ForEach(model.categories, id: \.self) { category in
            Button {
              model.selectedCategory = category
            } label: {
              if category == model.selectedCategory {
                Label(category, systemImage: "checkmark")
              } else {
                Text(category)
              }
            }
          }
        } label: {
          Label(model.selectedCategory, systemImage: "line.3.horizontal.decrease.circle")
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: 180)
      }
      HStack {
        Text("课程库 · \(model.filteredCourses.count)")
          .font(.headline)
        Spacer()
        Text("按类别筛选")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
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
    .bykcCard()
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
          if let availability = course.availability {
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
          row("人数", course.availability)
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
