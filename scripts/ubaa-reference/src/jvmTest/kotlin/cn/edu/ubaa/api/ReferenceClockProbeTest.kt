package cn.edu.ubaa.api

import cn.edu.ubaa.api.local.LocalJudgeApiBackend
import cn.edu.ubaa.api.core.ApiFactory
import cn.edu.ubaa.api.core.DefaultApiFactory
import cn.edu.ubaa.api.feature.JudgeApiBackend
import cn.edu.ubaa.model.dto.JudgeAssignmentDetailDto
import cn.edu.ubaa.model.dto.JudgeSubmissionStatus
import kotlinx.datetime.LocalDateTime
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ReferenceClockProbeTest {
  @Test
  fun originalJudgeTestsWithExplicitFixtureClock() {
    val names = listOf(
        "judge api uses direct upstream backend to fetch assignments",
        "judge api sends browser headers like python client",
        "judge api does not cache empty assignment lists",
        "judge api reactivates session and retries when judge page returns login html",
        "judge api activates direct judge cas session before fetching assignments",
    )
    for (name in names) {
      val original = LocalJudgeApiBackendTest()
      original.setup()
      try {
        val backend = LocalJudgeApiBackend(nowProvider = { LocalDateTime.parse("2026-05-01T12:00:00") })
        val factory = object : ApiFactory by DefaultApiFactory {
          override fun judgeApi(): JudgeApiBackend = backend
        }
        ConnectionRuntime.apiFactoryProvider = { factory }
        LocalJudgeApiBackendTest::class.java.getDeclaredMethod(name).invoke(original)
        println("CLOCK_CONTROL $name passed")
      } finally {
        original.tearDown()
      }
    }
  }

  @Test
  fun originalJudgeCutoffDependsOnWallDate() {
    val assignment = JudgeAssignmentDetailDto(
        courseId = "1", courseName = "synthetic", assignmentId = "101",
        title = "synthetic", startTime = "2026-04-20 19:00:00",
        submissionStatus = JudgeSubmissionStatus.UNSUBMITTED,
        submissionStatusText = "synthetic",
    )
    val predicate = LocalJudgeApiBackend::class.java.getDeclaredMethod(
        "startedBeforeSixMonthCutoff", JudgeAssignmentDetailDto::class.java,
    )
    predicate.isAccessible = true
    fun expiredOn(day: String): Boolean {
      val backend = LocalJudgeApiBackend(nowProvider = { LocalDateTime.parse(day) })
      return predicate.invoke(backend, assignment) as Boolean
    }
    assertFalse(expiredOn("2026-05-01T12:00:00"))
    assertTrue(expiredOn("2026-11-03T12:00:00"))
  }
}
