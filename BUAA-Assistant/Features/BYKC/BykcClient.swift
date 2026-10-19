import CryptoKit
import Foundation
import Security

actor BykcClient {
  private let session: URLSession
  private let base = URL(string: "https://bykc.buaa.edu.cn")
  private var token: String?

  init(session: URLSession = APIClient.shared.session) {
    self.session = session
  }

  func load() async throws -> BykcSnapshot {
    let loginToken = try await loginToken()
    let profileData = try await data(for: "getUserProfile", payload: [:], loginToken: loginToken)
    let configData = try await data(for: "getAllConfig", payload: [:], loginToken: loginToken)
    let profile = Self.profile(profileData)
    let semesters = Self.semesters(configData)
    let now = Date()
    let currentSemester = Self.currentSemester(semesters, now: now)

    var courses: [BykcCourse] = []
    var page = 1
    var lastPage = 1
    repeat {
      let pageData = try await data(
        for: "queryStudentSemesterCourseByPage",
        payload: ["pageNumber": page, "pageSize": 100],
        loginToken: loginToken
      )
      courses += Self.courses(pageData)
      lastPage = Self.integer(pageData["totalPages"]) ?? page
      page += 1
    } while page <= lastPage && page <= 20

    var chosen: [BykcChosenCourse] = []
    if let currentSemester,
       let start = Self.normalizedDateTime(currentSemester.startDate),
       let end = Self.normalizedDateTime(currentSemester.endDate) {
      let chosenData = try await data(
        for: "queryChosenCourse",
        payload: ["startDate": start, "endDate": end],
        loginToken: loginToken
      )
      chosen = Self.chosenCourses(chosenData)
    }

    let statisticsData = try await data(
      for: "queryStatisticByUserId",
      payload: [:],
      loginToken: loginToken
    )
    let statistics = Self.statistics(statisticsData)

    return BykcSnapshot(
      profile: profile,
      semesters: semesters,
      currentSemester: currentSemester,
      courses: courses,
      chosen: chosen,
      statistics: statistics,
      validCourseCount: Self.integer(statisticsData["validCount"]) ?? 0,
      fetchedAt: Date()
    )
  }

  private func loginToken() async throws -> String {
    if let token, token.isEmpty == false { return token }
    guard let loginURL = URL(string: "https://bykc.buaa.edu.cn/sscv/cas/login") else {
      throw BykcError.loginFailed
    }
    var request = URLRequest(url: loginURL)
    request.timeoutInterval = 35
    request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
    let (_, response) = try await session.routedData(for: request)
    guard let http = response as? HTTPURLResponse,
          let finalURL = http.url,
          let components = URLComponents(url: finalURL, resolvingAgainstBaseURL: false),
          let value = components.queryItems?.first(where: { $0.name == "token" })?.value,
          value.isEmpty == false else {
      throw BykcError.loginFailed
    }
    token = value
    return value
  }

  private func data(
    for api: String,
    payload: [String: Any],
    loginToken: String
  ) async throws -> [String: Any] {
    do {
      return try await dataOnce(for: api, payload: payload, loginToken: loginToken)
    } catch {
      token = nil
      let refreshed = try await self.loginToken()
      return try await dataOnce(for: api, payload: payload, loginToken: refreshed)
    }
  }

  private func dataOnce(
    for api: String,
    payload: [String: Any],
    loginToken: String
  ) async throws -> [String: Any] {
    guard let base,
          let endpoint = URL(string: "/sscv/\(api)", relativeTo: base)?.absoluteURL else {
      throw BykcError.invalidEnvelope
    }
    let encrypted = try BykcCrypto.encrypt(payload)
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.timeoutInterval = 35
    request.httpBody = encrypted.body.data(using: .utf8)
    request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("https://bykc.buaa.edu.cn/system/course-select", forHTTPHeaderField: "Referer")
    request.setValue("https://bykc.buaa.edu.cn", forHTTPHeaderField: "Origin")
    request.setValue(loginToken, forHTTPHeaderField: "auth_token")
    request.setValue(loginToken, forHTTPHeaderField: "authtoken")
    request.setValue(encrypted.ak, forHTTPHeaderField: "ak")
    request.setValue(encrypted.sk, forHTTPHeaderField: "sk")
    request.setValue(encrypted.ts, forHTTPHeaderField: "ts")

    let (raw, response) = try await session.routedData(for: request)
    guard let http = response as? HTTPURLResponse else { throw BykcError.invalidEnvelope }
    guard http.statusCode == 200 else {
      throw BykcError.upstream("HTTP \(http.statusCode)")
    }
    let bodyText: String
    if let value = try? JSONSerialization.jsonObject(with: raw, options: .fragmentsAllowed) as? String {
      bodyText = value
    } else if let value = String(data: raw, encoding: .utf8) {
      bodyText = value.trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
      throw BykcError.invalidEnvelope
    }
    guard let encryptedData = Data(base64Encoded: bodyText) else {
      throw BykcError.invalidEnvelope
    }
    let decrypted = try BykcCrypto.decrypt(encryptedData, key: encrypted.key)
    guard let root = try JSONSerialization.jsonObject(with: decrypted) as? [String: Any],
          let status = Self.string(root["status"]), status == "0",
          let object = root["data"] as? [String: Any] else {
      let message = (try? JSONSerialization.jsonObject(with: decrypted) as? [String: Any])
        .flatMap { Self.string($0["errmsg"]) }
      throw BykcError.upstream(message?.isEmpty == false ? message ?? "业务响应未成功" : "业务响应未成功")
    }
    return object
  }

  private static func profile(_ data: [String: Any]) -> BykcProfile {
    BykcProfile(
      studentType: string(data["studentType"]),
      className: string(data["classCode"]),
      collegeName: nestedString(data["college"], key: "collegeName"),
      termName: nestedString(data["term"], key: "termName")
    )
  }

  private static func semesters(_ data: [String: Any]) -> [BykcSemester] {
    guard let rows = data["semester"] as? [[String: Any]] else { return [] }
    return rows.compactMap { row in
      guard let id = integer64(row["id"]),
            let name = string(row["semesterName"]), name.isEmpty == false else { return nil }
      return BykcSemester(
        id: id,
        name: name,
        startDate: string(row["semesterStartDate"]),
        endDate: string(row["semesterEndDate"])
      )
    }
  }

  static func currentSemester(_ semesters: [BykcSemester], now: Date = Date()) -> BykcSemester? {
    if let active = semesters.first(where: { semester in
      guard let start = BykcDate.parse(semester.startDate),
            let end = BykcDate.parse(semester.endDate) else { return false }
      return start <= now && now <= end
    }) {
      return active
    }
    return semesters.max { lhs, rhs in
      (BykcDate.parse(lhs.endDate) ?? .distantPast) < (BykcDate.parse(rhs.endDate) ?? .distantPast)
    }
  }

  private static func courses(_ data: [String: Any]) -> [BykcCourse] {
    guard let rows = data["content"] as? [[String: Any]] else { return [] }
    return rows.compactMap(course)
  }

  private static func course(_ row: [String: Any]) -> BykcCourse? {
    guard let id = integer64(row["id"]),
          let name = string(row["courseName"])?.trimmingCharacters(in: .whitespacesAndNewlines),
          name.isEmpty == false else { return nil }
    var campuses: [String] = []
    if let list = row["courseCampusList"] as? [String] { campuses += list }
    if let value = string(row["courseCampus"]), value.isEmpty == false,
       campuses.contains(value) == false {
      campuses.append(value)
    }
    return BykcCourse(
      id: id,
      name: name,
      teacher: nonempty(row["courseTeacher"]),
      position: nonempty(row["coursePosition"]),
      category: nestedString(row["courseNewKind1"], key: "kindName") ?? nonempty(row["courseKind1"]),
      subcategory: nestedString(row["courseNewKind2"], key: "kindName") ?? nonempty(row["courseKind2"]),
      startDate: nonempty(row["courseStartDate"]),
      endDate: nonempty(row["courseEndDate"]),
      selectStartDate: nonempty(row["courseSelectStartDate"]),
      selectEndDate: nonempty(row["courseSelectEndDate"]),
      cancelEndDate: nonempty(row["courseCancelEndDate"]),
      maxCount: integer(row["courseMaxCount"]),
      currentCount: integer(row["courseCurrentCount"]),
      campuses: Array(Set(campuses)).sorted(),
      summary: nonempty(row["courseDesc"]),
      selected: bool(row["selected"]) ?? false,
      hasSignConfig: nonempty(row["courseSignConfig"]) != nil
    )
  }

  private static func chosenCourses(_ data: [String: Any]) -> [BykcChosenCourse] {
    guard let rows = data["courseList"] as? [[String: Any]] else { return [] }
    return rows.compactMap { row in
      guard let id = integer64(row["id"]),
            let courseInfo = row["courseInfo"] as? [String: Any],
            let course = course(courseInfo) else { return nil }
      return BykcChosenCourse(
        id: id,
        course: course,
        selectedAt: nonempty(row["selectDate"]),
        checkin: integer(row["checkin"]),
        passed: integer(row["pass"]),
        score: integer(row["score"])
      )
    }
  }

  private static func statistics(_ data: [String: Any]) -> [BykcStatisticsEntry] {
    guard let statistical = data["statistical"] as? [String: Any] else { return [] }
    var result: [BykcStatisticsEntry] = []
    for categoryKey in statistical.keys.sorted() {
      guard let subcategories = statistical[categoryKey] as? [String: Any] else { continue }
      for subcategoryKey in subcategories.keys.sorted() {
        guard let row = subcategories[subcategoryKey] as? [String: Any],
              let required = integer(row["assessmentCount"]),
              let completed = integer(row["completeAssessmentCount"]) else { continue }
        result.append(BykcStatisticsEntry(
          category: categoryKey.components(separatedBy: "|").last ?? categoryKey,
          subcategory: subcategoryKey.components(separatedBy: "|").last ?? subcategoryKey,
          required: required,
          completed: completed
        ))
      }
    }
    return result
  }

  private static func normalizedDateTime(_ raw: String?) -> String? {
    guard let raw else { return nil }
    return String(raw.prefix(19)).replacingOccurrences(of: "T", with: " ")
  }

  private static func string(_ value: Any?) -> String? { JSONValue.string(value) }
  private static func nonempty(_ value: Any?) -> String? { JSONValue.nonEmptyString(value) }
  private static func integer(_ value: Any?) -> Int? { JSONValue.int(value) }
  private static func integer64(_ value: Any?) -> Int64? { JSONValue.int64(value) }
  private static func bool(_ value: Any?) -> Bool? { JSONValue.bool(value) }

  private static func nestedString(_ value: Any?, key: String) -> String? {
    guard let object = value as? [String: Any] else { return nil }
    return nonempty(object[key])
  }
}

