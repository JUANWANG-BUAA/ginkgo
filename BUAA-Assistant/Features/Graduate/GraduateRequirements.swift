import Foundation

/// A requirement keeps its own scope. Parent and child gaps overlap and must never be added.
struct GraduateRequirement: Identifiable, Equatable {
  enum Kind: String { case total, category, group, course, joint, stage, unmapped }
  let id: String
  let title: String
  let path: [String]
  let kind: Kind
  var required: Double? = nil
  var earned: Double? = nil
  var inProgressCredits: Double? = nil
  var pending: Double? = nil
  var minimumCount: Int? = nil
  var completedCount: Int? = nil
  var note: String? = nil
  var code: String? = nil
  var credits: Double? = nil
  var completed: Bool? = nil
  var courseStatus: GraduateCourseProgressStatus? = nil
  var children: [GraduateRequirement] = []

  var gap: Double? {
    guard let required, let earned, required.isFinite, earned.isFinite,
          required >= 0, earned >= 0 else { return nil }
    return max(0, required - earned)
  }
  var countGap: Int? {
    guard let minimumCount, minimumCount > 0, let completedCount else { return nil }
    return max(0, minimumCount - completedCount)
  }
  var hasGap: Bool { (gap ?? 0) > 0.001 || (countGap ?? 0) > 0 }
  var needsAttention: Bool {
    hasGap || (kind != .course && gap == nil) || children.contains { $0.kind != .course && $0.needsAttention }
      || note?.isEmpty == false
  }
  var flattened: [Self] { [self] + children.flatMap(\.flattened) }
}

enum GraduateRequirementBuilder {
  static func build(
    _ snapshot: GraduateAcademicSnapshot,
    progress: GraduateProgressSummary? = nil
  ) -> GraduateRequirement {
    let execution = snapshot.planExecution
    let planTitle = snapshot.plan?.title ?? ""
    let title = planTitle.isEmpty ? "我的培养方案" : planTitle
    let categories = (execution?.categories ?? []).map { category -> GraduateRequirement in
      let path = [category.name]
      let id = "category/\(category.id)"
      let groups = category.groups.map { group in
        let groupID = "\(id)/group/\(group.id)"
        return GraduateRequirement(
          id: groupID, title: group.name, path: path + [group.name], kind: .group,
          required: group.requiredCredits, earned: group.earnedCredits,
          inProgressCredits: progress?.currentScheduleMatched != true
            ? nil
            : inProgressCredits(group.courses, progress: progress),
          pending: group.pendingCredits,
          children: courseNodes(group.courses, prefix: groupID, path: path + [group.name], progress: progress)
        )
      }
      let nestedKeys = Set(category.groups.flatMap(\.courses).map(courseKey))
      let directCourses = category.courses.filter { !nestedKeys.contains(courseKey($0)) }
      return GraduateRequirement(
        id: id, title: category.name, path: path, kind: .category,
        required: category.requiredCredits, earned: category.earnedCredits,
        inProgressCredits: progress?.currentScheduleMatched != true
          ? nil
          : inProgressCredits(category.allCourses, progress: progress),
        pending: category.pendingCredits, minimumCount: category.minimumCourseCount,
        completedCount: category.allCourses.filter(\.completed).count,
        note: category.requirementNote,
        children: groups + courseNodes(directCourses, prefix: id, path: path, progress: progress)
      )
    }
    var children = categories
    let executionNames = Set((execution?.categories ?? []).map { GraduateProgressBuilder.normalize($0.name) })
    let unmatchedInProgress = (progress?.courses ?? []).filter {
      $0.status == .inProgress && !executionNames.contains(GraduateProgressBuilder.normalize($0.category))
    }
    if unmatchedInProgress.isEmpty == false {
      let byCategory = Dictionary(grouping: unmatchedInProgress, by: \.category)
      let categoryRows = byCategory.keys.sorted().map { category in
        let courses = byCategory[category] ?? []
        let courseNodes = courses.map { course in
          GraduateRequirement(
            id: "schedule-unmapped/\(GraduateProgressBuilder.normalize(category))/\(course.id)",
            title: course.planCourse.name,
            path: ["本学期在修 · 尚未匹配执行层级", category, course.planCourse.name],
            kind: .course,
            note: course.note ?? "课程来自本学期课表，尚未归入学校执行报告类别。",
            code: course.planCourse.code,
            credits: course.planCourse.credits,
            courseStatus: .inProgress
          )
        }
        return GraduateRequirement(
          id: "schedule-unmapped/category/\(GraduateProgressBuilder.normalize(category))",
          title: category,
          path: ["本学期在修 · 尚未匹配执行层级", category],
          kind: .unmapped,
          inProgressCredits: courses.reduce(0) { $0 + $1.credits },
          note: "当前培养方案课程的类别与学校执行报告没有精确匹配，因此不会被计入任一类别的已获学分或缺口。",
          children: courseNodes
        )
      }
      children.append(GraduateRequirement(
        id: "schedule-unmapped",
        title: "本学期在修 · 尚未匹配执行层级",
        path: ["本学期在修 · 尚未匹配执行层级"],
        kind: .unmapped,
        inProgressCredits: unmatchedInProgress.reduce(0) { $0 + $1.credits },
        note: "以下课程已匹配到本学期课表，但未能匹配学校执行报告类别；不把它们猜作某一类别的学分或缺口。",
        children: categoryRows
      ))
    }
    if let required = snapshot.plan?.degreeCourseCredits, required > 0 {
      children.append(GraduateRequirement(
        id: "degree", title: "学位课最低学分", path: ["学位课最低学分"], kind: .joint,
        required: required,
        note: "要求来自方案头部；学校未单列对应的已获学分，需结合执行报告核对，不能按类别名称相加推断。"
      ))
    }
    if let required = snapshot.plan?.jointCourseCredits, required > 0 {
      children.append(GraduateRequirement(
        id: "joint", title: "校企课程", path: ["校企课程"], kind: .joint,
        required: required, earned: execution?.jointEarnedCredits,
        note: "此要求与课程类别可能重叠，单独核对，不叠加到总学分。"
      ))
    }
    if let required = execution?.stageRequiredCredits, required > 0 {
      children.append(GraduateRequirement(
        id: "stage", title: "分阶段培养", path: ["分阶段培养"], kind: .stage,
        required: required, earned: execution?.stageEarnedCredits
      ))
    }
    return GraduateRequirement(
      id: "total", title: title, path: [], kind: .total,
      required: execution?.totalRequiredCredits ?? snapshot.plan?.totalCredits,
      earned: execution?.earnedCredits,
      inProgressCredits: progress?.currentTermInProgressCredits,
      pending: execution?.pendingCredits,
      children: children
    )
  }

