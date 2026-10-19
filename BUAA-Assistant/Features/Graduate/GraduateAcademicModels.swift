import Foundation

struct GraduateStatusSummary: Codable, Equatable {
  let college: String?
  let major: String?
  let grade: String?
  let degreeLevel: String?
  let studentType: String?
  let status: String?
  let className: String?
  let campus: String?
  let studyMode: String?
  let enrollmentDate: String?
  let expectedGraduation: String?
}

struct GraduatePlanCourse: Codable, Equatable, Identifiable, Hashable {
  let id: String
  let name: String
  let code: String?
  let credits: Double?
  let category: String?
  let examMode: String?
  let term: String?
  let required: String?

  var creditText: String? {
    credits.map { "\(GraduateCredit.text($0)) 学分" }
  }
}

struct GraduatePlanSection: Codable, Equatable, Identifiable, Hashable {
  let id: String
  let title: String
  let content: String?
}

struct GraduatePlan: Codable, Equatable {
  let title: String
  let college: String?
  let major: String?
  let totalCredits: Double?
  let degreeCourseCredits: Double?
  let jointCourseCredits: Double?
  let reviewStatus: String?
  let sections: [GraduatePlanSection]
  let courses: [GraduatePlanCourse]
}

struct GraduatePlanExecution: Codable, Equatable {
  let totalRequiredCredits: Double?
  let earnedCredits: Double?
  let pendingCredits: Double?
  let researchCredits: Double?
  let stageRequiredCredits: Double?
  let stageEarnedCredits: Double?
  let categories: [GraduatePlanExecutionCategory]
  var totalEarnedCredits: Double? = nil
  var jointEarnedCredits: Double? = nil
}

struct GraduatePlanExecutionCategory: Codable, Equatable, Identifiable {
  let code: String
  let name: String
  let requiredCredits: Double?
  let earnedCredits: Double?
  let pendingCredits: Double?
  let minimumCourseCount: Int?
  let requirementNote: String?
  let groups: [GraduatePlanExecutionGroup]
  let courses: [GraduatePlanExecutionCourse]

  var id: String { code.isEmpty ? name : code }

  /// 直接课程与课组课程去重后的课程池。
  var allCourses: [GraduatePlanExecutionCourse] {
    var result: [GraduatePlanExecutionCourse] = []
    var positions: [String: Int] = [:]
    for course in courses + groups.flatMap(\.courses) {
      let key = course.code.isEmpty ? course.name : course.code
      if let index = positions[key] {
        if course.completed { result[index] = course }
      } else {
        positions[key] = result.count
        result.append(course)
      }
    }
    return result
  }
}

struct GraduatePlanExecutionGroup: Codable, Equatable, Identifiable {
  let code: String
  let name: String
  let requiredCredits: Double?
  let earnedCredits: Double?
  let pendingCredits: Double?
  let courses: [GraduatePlanExecutionCourse]

  var id: String { code.isEmpty ? name : code }
}

struct GraduatePlanExecutionCourse: Codable, Equatable, Identifiable, Hashable {
  let code: String
  let name: String
  let credits: Double?
  let completed: Bool
  let grade: String?
  let term: String?
  let category: String?
  let courseAttribute: String?

  var id: String { code.isEmpty ? name : code }
}

struct GraduateExamSummary: Codable, Equatable {
  let examCount: Int
  let quizCourseCount: Int
  let invigilationCount: Int

  var total: Int { examCount + quizCourseCount + invigilationCount }
}

struct GraduateGradeRecord: Codable, Equatable, Identifiable {
  let id: String
  let courseName: String
  let courseCode: String?
  let score: String?
  let credits: Double?
  let gradePoint: String?
  let category: String?
}

struct GraduateModuleOption: Codable, Equatable, Identifiable, Hashable {
  let id: String
  let name: String
}

struct GraduateModuleApp: Codable, Equatable, Identifiable, Hashable {
  let id: String
  let name: String
  let menus: [GraduateModuleOption]
}

struct GraduateModuleCategory: Codable, Equatable, Identifiable, Hashable {
  let id: String
  let name: String
  let apps: [GraduateModuleApp]
}

enum GraduateAcademicSection: String, Codable, CaseIterable {
  case plan, execution, grades, exams, modules, term

  var title: String {
    switch self {
    case .plan: "培养方案"
    case .execution: "方案执行报告"
    case .grades: "成绩"
    case .exams: "考试"
    case .modules: "服务目录"
    case .term: "当前学期"
    }
  }
}

struct GraduateAcademicIssue: Codable, Equatable {
  let section: GraduateAcademicSection
  let message: String
  var usesPreviousData = false
}

struct GraduateAcademicSnapshot: Codable, Equatable {
  let status: GraduateStatusSummary
  let plan: GraduatePlan?
  let planExecution: GraduatePlanExecution?
  let examSummary: GraduateExamSummary
  let grades: [GraduateGradeRecord]
  let moduleCategories: [GraduateModuleCategory]
  let fetchedAt: Date
  var currentTermID: String? = nil
  var issues: [GraduateAcademicIssue]? = nil
  var sourceDates: [String: Date]? = nil

  func issue(for section: GraduateAcademicSection) -> GraduateAcademicIssue? {
    issues?.first { $0.section == section }
  }

  func retainingSuccessfulData(from previous: Self?) -> Self {
    guard let previous else { return self }
    let failed = Set((issues ?? []).map(\.section))
    var result = Self(
      status: status,
      plan: failed.contains(.plan) ? previous.plan : plan,
      planExecution: failed.contains(.execution) ? previous.planExecution : planExecution,
      examSummary: failed.contains(.exams) ? previous.examSummary : examSummary,
      grades: failed.contains(.grades) ? previous.grades : grades,
      moduleCategories: failed.contains(.modules) ? previous.moduleCategories : moduleCategories,
      fetchedAt: fetchedAt,
      currentTermID: failed.contains(.term) ? previous.currentTermID : currentTermID,
      issues: issues,
      sourceDates: sourceDates
    )
    result.issues = (issues ?? []).map { issue in
      var copy = issue
      copy.usesPreviousData = previous.sourceDates?[issue.section.rawValue] != nil
      return copy
    }
    for section in failed {
      result.sourceDates?[section.rawValue] = previous.sourceDates?[section.rawValue]
    }
    return result
  }
}

enum GraduateAcademicError: LocalizedError {
  case unavailable
  case invalidResponse(String)
  case upstream(String)

  var errorDescription: String? {
    switch self {
    case .unavailable: "研究生教务服务暂时不可用"
    case .invalidResponse(let stage): "研究生教务返回结构无法识别：\(stage)"
    case .upstream(let message): "研究生教务请求失败：\(message)"
    }
  }
}

/// Only destinations already observed in the school portal; never infer URLs from a menu ID.
enum GraduateAcademicDestination {
  case portal, execution
  var url: URL? {
    let path: String
    switch self {
    case .portal: path = "yjsemaphome/portal/index.do"
    case .execution: path = "wdpyfazxbgappbuaa/*default/index.do"
    }
    guard let upstream = URL(string: "https://gsmis.buaa.edu.cn/gsapp/sys/" + path) else { return nil }
    return EffectiveUpstreamRoute.current == .webVPN ? (try? WebVPNRouter.wrap(upstream)) : upstream
  }
}

/// 学分的统一显示：整数不带小数，其余保留一位；缺值显示破折号。
enum GraduateCredit {
  static func text(_ value: Double?) -> String {
    guard let value, value.isFinite else { return "—" }
    return value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value)
  }
}
