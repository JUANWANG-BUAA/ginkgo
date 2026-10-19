import SwiftUI

struct IOSTasksView: View {
  @EnvironmentObject private var appState: AppState
  @EnvironmentObject private var store: PersonalTaskStore
  @State private var search = ""
  @State private var showCompleted = false
  @State private var onlyOverdue = false
  @State private var showingAdd = false
  @State private var editingTask: PersonalTask?
  @State private var deletingTask: PersonalTask?
  @State private var now = Date()

  var body: some View {
    List {
      if store.isReadable == false {
        Section {
          IOSInlineMessage(store.errorMessage ?? "本机待办数据无法读取，编辑已暂停。", systemImage: "externaldrive.badge.exclamationmark", tint: .orange)
        }
      }

      let tasks = visibleTasks
      if tasks.isEmpty {
        Section {
          ContentUnavailableView(
            emptyTitle,
            systemImage: store.isReadable ? "checklist" : "exclamationmark.triangle",
            description: Text(emptyDetail)
          )
        }
      } else {
        Section {
          ForEach(tasks) { task in
            HStack(spacing: 12) {
              Button {
                store.toggle(task.id)
              } label: {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                  .font(.title3)
                  .foregroundStyle(task.completed ? Color.accentColor : Color.secondary)
              }
              .buttonStyle(.plain)
              .accessibilityLabel(task.completed ? "标记为未完成：\(task.title)" : "完成待办：\(task.title)")

              VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                  .strikethrough(task.completed)
                  .foregroundStyle(task.completed ? Color.secondary : Color.primary)
                Text(task.due.formatted(date: .abbreviated, time: .shortened))
                  .font(.caption)
                  .foregroundStyle(deadlineTint(task))
                if task.completed == false && task.due < now {
                  Label("已逾期", systemImage: "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                }
              }
            }
            .padding(.vertical, 2)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
              Button(role: .destructive) {
                deletingTask = task
              } label: {
                Label("删除", systemImage: "trash")
              }
              Button {
                editingTask = task
              } label: {
                Label("编辑", systemImage: "pencil")
              }
              .tint(.blue)
            }
          }
        } header: {
          Text("\(tasks.count) 项")
        }
      }
    }
    .listStyle(.insetGrouped)
    .navigationTitle("待办")
    .searchable(text: $search, prompt: "搜索待办")
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Menu {
          Toggle("显示已完成", isOn: $showCompleted)
          Toggle("只看逾期", isOn: $onlyOverdue)
        } label: {
          Label("筛选待办", systemImage: "line.3.horizontal.decrease.circle")
        }

        Button {
          showingAdd = true
        } label: {
          Label("新建待办", systemImage: "plus")
        }
      }
    }
    .sheet(isPresented: $showingAdd) {
      IOSAddTaskSheet()
        .environmentObject(store)
    }
    .sheet(item: $editingTask) { task in
      IOSEditTaskSheet(task: task)
        .environmentObject(store)
    }
    .alert("删除这条待办？", isPresented: deleteConfirmationPresented) {
      Button("删除", role: .destructive) {
        guard let task = deletingTask else { return }
        deletingTask = nil
        store.delete(task.id)
      }
      Button("取消", role: .cancel) { deletingTask = nil }
    } message: {
      Text(deletingTask?.title ?? "")
    }
    .task(id: appState.user?.schoolid) {
      if let account = appState.user?.schoolid {
        store.load(account: account)
      }
    }
    .task {
      while Task.isCancelled == false {
        do { try await Task.sleep(nanoseconds: 60 * 1_000_000_000) }
        catch { return }
        now = Date()
      }
    }
  }

  private var visibleTasks: [PersonalTask] {
    let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
    return store.tasks.filter { task in
      (showCompleted || task.completed == false)
        && (onlyOverdue == false || (task.completed == false && task.due < now))
        && (term.isEmpty || task.title.localizedCaseInsensitiveContains(term))
    }
    .sorted { $0.due < $1.due }
  }

  private var emptyTitle: String {
    if store.isReadable == false { return "暂时无法读取待办" }
    if store.tasks.isEmpty { return "暂无待办" }
    if store.tasks.allSatisfy(\.completed) && search.isEmpty && onlyOverdue == false {
      return "所有待办已完成"
    }
    return "没有匹配的待办"
  }

  private var emptyDetail: String {
    if store.isReadable == false { return "为保护本机原数据，编辑功能已暂停。" }
    if store.tasks.isEmpty { return "点击右上角加号新建一条待办。" }
    return "请尝试调整搜索词或筛选条件。"
  }

  private func deadlineTint(_ task: PersonalTask) -> Color {
    if task.completed == false && task.due < now { return .orange }
    return .secondary
  }

  private var deleteConfirmationPresented: Binding<Bool> {
    Binding(
      get: { deletingTask != nil },
      set: { presented in if presented == false { deletingTask = nil } }
    )
  }
}

private struct IOSAddTaskSheet: View {
  @EnvironmentObject private var store: PersonalTaskStore
  @Environment(\.dismiss) private var dismiss
  @State private var title = ""
  @State private var due = Date()

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("任务名称", text: $title)
          DatePicker("截止时间", selection: $due)
        }
      }
      .navigationTitle("新建待办")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("添加") {
            store.add(title: title, due: due)
            dismiss()
          }
          .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
    .presentationDetents([.medium])
  }
}

private struct IOSEditTaskSheet: View {
  let task: PersonalTask
  @EnvironmentObject private var store: PersonalTaskStore
  @Environment(\.dismiss) private var dismiss
  @State private var title = ""
  @State private var due = Date()

  var body: some View {
    NavigationStack {
      Form {
        Section {
          TextField("任务名称", text: $title)
          DatePicker("截止时间", selection: $due)
        }
      }
      .navigationTitle("编辑待办")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("保存") {
            store.update(task.id, title: title, due: due)
            dismiss()
          }
          .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
      .onAppear {
        title = task.title
        due = task.due
      }
    }
    .presentationDetents([.medium])
  }
}
