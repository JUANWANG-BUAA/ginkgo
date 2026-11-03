package cn.edu.ubaa.api

import cn.edu.ubaa.api.core.getDefaultEngine
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.engine.okhttp.OkHttp
import cn.edu.ubaa.api.local.LocalCookieStore
import com.russhwolf.settings.MapSettings
import io.ktor.client.call.body
import io.ktor.client.request.request
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.HttpMethod
import io.ktor.http.content.TextContent
import java.io.File
import java.net.InetAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.Base64
import java.util.concurrent.CompletableFuture
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.*

/** Real pinned CIO + original client factory + original persistent cookie store. */
class ReferenceTransportProbeTest {
  private fun readRequest(socket: Socket): JsonObject {
    socket.soTimeout = 5000
    val input = socket.getInputStream().buffered()
    val header = StringBuilder()
    while (!header.endsWith("\r\n\r\n")) {
      val next = input.read()
      check(next >= 0 && header.length < 65536)
      header.append(next.toChar())
    }
    val lines = header.toString().trimEnd().split("\r\n")
    val first = lines.first().split(' ')
    val headers = linkedMapOf<String, String>()
    lines.drop(1).forEach {
      val key = it.substringBefore(':').lowercase()
      val value = it.substringAfter(':').trim()
      headers[key] = headers[key]?.let { old -> "$old, $value" } ?: value
    }
    val length = headers["content-length"]?.toInt() ?: 0
    check(length in 0..65536)
    val body = input.readNBytes(length)
    check(body.size == length)
    return buildJsonObject {
      put("method", first[0]); put("target", first[1]); put("version", first[2])
      put("headers", buildJsonObject { headers.forEach { (key, value) -> put(key, value) } })
      put("body_base64", Base64.getEncoder().encodeToString(body))
    }
  }

  @Test
  fun captureRealLoopbackTransport() = capture(getDefaultEngine(), "GINKGO_TRANSPORT_KTOR_WIRE", "CIO")

  @Test
  fun captureAndroidOkHttpOnJvm() = capture(OkHttp.create(), "GINKGO_TRANSPORT_OKHTTP_WIRE", "OkHttp-on-JVM")

  private fun capture(engine: HttpClientEngine, output: String, label: String) = runBlocking {
    localConnectionTestMutex.lock()
    try {
      LocalCookieStore.settings = MapSettings()
      val fixture = Json.parseToJsonElement(File(System.getenv("GINKGO_TRANSPORT_CASES")).readText()).jsonObject
      val cases = fixture.getValue("cases").jsonArray
      val listener = ServerSocket(0, 50, InetAddress.getByName("127.0.0.1"))
      listener.soTimeout = 5000
      val base = "http://127.0.0.1:${listener.localPort}"
      val server = CompletableFuture.supplyAsync {
        listener.use {
          cases.map { item ->
            val case = item.jsonObject
            listener.accept().use { socket ->
              val request = readRequest(socket)
              assertEquals(case.getValue("method"), request.getValue("method"))
              assertEquals(case.getValue("path"), request.getValue("target"))
              val response = case.getValue("response").jsonObject
              val bytes = response["base64"]?.jsonPrimitive?.content?.let { Base64.getDecoder().decode(it) }
                  ?: response.getValue("body").jsonPrimitive.content.toByteArray(Charsets.UTF_8)
              val head = buildString {
                append("HTTP/1.1 ${response.getValue("status").jsonPrimitive.int} Synthetic\r\n")
                append("Content-Length: ${bytes.size}\r\nConnection: close\r\nContent-Type: text/plain; charset=utf-8\r\n")
                response.getValue("headers").jsonArray.forEach { pair ->
                  append("${pair.jsonArray[0].jsonPrimitive.content}: ${pair.jsonArray[1].jsonPrimitive.content}\r\n")
                }
                append("\r\n")
              }
              socket.getOutputStream().write(head.toByteArray(Charsets.US_ASCII))
              socket.getOutputStream().write(bytes)
              buildJsonObject { put("id", case.getValue("id")); put("request", request) }
            }
          }
        }
      }
      val client = referenceClient(engine, false, LocalCookieStore.storage(ConnectionMode.DIRECT))
      val results = try {
        cases.map { item ->
          val case = item.jsonObject
          val response = client.request("$base${case.getValue("path").jsonPrimitive.content}") {
            method = HttpMethod.parse(case.getValue("method").jsonPrimitive.content)
            case.getValue("headers").jsonObject.forEach { (key, value) -> headers.append(key, value.jsonPrimitive.content) }
            if (method == HttpMethod.Post) {
              setBody(TextContent(case.getValue("body").jsonPrimitive.content,
                  ContentType.parse(case.getValue("headers").jsonObject.getValue("Content-Type").jsonPrimitive.content)))
            }
          }
          val bytes = response.body<ByteArray>()
          assertEquals(case.getValue("response").jsonObject.getValue("status").jsonPrimitive.int, response.status.value)
          buildJsonObject {
            put("id", case.getValue("id")); put("status", response.status.value)
            put("body_base64", Base64.getEncoder().encodeToString(bytes))
            put("location", response.headers["Location"]?.let(::JsonPrimitive) ?: JsonNull)
            put("set_cookies", JsonArray(response.headers.getAll("Set-Cookie").orEmpty().map(::JsonPrimitive)))
          }
        }
      } finally { client.close() }
      val captured = server.get(10, java.util.concurrent.TimeUnit.SECONDS)
      File(System.getenv(output)).writeText(buildJsonObject {
        put("source", "synthetic"); put("engine", label); put("requests", JsonArray(captured)); put("results", JsonArray(results))
      }.toString())
    } finally { localConnectionTestMutex.unlock() }
  }
}