  private static func courseNodes(
    _ courses: [GraduatePlanExecutionCourse], prefix: String, path: [String],
    progress: GraduateProgressSummary?
  ) -> [GraduateRequirement] {
    var seen = Set<String>()
    return courses.filter { seen.insert($0.id).inserted }.map { course in
      let matchingProgress = progress?.courses.first { progressCourse in
        let planCode = progressCourse.planCourse.code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !course.code.isEmpty, !planCode.isEmpty { return course.code.caseInsensitiveCompare(planCode) == .orderedSame }
        return GraduateProgressBuilder.normalize(course.name) == GraduateProgressBuilder.normalize(progressCourse.planCourse.name)
      }
      let status: GraduateCourseProgressStatus
      if course.completed {
        status = .completed
      } else if matchingProgress?.status == .inProgress {
        status = .inProgress
      } else if matchingProgress?.status == .completed {
        status = .completed
      } else if matchingProgress?.status == .notPassed {
        status = .notPassed
      } else {
        status = .needsReview
      }
      let detailNote = !course.completed && matchingProgress?.status == .completed
        ? "成绩显示已通过，学校执行报告尚未确认"
        : matchingProgress?.note
      return GraduateRequirement(
        id: "\(prefix)/course/\(course.id)", title: course.name, path: path + [course.name], kind: .course,
        note: [course.grade, course.term, detailNote].compactMap { $0 }.joined(separator: " · "),
        code: course.code, credits: course.credits, completed: course.completed, courseStatus: status
      )
    }
  }

  private static func inProgressCredits(
    _ courses: [GraduatePlanExecutionCourse], progress: GraduateProgressSummary?
  ) -> Double? {
    guard let progress, progress.currentScheduleMatched else { return nil }
    let matching = courses.filter { !$0.completed }.compactMap { course in
      progress.courses.first { item in
        let planCode = item.planCourse.code?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !course.code.isEmpty, !planCode.isEmpty { return course.code.caseInsensitiveCompare(planCode) == .orderedSame }
        return GraduateProgressBuilder.normalize(course.name) == GraduateProgressBuilder.normalize(item.planCourse.name)
      }
    }
    let active = matching.filter { $0.status == .inProgress }
    guard active.allSatisfy({ $0.planCourse.credits != nil }) else { return nil }
    return active.reduce(0) { $0 + $1.credits }
  }

  private static func courseKey(_ course: GraduatePlanExecutionCourse) -> String {
    course.code.isEmpty ? GraduateProgressBuilder.normalize(course.name) : course.code.uppercased()
  }
}