enum BykcDate {
  static func parse(_ raw: String?) -> Date? {
    guard let raw, raw.isEmpty == false else { return nil }
    let normalized = String(raw.prefix(19)).replacingOccurrences(of: "T", with: " ")
    return SchoolTime.date(from: normalized, formats: [normalized.count > 10 ? "yyyy-MM-dd HH:mm:ss" : "yyyy-MM-dd"])
  }

  static func display(_ raw: String?) -> String? {
    guard let date = parse(raw) else { return raw }
    return date.formatted(.dateTime.year().month().day().hour().minute())
  }
}

enum BykcCrypto {
  private struct EncryptedRequest {
    let body: String
    let key: Data
    let ak: String
    let sk: String
    let ts: String
  }

  private static let publicKeyBase64 = "MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDlHMQ3B5GsWnCe7Nlo1YiG/YmHdlOiKOST5aRm4iaqYSvhvWmwcigoyWTM+8bv2+sf6nQBRDWTY4KmNV7DBk1eDnTIQo6ENA31k5/tYCLEXgjPbEjCK9spiyB62fCT6cqOhbamJB0lcDJRO6Vo1m3dy+fD0jbxfDVBBNtyltIsDQIDAQAB"
  private static let keyCharacters = Array("ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678")

  static func encrypt(_ payload: [String: Any]) throws -> (body: String, key: Data, ak: String, sk: String, ts: String) {
    let data = try JSONSerialization.data(withJSONObject: payload, options: [])
    let key = Data((0..<16).compactMap { _ in keyCharacters.randomElement() }.map { UInt8($0.asciiValue ?? 65) })
    let encrypted = try aes(data, key: key, encrypting: true)
    let digest = Data(sha1Hex(data).utf8)
    let request = EncryptedRequest(
      body: encrypted.base64EncodedString(),
      key: key,
      ak: try rsaEncrypt(key).base64EncodedString(),
      sk: try rsaEncrypt(digest).base64EncodedString(),
      ts: String(Int64(Date().timeIntervalSince1970 * 1_000))
    )
    return (request.body, request.key, request.ak, request.sk, request.ts)
  }

