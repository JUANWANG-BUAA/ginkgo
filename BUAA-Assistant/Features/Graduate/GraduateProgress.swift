import Foundation

/// 培养方案与当前课表/成绩的对照结果。只做名称/课程代码的保守匹配，
/// 不把无法确认的课程直接当成“已修”或“待修”。
enum GraduateCourseProgressStatus: String, Codable, Equatable {
  case completed
  case inProgress
  case notPassed
  case remaining
  case needsReview

  var title: String {
    switch self {
    case .completed: "已修"
    case .inProgress: "在修"
    case .notPassed: "未通过"
    case .remaining: "课程池候选"
    case .needsReview: "待核对"
    }
  }

  var sortOrder: Int {
    switch self {
    case .completed: 0
    case .inProgress: 1
    case .notPassed: 2
    case .needsReview: 3
    case .remaining: 4
    }
  }
}

struct GraduateCourseProgress: Identifiable, Equatable {
  let planCourse: GraduatePlanCourse
  let status: GraduateCourseProgressStatus
  let matchedName: String?
  let score: String?
  let note: String?

  var id: String { planCourse.id }
  var credits: Double { max(0, planCourse.credits ?? 0) }
  var category: String {
    if let category = planCourse.category, category.isEmpty == false { return category }
    return "未分类"
  }
  var isRequired: Bool { planCourse.required == "是" }
}

struct GraduateCategoryGroupProgress: Identifiable, Equatable {
  let name: String
  let requiredCredits: Double?
  let earnedCredits: Double?
  let pendingCredits: Double?

  var id: String { name }
}

struct GraduateCategoryProgress: Identifiable, Equatable {
  let category: String
  /// 课程池规模，不是类别最低学分。
  let totalCredits: Double
  let completedCredits: Double
  let inProgressCredits: Double
  let needsReviewCredits: Double
  let courseCount: Int
  let completedCount: Int
  let requiredCredits: Double?
  let pendingCredits: Double?
  let minimumCourseCount: Int?
  let requirementNote: String?
  let groups: [GraduateCategoryGroupProgress]

  var id: String { category }
  /// `totalCredits` 是课程池规模，不是类别最低学分要求。
  var matchedCredits: Double {
    completedCredits + inProgressCredits + needsReviewCredits
  }
  var unmatchedCredits: Double {
    max(0, totalCredits - matchedCredits)
  }
}

struct GraduateProgressSummary: Equatable {
  let totalCredits: Double
  let completedCredits: Double
  let inProgressCredits: Double
  let needsReviewCredits: Double
  let remainingCredits: Double
  let requiredRemainingCredits: Double
  let electiveRemainingCredits: Double
  let categories: [GraduateCategoryProgress]
  let courses: [GraduateCourseProgress]
  let notes: [String]
  let planCourseCount: Int
  let coursePoolCredits: Double
  let matchedCourseCount: Int
  let gradeCount: Int
  let scheduleCourseCount: Int
  var currentScheduleMatched = false

  var currentTermInProgressCredits: Double? {
    guard currentScheduleMatched else { return nil }
    let active = courses.filter { $0.status == .inProgress }
    guard active.allSatisfy({ $0.planCourse.credits != nil }) else { return nil }
    return active.reduce(0) { $0 + $1.credits }
  }

  var inProgressCourseCount: Int {
    courses.filter { $0.status == .inProgress }.count
  }

  var needsReviewCourseCount: Int {
    courses.filter { $0.status == .needsReview }.count
  }

  func courses(status: GraduateCourseProgressStatus) -> [GraduateCourseProgress] {
    courses.filter { $0.status == status }
  }
}

