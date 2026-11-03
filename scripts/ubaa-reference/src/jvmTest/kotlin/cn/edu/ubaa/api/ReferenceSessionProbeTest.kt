package cn.edu.ubaa.api

import cn.edu.ubaa.api.auth.LoginStatsReporter
import cn.edu.ubaa.api.local.LocalAuthServiceBackend
import cn.edu.ubaa.api.local.LocalAuthSessionStore
import cn.edu.ubaa.api.local.LocalCookieStore
import cn.edu.ubaa.api.local.LocalUpstreamClientProvider
import cn.edu.ubaa.api.local.LocalWebVpnSupport
import com.russhwolf.settings.MapSettings
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import io.ktor.utils.io.ByteReadChannel
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.*
import java.io.File

class ReferenceSessionProbeTest {
  private val requests = mutableListOf<String>()
  private var callbackSeen = false
  private val rawRequests = mutableListOf<JsonElement>()

  @BeforeTest
  fun setup() {
    runTest { localConnectionTestMutex.lock() }
    ConnectionModeStore.settings = MapSettings()
    LocalAuthSessionStore.settings = MapSettings()
    LocalCookieStore.settings = MapSettings()
    ConnectionRuntime.clearSelectedMode()
    LocalUpstreamClientProvider.reset()
    LoginStatsReporter.reporter = { }
    requests.clear()
    rawRequests.clear()
    callbackSeen = false
  }

  @AfterTest
  fun teardown() {
    LoginStatsReporter.reset()
    LocalUpstreamClientProvider.reset()
    ConnectionRuntime.clearSelectedMode()
    localConnectionTestMutex.unlock()
  }

  @Test
  fun ticket() = runTest {
    install(ConnectionMode.DIRECT, ucUnavailable = false)
    val result = LocalAuthServiceBackend().login("sy2501001", "synthetic", null, null)
    println("ORACLE ticket result=${if (result.isSuccess) "SignedIn" else "Error"} requests=$requests")
    assertTrue(result.isSuccess)
    assertEquals(listOf("CAS_GET:direct", "CAS_POST:direct", "CALLBACK:direct", "UC_ACTIVATE:direct", "UC_STATUS:direct"), requests)
    saveWire("ticket")
  }

  @Test
  fun ucUnavailable() = runTest {
    install(ConnectionMode.DIRECT, ucUnavailable = true)
    val result = LocalAuthServiceBackend().login("sy2501001", "synthetic", null, null)
    println("ORACLE uc_unavailable result=${if (result.isSuccess) "SignedIn" else "Error"} requests=$requests")
    assertTrue(result.isFailure)
    assertEquals(listOf("CAS_GET:direct", "CAS_POST:direct", "UC_ACTIVATE:direct", "UC_STATUS:direct"), requests)
    saveWire("uc_unavailable")
  }

  @Test
  fun webvpnAlsoSubmitsDirectCredentials() = runTest {
    install(ConnectionMode.WEBVPN, ucUnavailable = false)
    val result = LocalAuthServiceBackend().login("sy2501001", "synthetic", null, null)
    println("ORACLE webvpn result=${if (result.isSuccess) "SignedIn" else "Error"} requests=$requests")
    assertTrue(result.isSuccess)
    assertEquals(2, requests.count { it.startsWith("CAS_POST:") })
    assertTrue(requests.contains("CAS_POST:direct"))
    assertEquals("CALLBACK:vpn", requests[requests.indexOf("CAS_POST:direct") + 1])
    saveWire("webvpn")
  }

  private fun install(mode: ConnectionMode, ucUnavailable: Boolean) {
    ConnectionModeStore.save(mode)
    ConnectionRuntime.resolveSelectedMode()
    val engine = MockEngine { request ->
      rawRequests += request.wireValue()
      val rawUrl = request.url.toString()
      val original = LocalWebVpnSupport.fromWebVpnUrl(rawUrl)
      val route = if (rawUrl == original) "direct" else "vpn"
      val stage = when {
        original == "https://sso.buaa.edu.cn/login" && request.method.value == "GET" -> "CAS_GET"
        original == "https://sso.buaa.edu.cn/login" && request.method.value == "POST" -> "CAS_POST"
        original == "https://uc.buaa.edu.cn/api/callback?ticket=ST-synthetic" -> "CALLBACK"
        original.startsWith("https://uc.buaa.edu.cn/api/login?") -> "UC_ACTIVATE"
        original == "https://uc.buaa.edu.cn/api/uc/status" -> "UC_STATUS"
        else -> error("Unexpected synthetic request: $original")
      }
      requests += "$stage:$route"
      when (stage) {
        "CAS_GET" -> respond(
            ByteReadChannel("""<html><body><form action="/login" method="post"><input type="hidden" name="execution" value="abc+def/ghi=" /><input type="text" name="username" /><input type="password" name="password" /></form></body></html>"""),
            HttpStatusCode.OK,
            headersOf(
                HttpHeaders.ContentType to listOf("text/html"),
                HttpHeaders.SetCookie to listOf(if (route == "vpn") "wengine_vpn_ticket=synthetic; Path=/; Secure" else "CASTGC=synthetic; Path=/; Secure"),
            ),
        )
        "CAS_POST" -> if (ucUnavailable) {
          respond(ByteReadChannel("ok"), HttpStatusCode.OK)
        } else {
          respond(
              ByteReadChannel.Empty,
              HttpStatusCode.Found,
              headersOf(HttpHeaders.Location, "https://uc.buaa.edu.cn/api/callback?ticket=ST-synthetic"),
          )
        }
        "CALLBACK" -> { callbackSeen = true; respond(ByteReadChannel.Empty, HttpStatusCode.OK) }
        "UC_ACTIVATE" -> respond(ByteReadChannel.Empty, HttpStatusCode.OK)
        "UC_STATUS" -> {
          val body = if (ucUnavailable) "unavailable" else if (!callbackSeen) """{"code":10600,"data":null}""" else """{"code":0,"data":{"schoolid":"sy2501001","name":"fixture"}}"""
          respond(ByteReadChannel(body), if (ucUnavailable) HttpStatusCode.ServiceUnavailable else HttpStatusCode.OK, headersOf(HttpHeaders.ContentType, "application/json"))
        }
        else -> error("Unexpected stage")
      }
    }
    LocalUpstreamClientProvider.clientFactory = { followRedirects ->
      referenceClient(engine, followRedirects, LocalCookieStore.storage(mode))
    }
    LocalUpstreamClientProvider.isolatedClientFactory = { followRedirects, storage ->
      referenceClient(engine, followRedirects, storage)
    }
  }

  private fun saveWire(name: String) {
    val file = File(System.getenv("GINKGO_REFERENCE_AUTH_WIRE"))
    val cases = if (file.exists()) Json.parseToJsonElement(file.readText()).jsonObject.toMutableMap() else mutableMapOf()
    check(name !in cases) { "Duplicate authentication capture" }
    cases[name] = JsonArray(rawRequests)
    file.writeText(JsonObject(cases).toString())
  }
}
