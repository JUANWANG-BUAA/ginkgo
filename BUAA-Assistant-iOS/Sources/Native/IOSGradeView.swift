import SwiftUI

struct IOSGradeView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var model: GradeViewModel
  @State private var search = ""

  var body: some View {
    List {
      if let snapshot = model.snapshot {
        Section {
          LabeledContent("已发布", value: "\(snapshot.courses.count) 门")
          LabeledContent(
            "加权平均分",
            value: snapshot.weightedAverage?.formatted(.number.precision(.fractionLength(2))) ?? "—"
          )
          LabeledContent(
            "参考绩点",
            value: snapshot.gradePointAverage?.formatted(.number.precision(.fractionLength(2))) ?? "—"
          )
        } header: {
          Text(snapshot.term.name)
        } footer: {
          Text("绩点与均分按学分加权计算，仅统计有效百分制成绩。更新于 \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))")
        }

        if let error = model.errorMessage {
          Section {
            IOSInlineMessage(error, systemImage: "exclamationmark.triangle.fill", tint: .orange)
          }
        }

        let courses = filteredCourses(snapshot)
        if courses.isEmpty {
          Section {
            ContentUnavailableView(
              snapshot.courses.isEmpty ? "暂无已发布成绩" : "没有匹配的课程",
              systemImage: snapshot.courses.isEmpty ? "chart.bar.xaxis" : "magnifyingglass",
              description: Text(snapshot.courses.isEmpty ? "成绩发布后可下拉刷新。" : "请尝试其他关键词。")
            )
          }
        } else {
          Section("课程成绩") {
            ForEach(courses) { course in
              HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                  Text(course.name)
                    .font(.body.weight(.medium))
                  HStack(spacing: 6) {
                    if let code = course.code, code.isEmpty == false {
                      Text(code)
                    }
                    if let type = course.courseType, type.isEmpty == false {
                      if course.code?.isEmpty == false { Text("·") }
                      Text(type)
                    }
                  }
                  .font(.caption)
                  .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                  Text(course.score)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(scoreTint(course).map { AnyShapeStyle($0) } ?? AnyShapeStyle(.primary))
                  if let credit = course.credit {
                    Text("\(credit.formatted()) 学分")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                }
              }
              .padding(.vertical, 3)
            }
          }
        }
      } else if model.isLoading {
        Section {
          HStack(spacing: 10) {
            ProgressView()
            Text("正在读取成绩…")
          }
        }
      } else {
        Section {
          ContentUnavailableView(
            "成绩尚未确认",
            systemImage: "wifi.exclamationmark",
            description: Text(model.errorMessage ?? "请检查网络后重试。")
          )
          Button("重试") { Task { await model.refresh() } }
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("成绩")
    .searchable(text: $search, prompt: "搜索课程名称或课程号")
    .refreshable { await model.refresh() }
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        if let snapshot = model.snapshot {
          Menu {
            ForEach(model.terms.isEmpty ? [snapshot.term] : model.terms) { term in
              Button {
                Task { await model.refresh(term: term) }
              } label: {
                if term.id == snapshot.term.id {
                  Label(term.name, systemImage: "checkmark")
                } else {
                  Text(term.name)
                }
              }
            }
          } label: {
            Label("选择学期", systemImage: "calendar")
          }
        }
        Button {
          Task { await model.refresh() }
        } label: {
          if model.isLoading {
            ProgressView().controlSize(.small)
          } else {
            Image(systemName: "arrow.clockwise")
          }
        }
        .disabled(model.isLoading)
        .accessibilityLabel("刷新成绩")
      }
    }
    .task(id: appState.user?.schoolid) {
      guard let account = appState.user?.schoolid else { return }
      await model.start(account: account)
    }
    .onChange(of: model.needsSessionCheck) { _, needed in
      guard needed else { return }
      Task { _ = try? await appState.confirmSessionAfterAuthFailure() }
    }
  }

  private func filteredCourses(_ snapshot: GradeSnapshot) -> [GradeCourse] {
    snapshot.courses(matching: search)
  }

  private func scoreTint(_ course: GradeCourse) -> Color? {
    guard let score = course.percentageScore else { return nil }
    if score < 60 { return .red }
    if score >= 90 { return .green }
    return nil
  }
}
