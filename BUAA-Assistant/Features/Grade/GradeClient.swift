import Foundation

protocol GradeServing {
  func load(term: SchoolTerm) async throws -> GradeSnapshot
}

actor GradeClient: GradeServing {
  private let session: URLSession
  private let url = URL(string: "https://app.buaa.edu.cn/buaascore/wap/default/index")!

  init(session: URLSession = APIClient.shared.session) { self.session = session }

  func load(term: SchoolTerm) async throws -> GradeSnapshot {
    let parts = try GradeTermCode.parts(term.id)
    // API.md §4.1：先 GET 激活 buaascore 会话。
    var activation = URLRequest(url: url)
    activation.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
    _ = try await send(activation)

    // API.md §4.2：同址 POST xq/year，Ajax 响应为 JSON。
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.httpBody = "xq=\(parts.semester)&year=\(parts.year)".data(using: .utf8)
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
    request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
    request.setValue(url.absoluteString, forHTTPHeaderField: "Referer")
    return GradeSnapshot(term: term, courses: try GradeParser.courses(try await send(request)), fetchedAt: Date())
  }

  private func send(_ request: URLRequest) async throws -> Data {
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw ScheduleError.changedResponse }
    if http.statusCode == 401 || http.statusCode == 403 || http.url?.host == "sso.buaa.edu.cn" {
      throw ScheduleError.sessionExpired
    }
    guard (200..<300).contains(http.statusCode) else { throw ScheduleError.unavailable("成绩服务") }
    if String(data: data.prefix(5000), encoding: .utf8)?.contains("name=\"execution\"") == true {
      throw ScheduleError.sessionExpired
    }
    return data
  }
}