  static func decrypt(_ data: Data, key: Data) throws -> Data {
    try aes(data, key: key, encrypting: false)
  }

  /// 会话密钥为 16 字节随机串，AES-ECB + PKCS7（API.md 博雅章节）。
  private static func aes(_ data: Data, key: Data, encrypting: Bool) throws -> Data {
    guard key.count == 16 else { throw BykcError.crypto }
    let result = encrypting
      ? AESCipher.encrypt(data, key: Array(key), mode: .ecb)
      : AESCipher.decrypt(data, key: Array(key), mode: .ecb)
    guard let result else { throw BykcError.crypto }
    return result
  }

  private static func sha1Hex(_ data: Data) -> String {
    Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  private static func rsaEncrypt(_ data: Data) throws -> Data {
    guard let der = Data(base64Encoded: publicKeyBase64) else { throw BykcError.crypto }
    let attributes: [CFString: Any] = [
      kSecAttrKeyType: kSecAttrKeyTypeRSA,
      kSecAttrKeyClass: kSecAttrKeyClassPublic
    ]
    var error: Unmanaged<CFError>?
    guard let key = SecKeyCreateWithData(der as CFData, attributes as CFDictionary, &error),
          let encrypted = SecKeyCreateEncryptedData(key, .rsaEncryptionPKCS1, data as CFData, &error) else {
      throw BykcError.crypto
    }
    return encrypted as Data
  }
}