enum GraduateProgressBuilder {
  static func build(
    academic: GraduateAcademicSnapshot,
    schedule: ScheduleSnapshot?
  ) -> GraduateProgressSummary {
    let plan = academic.plan
    let planCourses = plan?.courses ?? []
    let grades = academic.grades
    let currentScheduleMatched = termMatches(schedule?.termID, academic.currentTermID)
    let scheduleNames = currentScheduleMatched
      ? scheduleCourseNames(schedule) : []
    let executionCourses = academic.planExecution?.categories.flatMap(\.allCourses) ?? []

    var gradeByCode: [String: GraduateGradeRecord] = [:]
    var gradeByName: [String: GraduateGradeRecord] = [:]
    for grade in grades {
      if let code = grade.courseCode, code.isEmpty == false {
        let key = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if gradeByCode[key] == nil || passingStatus(grade.score) == true {
          gradeByCode[key] = grade
        }
      }
      let key = normalize(grade.courseName)
      if key.isEmpty == false, gradeByName[key] == nil || passingStatus(grade.score) == true {
        gradeByName[key] = grade
      }
    }

    var courses: [GraduateCourseProgress] = []

    for planCourse in planCourses {
      let normalizedName = normalize(planCourse.name)
      let codeKey = planCourse.code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
      let byName = gradeByName[normalizedName]
      let nameCompatible = codeKey.isEmpty || byName?.courseCode?.isEmpty != false
      let grade = (codeKey.isEmpty ? nil : gradeByCode[codeKey]) ?? (nameCompatible ? byName : nil)
      let reported = executionCourses.filter {
        if !codeKey.isEmpty, !$0.code.isEmpty { return $0.code.uppercased() == codeKey }
        return normalize($0.name) == normalizedName
      }
      let official = reported.first(where: \.completed) ?? reported.first
      let scheduleMatched = scheduleNames.contains(normalizedName)

      let status: GraduateCourseProgressStatus
      let note: String?
      if official?.completed == true {
        status = .completed
        note = "学校执行报告已确认完成"
      } else if let grade {
        switch passingStatus(grade.score) {
        case .some(true):
          status = .completed
          note = nil
        case .some(false):
          status = .notPassed
          note = "成绩 \(grade.score ?? "未显示")，未通过"
        case .none:
          status = .needsReview
          note = "有成绩记录，但成绩格式无法判断"
        }
      } else if scheduleMatched {
        status = .inProgress
        note = "已匹配到本学期课表"
      } else if official != nil {
        status = .needsReview
        note = "学校执行报告标为待考核；尚未计入已获学分"
      } else {
        status = .remaining
        note = "课程池候选，尚未匹配到修读记录"
      }

      courses.append(
        GraduateCourseProgress(
          planCourse: planCourse,
          status: status,
          matchedName: official?.name ?? grade?.courseName ?? (scheduleMatched ? planCourse.name : nil),
          score: official?.grade ?? grade?.score,
          note: note
        )
      )
    }

    let planCourseCredits = courses.reduce(0) { $0 + $1.credits }
    let execution = academic.planExecution
    let headerTotal = max(0, execution?.totalRequiredCredits ?? plan?.totalCredits ?? 0)
    // A course pool never supplies a missing minimum requirement.
    let totalCredits = headerTotal

    var categoryMap: [String: (total: Double, completed: Double, inProgress: Double, needsReview: Double, count: Int, completedCount: Int)] = [:]
    for course in courses {
      var entry = categoryMap[course.category] ?? (0, 0, 0, 0, 0, 0)
      entry.total += course.credits
      entry.count += 1
      switch course.status {
      case .completed:
        entry.completed += course.credits
        entry.completedCount += 1
      case .inProgress: entry.inProgress += course.credits
      case .notPassed: break
      case .needsReview: entry.needsReview += course.credits
      case .remaining: break
      }
      categoryMap[course.category] = entry
    }

    let computedCompleted = courses.filter { $0.status == .completed }.reduce(0) { $0 + $1.credits }
    let inProgressCredits = uniqueCourses(courses.filter { $0.status == .inProgress })
      .reduce(0) { $0 + $1.credits }
    let needsReviewCredits = courses.filter { $0.status == .needsReview }.reduce(0) { $0 + $1.credits }
    let completedCredits = execution?.earnedCredits ?? computedCompleted
    let remainingCredits = max(0, totalCredits - completedCredits)

    var categories: [GraduateCategoryProgress] = []
    if let execution, execution.categories.isEmpty == false {
      for executionCategory in execution.categories {
        let matched = courses.filter {
          normalize($0.category) == normalize(executionCategory.name)
        }
        let allExecutionCourses = executionCategory.allCourses
        let poolCredits = allExecutionCourses.reduce(0) { $0 + max(0, $1.credits ?? 0) }
        let matchedPoolCredits = poolCredits > 0 ? poolCredits : matched.reduce(0) { $0 + $1.credits }
        let matchedInProgress = matched.filter { $0.status == .inProgress }.reduce(0) { $0 + $1.credits }
        let matchedNeedsReview = matched.filter { $0.status == .needsReview }.reduce(0) { $0 + $1.credits }
        let completedCount = allExecutionCourses.filter(\.completed).count
        let groups = executionCategory.groups.map {
          GraduateCategoryGroupProgress(
            name: $0.name,
            requiredCredits: $0.requiredCredits,
            earnedCredits: $0.earnedCredits,
            pendingCredits: $0.pendingCredits
          )
        }
        categories.append(
          GraduateCategoryProgress(
            category: executionCategory.name,
            totalCredits: matchedPoolCredits,
            completedCredits: executionCategory.earnedCredits ?? matched.filter { $0.status == .completed }.reduce(0) { $0 + $1.credits },
            inProgressCredits: matchedInProgress,
            needsReviewCredits: matchedNeedsReview,
            courseCount: allExecutionCourses.count,
            completedCount: completedCount,
            requiredCredits: executionCategory.requiredCredits,
            pendingCredits: executionCategory.pendingCredits,
            minimumCourseCount: executionCategory.minimumCourseCount,
            requirementNote: executionCategory.requirementNote,
            groups: groups
          )
        )
      }
      let executionNames = Set(execution.categories.map { normalize($0.name) })
      for (key, value) in categoryMap where executionNames.contains(normalize(key)) == false {
        categories.append(
          GraduateCategoryProgress(
            category: key,
            totalCredits: value.total,
            completedCredits: value.completed,
            inProgressCredits: value.inProgress,
            needsReviewCredits: value.needsReview,
            courseCount: value.count,
            completedCount: value.completedCount,
            requiredCredits: nil,
            pendingCredits: nil,
            minimumCourseCount: nil,
            requirementNote: nil,
            groups: []
          )
        )
      }
    } else {
      categories = categoryMap.map { key, value in
        GraduateCategoryProgress(
          category: key,
          totalCredits: value.total,
          completedCredits: value.completed,
          inProgressCredits: value.inProgress,
          needsReviewCredits: value.needsReview,
          courseCount: value.count,
          completedCount: value.completedCount,
          requiredCredits: nil,
          pendingCredits: nil,
          minimumCourseCount: nil,
          requirementNote: nil,
          groups: []
        )
      }
    }
    categories.sort { lhs, rhs in
      if lhs.category == "校企课程" { return false }
      if rhs.category == "校企课程" { return true }
      if lhs.category == "方案未列课程/环节" { return false }
      if rhs.category == "方案未列课程/环节" { return true }
      return lhs.category.localizedStandardCompare(rhs.category) == .orderedAscending
    }
    let requiredRemaining = courses
      .filter { ($0.status == .remaining || $0.status == .notPassed) && $0.isRequired }
      .reduce(0) { $0 + $1.credits }
    let electiveRemaining = courses
      .filter { ($0.status == .remaining || $0.status == .notPassed) && $0.isRequired == false }
      .reduce(0) { $0 + $1.credits }

    var notes: [String] = []
    if grades.isEmpty {
      notes.append("成绩列表暂无记录；培养方案已获学分优先采用学校执行报告。")
    }
    if scheduleNames.isEmpty {
      notes.append("尚未匹配到当前学期课表；不使用历史学期推断在修状态。")
    }
    if courses.contains(where: { $0.status == .needsReview }) {
      notes.append("部分课程有成绩记录但成绩格式无法判断，已单列为“待核对”。")
    }
    if courses.contains(where: { $0.planCourse.credits == nil }) {
      notes.append("部分计划课程未返回学分，学分合计可能偏低。")
    }
    let unmatchedCount = courses.filter { $0.status == .remaining && $0.matchedName == nil }.count
    if unmatchedCount > 0 {
      notes.append("\(unmatchedCount) 门计划课程未匹配到成绩或当前课表；它们可能只是课程池中的可选课，不等于都需修读。")
    }
    if planCourseCredits > totalCredits + 0.01 {
      notes.append("培养方案课程池合计 \(formatCredit(planCourseCredits)) 学分，方案总学分要求为 \(formatCredit(totalCredits))；页面按总要求计算进度，课程池中的课程不是全部必修。")
      if execution == nil {
        notes.append("类别卡片显示的是课程池规模与已修/在修分布；方案未返回结构化的类别最低学分，因此不推断“某类别还差多少”。")
      } else {
        notes.append("类别/课组最低学分来自学校培养方案执行报告；课程池中的课程仍不是全部必修。")
      }
    }
    let gradeOutsidePlan = grades.filter { grade in
      !planCourses.contains { planCourse in
        if let code = grade.courseCode, code.isEmpty == false,
           let planCode = planCourse.code, planCode.isEmpty == false,
           code.caseInsensitiveCompare(planCode) == .orderedSame {
          return true
        }
        return normalize(grade.courseName) == normalize(planCourse.name)
      }
    }
    if gradeOutsidePlan.isEmpty == false {
      notes.append("成绩中有 \(gradeOutsidePlan.count) 门课程不在培养方案课程列表，未计入进度。")
    }
    let scheduleOutsidePlan = scheduleNames.filter { name in
      !planCourses.contains { normalize($0.name) == name }
    }
    if scheduleOutsidePlan.isEmpty == false {
      notes.append("课表中有 \(scheduleOutsidePlan.count) 门课程不在培养方案课程列表，未计入进度。")
    }

    return GraduateProgressSummary(
      totalCredits: totalCredits,
      completedCredits: completedCredits,
      inProgressCredits: inProgressCredits,
      needsReviewCredits: needsReviewCredits,
      remainingCredits: remainingCredits,
      requiredRemainingCredits: requiredRemaining,
      electiveRemainingCredits: electiveRemaining,
      categories: categories,
      courses: courses.sorted {
        if $0.status.sortOrder != $1.status.sortOrder { return $0.status.sortOrder < $1.status.sortOrder }
        return $0.planCourse.name.localizedStandardCompare($1.planCourse.name) == .orderedAscending
      },
      notes: notes,
      planCourseCount: planCourses.count,
      coursePoolCredits: planCourseCredits,
      matchedCourseCount: courses.filter { $0.matchedName != nil }.count,
      gradeCount: grades.count,
      scheduleCourseCount: scheduleNames.count,
      currentScheduleMatched: currentScheduleMatched
    )
  }

