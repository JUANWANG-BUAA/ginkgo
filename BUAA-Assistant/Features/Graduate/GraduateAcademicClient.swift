import Foundation

protocol GraduateAcademicLoading {
  func load(account: String) async throws -> GraduateAcademicSnapshot
}

actor GraduateAcademicClient: GraduateAcademicLoading {
  private let session: URLSession
  private let host = URL(string: "https://gsmis.buaa.edu.cn")
  private let portalPath = "/gsapp/sys/yjsemaphome/portal/index.do"

  init(session: URLSession = APIClient.shared.session) {
    self.session = session
  }

  func load(account: String) async throws -> GraduateAcademicSnapshot {
    try await activate()
    var issues: [GraduateAcademicIssue] = []
    var dates: [String: Date] = [:]
    func read<T>(_ section: GraduateAcademicSection, _ operation: () async throws -> T) async throws -> T? {
      do {
        let value = try await operation()
        dates[section.rawValue] = Date()
        return value
      } catch {
        if RequestCancellation.isCancellation(error) { throw error }
        issues.append(GraduateAcademicIssue(section: section, message: error.localizedDescription))
        return nil
      }
    }
    let userInfo = try await read(.term) {
      try await self.postJSON(
        path: "/gsapp/sys/yjsemaphome/modules/pubWork/getUserInfo.do",
        form: [:], referer: self.portalPath
      )
    }
    let termCode = userInfo.flatMap { Self.nestedString($0, path: ["data", "xnxqdm"]) }

    let statusEnvelope = try await postJSON(
      path: "/gsapp/sys/wdxjappbuaa/modules/wdxj/xsjcxxcx.do",
      form: ["XH": account],
      referer: "/gsapp/sys/wdxjappbuaa/*default/index.do"
    )
    guard let statusRow = Self.firstRow(statusEnvelope, key: "xsjcxxcx") else {
      throw GraduateAcademicError.invalidResponse("学籍")
    }

    let categoryEnvelope = try await read(.modules) {
      try await self.postJSON(
        path: "/gsapp/sys/yjsemaphome/modules/pubWork/getCanVisitAppList.do",
        form: ["KEYWORD": ""], referer: self.portalPath
      )
    }
    let modules = categoryEnvelope.map(Self.moduleCategories) ?? []
    let plan = try await read(.plan) { try await self.loadPlan(account: account) }
    let execution = try await read(.execution) { try await self.loadPlanExecution() }
    let grades = try await read(.grades) { try await self.loadGrades(account: account) }
    let exams = try await read(.exams) { try await self.loadExamSummary(termCode: termCode) }
    try Task.checkCancellation()

    return GraduateAcademicSnapshot(
      status: Self.status(statusRow),
      plan: plan ?? nil,
      planExecution: execution ?? nil,
      examSummary: exams ?? GraduateExamSummary(examCount: 0, quizCourseCount: 0, invigilationCount: 0),
      grades: grades ?? [],
      moduleCategories: modules,
      fetchedAt: Date(),
      currentTermID: termCode,
      issues: issues,
      sourceDates: dates
    )
  }

  private func activate() async throws {
    _ = try? await get(path: portalPath, acceptHTML: true)
    let apps = ["wdxjappbuaa", "wdpyfaappbuaa", "wdpyfazxbgappbuaa", "wdcjapp", "wdksapp"]
    for app in apps {
      _ = try? await get(
        path: "/gsapp/sys/\(app)/*default/index.do",
        acceptHTML: true,
        referer: nil
      )
    }
  }

  private func loadPlan(account: String) async throws -> GraduatePlan? {
    let mapping = try await postJSON(
      path: "/gsapp/sys/wdpyfaappbuaa/modules/pyfaxq/gjxhcxdyfadm.do",
      form: ["XH": account],
      referer: "/gsapp/sys/wdpyfaappbuaa/*default/index.do"
    )
    let mappings = try Self.validatedRows(mapping, key: "gjxhcxdyfadm")
    guard let planCode = mappings.first.flatMap({ Self.string($0["FADM"]) }),
          planCode.isEmpty == false else {
      return nil
    }

    let headerEnvelope = try await getJSON(
      path: "/gsapp/sys/wdpyfaappbuaa/modules/pyfaxq/facx.do",
      query: ["DM": planCode, "EN": "zh"],
      referer: "/gsapp/sys/wdpyfaappbuaa/*default/index.do"
    )
    guard let header = Self.firstRow(headerEnvelope, key: "facx") else {
      throw GraduateAcademicError.invalidResponse("培养方案头部")
    }

    let sectionsEnvelope = try await getJSON(
      path: "/gsapp/sys/wdpyfaappbuaa/modules/pyfaxq/gjfadmhqdydpyfanr.do",
      query: ["DM": planCode],
      referer: "/gsapp/sys/wdpyfaappbuaa/*default/index.do"
    )
    let sections = try Self.validatedRows(sectionsEnvelope, key: "gjfadmhqdydpyfanr").enumerated().compactMap { index, row -> GraduatePlanSection? in
      let title = Self.cleanText(Self.string(row["MC"]))
      guard title.isEmpty == false else { return nil }
      let content = Self.cleanText(Self.string(row["MRZ"]) ?? Self.string(row["SM"]) ?? "")
      return GraduatePlanSection(
        id: "plan-section-\(index)",
        title: title,
        content: content.isEmpty ? nil : content
      )
    }

    let setting = try JSONSerialization.data(withJSONObject: [["name": "FADM", "value": planCode]])
    let settingText = String(data: setting, encoding: .utf8) ?? "[]"
    let coursesEnvelope = try await postJSON(
      path: "/gsapp/sys/wdpyfaappbuaa/modules/pyfaxq/pyfakcxxcx.do",
      form: ["setting": settingText],
      referer: "/gsapp/sys/wdpyfaappbuaa/*default/index.do"
    )
    let courses = try Self.validatedRows(coursesEnvelope, key: "pyfakcxxcx").enumerated().compactMap { index, row -> GraduatePlanCourse? in
      let name = Self.cleanText(Self.string(row["KCMC"]))
      guard name.isEmpty == false else { return nil }
      return GraduatePlanCourse(
        id: "plan-course-\(index)-\(Self.string(row["KCDM"]) ?? name)",
        name: name,
        code: Self.nonempty(row["KCDM"]),
        credits: Self.double(row["XF"]),
        category: Self.nonempty(row["KCLBLXMC"]) ?? Self.nonempty(row["KCLBDM_DISPLAY"]),
        examMode: Self.nonempty(row["KKSX_DISPLAY"]),
        term: Self.nonempty(row["KKXQDM_DISPLAY"]),
        required: Self.nonempty(row["SFBX_DISPLAY"])
      )
    }

    return GraduatePlan(
      title: Self.cleanText(Self.string(header["MC"])),
      college: Self.nonempty(header["YXDM_DISPLAY"]),
      major: Self.nonempty(header["ZYDM_DISPLAY"]),
      totalCredits: Self.double(header["ZDXF"]),
      degreeCourseCredits: Self.double(header["XWKZDXF"]),
      jointCourseCredits: Self.double(header["XQLHKCXF"]),
      reviewStatus: Self.nonempty(header["SHZT_DISPLAY"]),
      sections: sections,
      courses: courses
    )
  }

  private func loadPlanExecution() async throws -> GraduatePlanExecution? {
    let envelope = try await postJSON(
      path: "/gsapp/sys/wdpyfazxbgappbuaa/zxbg/loadXspyfazxbgInfo.do",
      form: ["isShowSszxbg": "0"],
      referer: "/gsapp/sys/wdpyfazxbgappbuaa/*default/index.do",
      validateCode: false
    )

    return try Self.parseExecution(envelope)
  }

  /// School wdpyfazxbg.js treats code 0 as failure; zxbgBuilder.js owns field semantics.
  static func parseExecution(_ envelope: [String: Any]) throws -> GraduatePlanExecution? {
    guard integer(envelope["code"]) == 1 else {
      throw GraduateAcademicError.upstream(nonempty(envelope["msg"]) ?? "执行报告暂不可用")
    }
    let root = (envelope["datas"] as? [String: Any]) ?? envelope
    guard let categoryRows = Self.executionCategoryRows(root["zxbg"]) else {
      throw GraduateAcademicError.invalidResponse("培养方案执行报告")
    }
    for category in categoryRows {
      guard let groups = category["dxzList"] as? [[String: Any]],
            let courses = category["kcList"] as? [[String: Any]],
            groups.allSatisfy({ Self.nonempty($0["dxzmc"]) != nil && $0["kcList"] is [[String: Any]] }) else {
        throw GraduateAcademicError.invalidResponse("执行报告课组或修读记录")
      }
      let allCourses = courses + groups.flatMap { $0["kcList"] as? [[String: Any]] ?? [] }
      guard allCourses.allSatisfy({ Self.nonempty($0["kcmc"]) != nil && $0["sfwc"] != nil }) else {
        throw GraduateAcademicError.invalidResponse("执行报告课程状态")
      }
    }
    let categories = categoryRows.compactMap(Self.executionCategory)
    guard categories.count == categoryRows.count else {
      throw GraduateAcademicError.invalidResponse("执行报告类别")
    }

    let plan = root["fa"] as? [String: Any] ?? [:]
    let stage = root["scxx"] as? [String: Any] ?? [:]
    return GraduatePlanExecution(
      totalRequiredCredits: Self.double(plan["ZDXF"]),
      earnedCredits: Self.double(root["yhpyfaxf"]),
      pendingCredits: Self.double(root["dkhxf"]),
      researchCredits: Self.double(root["yhyjxf"]),
      stageRequiredCredits: Self.double(stage["FDPYYQXF"]),
      stageEarnedCredits: Self.double(stage["FDPYWCXF"]),
      categories: categories,
      totalEarnedCredits: Self.double(root["yxxf"]),
      jointEarnedCredits: Self.double(root["yhxqlhkcxf"])
    )
  }

  private static func executionCategoryRows(_ value: Any?) -> [[String: Any]]? {
    if let rows = value as? [[String: Any]] { return rows }
    guard let text = value as? String,
          let data = text.data(using: .utf8),
          let rows = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      return nil
    }
    return rows
  }

  private static func executionCategory(_ row: [String: Any]) -> GraduatePlanExecutionCategory? {
    let name = cleanText(string(row["kclbmc"]) ?? "")
    guard name.isEmpty == false else { return nil }
    let groups = (row["dxzList"] as? [[String: Any]] ?? []).compactMap(executionGroup)
    let courses = (row["kcList"] as? [[String: Any]] ?? []).compactMap(executionCourse)
    let rawRequired = double(row["yqxf"])
    return GraduatePlanExecutionCategory(
      code: string(row["kclbdm"]) ?? name,
      name: name,
      requiredCredits: rawRequired,
      earnedCredits: double(row["yhxf"]),
      pendingCredits: double(row["dkhxf"]),
      minimumCourseCount: integer(row["zsms"]),
      requirementNote: nonempty(row["kclbhbzyq"]),
      groups: groups,
      courses: courses
    )
  }

  private static func executionGroup(_ row: [String: Any]) -> GraduatePlanExecutionGroup? {
    let name = cleanText(string(row["dxzmc"]) ?? "")
    guard name.isEmpty == false else { return nil }
    return GraduatePlanExecutionGroup(
      code: string(row["dxzdm"]) ?? name,
      name: name,
      requiredCredits: double(row["yqxf"]),
      earnedCredits: double(row["yhxf"]),
      pendingCredits: double(row["dkhxf"]),
      courses: (row["kcList"] as? [[String: Any]] ?? []).compactMap(executionCourse)
    )
  }

  private static func executionCourse(_ row: [String: Any]) -> GraduatePlanExecutionCourse? {
    let name = cleanText(string(row["kcmc"]) ?? "")
    guard name.isEmpty == false else { return nil }
    return GraduatePlanExecutionCourse(
      code: string(row["kcdm"]) ?? "",
      name: name,
      credits: double(row["xf"]),
      completed: bool(row["sfwc"]),
      grade: nonempty(row["cjxsz"]),
      term: nonempty(row["xnxqmc"]),
      category: nonempty(row["kclbmc"]),
      courseAttribute: nonempty(row["kksx"])
    )
  }

  private func loadGrades(account: String) async throws -> [GraduateGradeRecord] {
    let envelope = try await postJSON(
      path: "/gsapp/sys/wdcjapp/modules/wdcj/xscjcx.do",
      form: ["XH": account],
      referer: "/gsapp/sys/wdcjapp/*default/index.do"
    )
    return try Self.validatedRows(envelope, key: "xscjcx").enumerated().compactMap { index, row -> GraduateGradeRecord? in
      let name = Self.cleanText(Self.string(row["KCMC"]))
      guard name.isEmpty == false else { return nil }
      return GraduateGradeRecord(
        id: "grade-\(index)-\(Self.string(row["KCDM"]) ?? name)",
        courseName: name,
        courseCode: Self.nonempty(row["KCDM"]),
        score: Self.nonempty(row["CJXSZ"]) ?? Self.nonempty(row["CJ"]),
        credits: Self.double(row["XF"]),
        gradePoint: Self.nonempty(row["JD"]),
        category: Self.nonempty(row["KCLBMC"])
      )
    }
  }

  private func loadExamSummary(termCode: String?) async throws -> GraduateExamSummary {
    guard let termCode, termCode.isEmpty == false else {
      throw GraduateAcademicError.invalidResponse("当前学期，无法查询考试")
    }
    let envelope = try await postJSON(
      path: "/gsapp/sys/wdksapp/modules/ksxxck/getWdksxx.do",
      form: ["xnxqdm": termCode],
      referer: "/gsapp/sys/wdksapp/*default/index.do"
    )
    guard let exams = Self.integer(envelope["countKs"]),
          let quizzes = Self.integer(envelope["countKcks"]),
          let invigilation = Self.integer(envelope["countJk"]),
          exams >= 0, quizzes >= 0, invigilation >= 0 else {
      throw GraduateAcademicError.invalidResponse("考试汇总")
    }
    return GraduateExamSummary(examCount: exams, quizCourseCount: quizzes, invigilationCount: invigilation)
  }

  private func postJSON(
    path: String,
    form: [String: String],
    referer: String,
    validateCode: Bool = true
  ) async throws -> [String: Any] {
    guard let url = endpoint(path: path, query: [String: String]()) else {
      throw GraduateAcademicError.invalidResponse("URL")
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 45
    request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
    request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    request.setValue(upstreamURL(path: referer), forHTTPHeaderField: "Referer")
    request.httpBody = formBody(form)
    return try await execute(request, validateCode: validateCode)
  }

  private func getJSON(
    path: String,
    query: [String: String],
    referer: String
  ) async throws -> [String: Any] {
    guard let url = endpoint(path: path, query: query) else {
      throw GraduateAcademicError.invalidResponse("URL")
    }
    var request = URLRequest(url: url)
    request.timeoutInterval = 45
    request.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
    request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
    request.setValue(upstreamURL(path: referer), forHTTPHeaderField: "Referer")
    return try await execute(request)
  }

  private func get(
    path: String,
    acceptHTML: Bool,
    referer: String? = nil
  ) async throws -> Data {
    guard let url = endpoint(path: path, query: [String: String]()) else {
      throw GraduateAcademicError.invalidResponse("URL")
    }
    var request = URLRequest(url: url)
    request.timeoutInterval = 45
    if acceptHTML {
      request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
    }
    if let referer {
      request.setValue(upstreamURL(path: referer), forHTTPHeaderField: "Referer")
    }
    let (data, response) = try await session.routedData(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw GraduateAcademicError.unavailable
    }
    return data
  }

  private func execute(_ request: URLRequest, validateCode: Bool = true) async throws -> [String: Any] {
    let (data, response) = try await session.routedData(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw GraduateAcademicError.invalidResponse("HTTP")
    }
    guard http.statusCode == 200 else {
      if http.statusCode == 401 || http.statusCode == 403 || http.url?.host == "sso.buaa.edu.cn" {
        throw GraduateAcademicError.unavailable
      }
      throw GraduateAcademicError.upstream("HTTP \(http.statusCode)")
    }
    guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw GraduateAcademicError.invalidResponse("JSON")
    }
    if let success = object["success"] as? Bool, success == false {
      throw GraduateAcademicError.upstream(Self.string(object["msg"]) ?? "业务响应未成功")
    }
    if validateCode, let code = Self.string(object["code"]), code != "0" {
      throw GraduateAcademicError.upstream(Self.string(object["msg"]) ?? code)
    }
    return object
  }

  private func endpoint(path: String, query: [String: String]) -> URL? {
    guard let host,
          var components = URLComponents(string: host.absoluteString + path) else { return nil }
    if query.isEmpty == false {
      components.queryItems = query.sorted { $0.key < $1.key }.map {
        URLQueryItem(name: $0.key, value: $0.value)
      }
    }
    return components.url
  }

  private func upstreamURL(path: String) -> String {
    "https://gsmis.buaa.edu.cn\(path)"
  }

  private func formBody(_ values: [String: String]) -> Data? {
    var components = URLComponents()
    components.queryItems = values.sorted { $0.key < $1.key }.map {
      URLQueryItem(name: $0.key, value: $0.value)
    }
    return components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B").data(using: .utf8)
  }

  private static func validatedRows(_ envelope: [String: Any], key: String) throws -> [[String: Any]] {
    guard let data = envelope["datas"] as? [String: Any],
          let table = data[key] as? [String: Any],
          let rows = table["rows"] as? [[String: Any]] else {
      throw GraduateAcademicError.invalidResponse(key)
    }
    return rows
  }

  private static func firstRow(_ envelope: [String: Any], key: String) -> [String: Any]? {
    rows(envelope, key: key).first
  }

  private static func rows(_ envelope: [String: Any], key: String) -> [[String: Any]] {
    guard let data = envelope["datas"] as? [String: Any],
          let table = data[key] as? [String: Any] else { return [] }
    return table["rows"] as? [[String: Any]] ?? []
  }

  private static func nestedString(_ object: [String: Any], path: [String]) -> String? {
    var current: Any = object
    for component in path {
      guard let dictionary = current as? [String: Any], let value = dictionary[component] else { return nil }
      current = value
    }
    return string(current)
  }

  static func status(_ row: [String: Any]) -> GraduateStatusSummary {
    GraduateStatusSummary(
      college: nonempty(row["YXDM_DISPLAY"]),
      major: nonempty(row["ZYDM_DISPLAY"]),
      grade: nonempty(row["NJDM_DISPLAY"]),
      degreeLevel: nonempty(row["PYCCDM_DISPLAY"]),
      studentType: nonempty(row["XSLBDM_DISPLAY"]),
      status: nonempty(row["XJZTDM_DISPLAY"]),
      className: nonempty(row["BJMC"]),
      campus: nonempty(row["XQDM_DISPLAY"]),
      studyMode: nonempty(row["XXFSDM_DISPLAY"]),
      enrollmentDate: nonempty(row["RDRQ"]),
      expectedGraduation: nonempty(row["SJBYSJ"])
    )
  }

  static func moduleCategories(_ envelope: [String: Any]) -> [GraduateModuleCategory] {
    guard let categories = envelope["res"] as? [[String: Any]] else { return [] }
    return categories.compactMap { category in
      guard let name = nonempty(category["FZMC"]) else { return nil }
      let apps = (category["secondCategory"] as? [[String: Any]] ?? []).flatMap { section -> [GraduateModuleApp] in
        (section["secondCategoryApp"] as? [[String: Any]] ?? []).compactMap { app in
          guard let appName = nonempty(app["YYMC"]) else { return nil }
          let appID = nonempty(app["YYDM"]) ?? appName
          let menus = (app["caidanList"] as? [[String: Any]] ?? []).compactMap { menu -> GraduateModuleOption? in
            guard let menuName = nonempty(menu["caidanmc"]) else { return nil }
            return GraduateModuleOption(
              id: appID + "|" + (nonempty(menu["caidandm"]) ?? menuName),
              name: menuName
            )
          }
          return GraduateModuleApp(id: appID, name: appName, menus: menus)
        }
      }
      return GraduateModuleCategory(
        id: nonempty(category["FZDM"]) ?? name,
        name: name,
        apps: apps
      )
    }
  }

  private static func cleanText(_ raw: String?) -> String { raw.map(HTMLText.plainText) ?? "" }

  private static func string(_ value: Any?) -> String? { JSONValue.string(value) }
  private static func nonempty(_ value: Any?) -> String? { JSONValue.nonEmptyString(value) }
  private static func integer(_ value: Any?) -> Int? { JSONValue.int(value) }
  private static func double(_ value: Any?) -> Double? { JSONValue.double(value) }

  /// 研究生系统另用“是/已完成”表示真值。
  private static func bool(_ value: Any?) -> Bool {
    if let text = value as? String, ["是", "已完成"].contains(text) { return true }
    return JSONValue.bool(value) ?? false
  }
}
