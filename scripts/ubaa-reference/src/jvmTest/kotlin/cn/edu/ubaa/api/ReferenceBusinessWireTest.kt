package cn.edu.ubaa.api

import cn.edu.ubaa.api.feature.ScheduleApi
import cn.edu.ubaa.api.feature.SigninApi
import cn.edu.ubaa.api.feature.GradeApi
import cn.edu.ubaa.api.feature.ClassroomApi
import cn.edu.ubaa.api.local.LocalAuthSession
import cn.edu.ubaa.api.local.LocalAuthSessionStore
import cn.edu.ubaa.api.local.LocalCookieStore
import cn.edu.ubaa.api.local.LocalLibBookApiBackend
import cn.edu.ubaa.api.local.LocalUpstreamClientProvider
import cn.edu.ubaa.api.local.LocalWebVpnSupport
import cn.edu.ubaa.model.dto.UserData
import com.russhwolf.settings.MapSettings
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.Url
import io.ktor.http.content.OutgoingContent
import io.ktor.http.content.TextContent
import io.ktor.http.headersOf
import java.io.File
import kotlin.test.Test
import kotlin.test.assertTrue
import kotlin.time.Clock
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.TimeZone
import kotlinx.datetime.toLocalDateTime
import kotlinx.serialization.json.*

class ReferenceBusinessWireTest {
  @Test
  fun captureBusinessRequests() = runTest {
    localConnectionTestMutex.lock()
    try {
      val json = Json { ignoreUnknownKeys = true }
      val fixture = json.parseToJsonElement(File(System.getenv("GINKGO_REFERENCE_RESPONSES")).readText()).jsonObject
      val responses = fixture.getValue("responses").jsonArray
      val day = Clock.System.now().toLocalDateTime(TimeZone.of("Asia/Shanghai")).date.toString()
      val cases = mutableListOf<JsonElement>()
      ConnectionModeStore.settings = MapSettings()
      LocalAuthSessionStore.settings = MapSettings()
      LocalCookieStore.settings = MapSettings()
      for (mode in listOf(ConnectionMode.DIRECT, ConnectionMode.WEBVPN)) {
        for (operation in listOf("terms", "checkin", "checkin-nonempty", "library", "grades", "classroom")) {
          LocalUpstreamClientProvider.reset()
          ConnectionRuntime.clearSelectedMode()
          ConnectionModeStore.save(mode)
          ConnectionRuntime.resolveSelectedMode()
          LocalAuthSessionStore.save(LocalAuthSession("sy2501001", UserData("fixture", "sy2501001"), "2026-11-03T00:00:00Z", "2026-11-03T00:00:00Z"))
          val requests = mutableListOf<JsonElement>()
          val engine = MockEngine { request ->
            val original = LocalWebVpnSupport.fromWebVpnUrl(request.url.toString())
            val body = when (val content = request.body) {
              is TextContent -> content.text
              is OutgoingContent.ByteArrayContent -> content.bytes().decodeToString()
              is OutgoingContent.NoContent -> ""
              else -> error("Unsupported synthetic body")
            }
            val headers = request.headers.entries().associate { it.key.lowercase() to it.value.joinToString(", ") }.toMutableMap()
            request.body.contentType?.let { headers.putIfAbsent("content-type", it.toString()) }
            requests += buildJsonObject {
              put("method", request.method.value); put("url", request.url.toString()); put("body", body)
              put("headers", buildJsonObject { headers.forEach { (key, value) -> put(key, value) } })
            }
            val response = responses.single { it.jsonObject.getValue("path").jsonPrimitive.content == Url(original).encodedPath }.jsonObject
            val location = (if (operation == "classroom") response["classroom_location"] ?: response["location"] else response["location"])?.jsonPrimitive?.content
            val responseBody = if (operation == "checkin-nonempty" && Url(original).encodedPath.endsWith("get_stu_course_sched.action")) fixture.getValue("nonempty_checkin_body").jsonPrimitive.content else if (request.method.value == "GET" && "get_body" in response) response.getValue("get_body").jsonPrimitive.content else response.getValue("body").jsonPrimitive.content
            respond(responseBody, HttpStatusCode.fromValue(response.getValue("status").jsonPrimitive.int), if (location != null) headersOf(HttpHeaders.Location, location) else headersOf(HttpHeaders.ContentType, "application/json"))
          }
          val factory: (Boolean) -> HttpClient = { redirects ->
            referenceClient(engine, redirects, LocalCookieStore.storage(mode))
          }
          LocalUpstreamClientProvider.clientFactory = factory
          LocalUpstreamClientProvider.libBookClientFactory = factory
          var values: JsonArray? = null
          val result = when (operation) {
            "terms" -> ScheduleApi().getTerms().map { it.size }
            "checkin", "checkin-nonempty" -> SigninApi().getTodayClasses().map { result ->
              if (operation == "checkin-nonempty") values = JsonArray(result.data.map { course -> buildJsonObject {
                put("id", course.courseId); put("name", course.courseName)
                put("begin", course.classBeginTime); put("end", course.classEndTime); put("sign_status", course.signStatus)
              } })
              result.data.size
            }
            "library" -> LocalLibBookApiBackend().getLibraries(day).map { it.size }
            "grades" -> GradeApi().getGrades("2025-2026-1").map { it.grades.size }
            "classroom" -> ClassroomApi().queryClassrooms(1, day).map { it.d.list.values.sumOf { rooms -> rooms.size } }
            else -> error("Unknown operation")
          }
          assertTrue(result.isSuccess, "$mode $operation: ${result.exceptionOrNull()}")
          cases += buildJsonObject { put("id", "${mode.storageKey}-$operation"); put("count", result.getOrThrow()); put("requests", JsonArray(requests)); values?.let { put("values", it) } }
        }
      }
      File(System.getenv("GINKGO_REFERENCE_WIRE")).writeText(buildJsonObject { put("day", day); put("source", "synthetic"); put("cases", JsonArray(cases)) }.toString())
    } finally {
      LocalUpstreamClientProvider.reset()
      ConnectionRuntime.clearSelectedMode()
      localConnectionTestMutex.unlock()
    }
  }
}
