import Foundation

struct PersonalTask: Identifiable, Codable {
  var id = UUID()
  var title: String
  var due: Date
  var completed = false
}

@MainActor
final class PersonalTaskStore: ObservableObject {
  @Published private(set) var tasks: [PersonalTask] = []
  @Published var errorMessage: String?
  @Published private(set) var isReadable = true
  private var key: String?
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) { self.defaults = defaults }
  func load(account: String) {
    key = "personalTasks." + LocalStore.accountKey(account)
    errorMessage = nil
    isReadable = true
    guard let data = defaults.data(forKey: key!) else { tasks = []; return }
    do { tasks = try JSONDecoder().decode([PersonalTask].self, from: data) }
    catch {
      AppLog.network.error("待办读取失败")
      tasks = []
      isReadable = false
      errorMessage = "待办数据无法读取。为避免覆盖本机数据，暂时停用编辑操作。"
    }
  }
  func add(title: String, due: Date) {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    var next = tasks; next.append(PersonalTask(title: trimmed, due: due)); save(next)
  }
  func update(_ id: UUID, title: String, due: Date) {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let index = tasks.firstIndex(where: { $0.id == id }) else { return }
    var next = tasks
    next[index].title = trimmed; next[index].due = due
    save(next)
  }
  func toggle(_ id: UUID) {
    var next = tasks
    guard let index = next.firstIndex(where: { $0.id == id }) else { return }
    next[index].completed.toggle(); save(next)
  }
  func delete(_ id: UUID) { save(tasks.filter { $0.id != id }) }
  private func save(_ next: [PersonalTask]) {
    guard let key, isReadable else { return }
    do {
      let data = try JSONEncoder().encode(next)
      defaults.set(data, forKey: key); tasks = next; errorMessage = nil
    } catch { AppLog.network.error("待办保存失败"); errorMessage = "待办保存失败，请重试" }
  }
}
