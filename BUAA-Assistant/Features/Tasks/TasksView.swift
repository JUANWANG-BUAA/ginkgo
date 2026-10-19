import SwiftUI

struct TasksView: View {
  @EnvironmentObject private var appState: AppState
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @EnvironmentObject private var store: PersonalTaskStore
  @AppStorage("compactLists") private var compactLists = false
  @State private var onlyOverdue = false
  @State private var title = ""
  @State private var due = Date()
  @State private var showCompleted = false
  @State private var search = ""
  @State private var deleting: PersonalTask?
  @State private var editing: PersonalTask?
  @State private var editTitle = ""
  @State private var editDue = Date()
  /// 分钟级时钟：逾期标记与“只看逾期”筛选在页面停留时也能自行更新。
  @State private var now = Date()
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        PageHeading(eyebrow: "PERSONAL / TASKS", title: "待办", subtitle: "记录自己的课程任务与截止时间，保存在本机")
        VStack(alignment: .leading, spacing: 12) {
          TextField("添加任务，例如完成实验报告", text: $title).textFieldStyle(.roundedBorder).onSubmit(add)
          HStack {
            DatePicker("截止时间", selection: $due)
            Spacer()
            Button("添加待办", action: add).buttonStyle(.borderedProminent).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }.padding(16).background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 12))
          .disabled(!store.isReadable)
        if let error = store.errorMessage { StatusNotice(message: error, kind: .warning) }
        SearchField(prompt: "搜索待办", text: $search)
        HStack {
          Toggle("显示已完成", isOn: $showCompleted)
          Toggle("只看逾期", isOn: $onlyOverdue)
          Spacer()
          Text("待完成 \(store.tasks.filter { $0.completed == false }.count) 项").font(.caption).foregroundStyle(.secondary)
        }
        let term = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let visible = store.tasks.filter { (showCompleted || !$0.completed) && (!onlyOverdue || (!$0.completed && $0.due < now)) && (term.isEmpty || $0.title.localizedCaseInsensitiveContains(term)) }.sorted { $0.due < $1.due }
        if visible.isEmpty {
          PageEmptyState(
            symbol: store.isReadable ? "checklist" : "exclamationmark.triangle",
            title: !store.isReadable ? "暂时无法读取待办" : (store.tasks.isEmpty ? "暂无待办" : (store.tasks.allSatisfy(\.completed) && term.isEmpty && !onlyOverdue ? "所有待办已完成" : "未找到匹配任务")),
            detail: !store.isReadable ? "本机待办数据无法解析，编辑已暂停以保护原数据。" : (store.tasks.isEmpty ? "可以在上方添加任务。学校作业可在独立页面查询。" : "更换搜索词或重置筛选条件。")
          )
        }
        ProgressiveList(items: visible, pageSize: 60) { task in
          HStack(spacing: 12) {
            Button { store.toggle(task.id) } label: { Image(systemName: task.completed ? "checkmark.circle.fill" : "circle").font(.title2) }
              .buttonStyle(.plain).accessibilityLabel(task.completed ? "标记为未完成：\(task.title)" : "完成待办：\(task.title)")
            VStack(alignment: .leading, spacing: 5) {
              Text(task.title).font(.body.weight(.medium)).strikethrough(task.completed)
              Text(task.due.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
              if !task.completed && task.due < now { Label("已逾期", systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.orange) }
            }
            Spacer()
            Button { editing = task; editTitle = task.title; editDue = task.due } label: { Image(systemName: "pencil") }
              .buttonStyle(.borderless).help("编辑待办").accessibilityLabel("编辑待办：\(task.title)")
            Button { deleting = task } label: { Image(systemName: "trash") }
              .buttonStyle(.borderless).help("删除待办").accessibilityLabel("删除待办：\(task.title)")
          }.padding(compactLists ? 10 : 16).background(Color.ginkgoCardBackground, in: RoundedRectangle(cornerRadius: 10))
        }
        .disabled(!store.isReadable)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: visible.map(\.id))
      }.ginkgoPagePadding().frame(maxWidth: 800, alignment: .leading).frame(maxWidth: .infinity)
    }.background(Color.ginkgoWindowBackground)
      .task(id: appState.user?.schoolid) { if let account = appState.user?.schoolid { store.load(account: account) } }
      .task {
        while !Task.isCancelled {
          do { try await Task.sleep(nanoseconds: 60 * 1_000_000_000) } catch { return }
          now = Date()
        }
      }
      .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: store.tasks.map { $0.id })
      .alert("删除这条待办？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
        Button("删除", role: .destructive) { if let task = deleting { store.delete(task.id) }; deleting = nil }
        Button("取消", role: .cancel) { deleting = nil }
      } message: { Text(deleting?.title ?? "") }
      .sheet(item: $editing) { task in
        VStack(alignment: .leading, spacing: 16) {
          Text("编辑待办").font(.title2.weight(.semibold))
          TextField("任务名称", text: $editTitle).textFieldStyle(.roundedBorder)
          DatePicker("截止时间", selection: $editDue)
          HStack {
            Button("取消", role: .cancel) { editing = nil }
            Spacer()
            Button("保存") { store.update(task.id, title: editTitle, due: editDue); editing = nil }
              .buttonStyle(.borderedProminent).disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
              .keyboardShortcut(.defaultAction)
          }
        }.padding(24).ginkgoSheetSizing(minWidth: 420, minHeight: 250)
      }
  }
  private func add() {
    store.add(title: title, due: due)
    if store.errorMessage == nil { title = ""; appState.showToast("待办已添加") }
  }
}