  private static func uniqueCourses(_ courses: [GraduateCourseProgress]) -> [GraduateCourseProgress] {
    var seen = Set<String>()
    return courses.filter { course in
      let code = course.planCourse.code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
      let key = code.isEmpty ? normalize(course.planCourse.name) : code
      return !key.isEmpty && seen.insert(key).inserted
    }
  }

  static func normalize(_ value: String) -> String {
    value
      .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "zh_CN"))
      .replacingOccurrences(of: " ", with: "")
      .replacingOccurrences(of: "（", with: "(")
      .replacingOccurrences(of: "）", with: ")")
      .replacingOccurrences(of: "：", with: ":")
      .replacingOccurrences(of: "·", with: "")
      .lowercased()
  }

  static func passingStatus(_ score: String?) -> Bool? {
    guard let raw = score?.trimmingCharacters(in: .whitespacesAndNewlines), raw.isEmpty == false else {
      return nil
    }
    if let value = Double(raw.replacingOccurrences(of: "%", with: "")) {
      return value >= 60
    }
    let text = raw.replacingOccurrences(of: " ", with: "").uppercased()
    let failing = ["不及格", "不合格", "未通过", "不通过", "FAIL", "F", "E"]
    if failing.contains(text) { return false }
    let passing = ["优秀", "良好", "中等", "及格", "合格", "通过", "PASS", "P", "A", "B", "C", "D"]
    if passing.contains(text) || ["A+", "A-", "B+", "B-", "C+", "C-", "D+", "D-"].contains(text) { return true }
    return nil
  }

  static func termMatches(_ lhs: String?, _ rhs: String?) -> Bool {
    func canonical(_ term: String?) -> String? {
      guard let term else { return nil }
      let parts = term.split(separator: "-")
      if parts.count >= 2, parts[0].count == 4, let semester = parts.last {
        return String(parts[0]) + String(semester)
      }
      return term.count == 5 ? term : nil
    }
    guard let left = canonical(lhs), let right = canonical(rhs) else { return false }
    return left == right
  }

  private static func scheduleCourseNames(_ snapshot: ScheduleSnapshot?) -> Set<String> {
    guard let snapshot else { return [] }
    var names = Set<String>()
    for course in snapshot.courses {
      names.insert(normalize(course.name))
    }
    if let termCourses = snapshot.termCourses {
      for courses in termCourses.values {
        for course in courses {
          names.insert(normalize(course.name))
        }
      }
    }
    names.remove("")
    return names
  }

  private static func formatCredit(_ value: Double) -> String {
    value.rounded() == value ? "\(Int(value))" : String(format: "%.1f", value)
  }
}
