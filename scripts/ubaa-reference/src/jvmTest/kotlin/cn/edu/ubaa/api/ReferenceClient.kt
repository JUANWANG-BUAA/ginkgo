package cn.edu.ubaa.api

import io.ktor.client.HttpClient
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.plugins.cookies.CookiesStorage
import io.ktor.client.request.HttpRequestData
import io.ktor.http.content.OutgoingContent
import io.ktor.http.content.TextContent
import kotlinx.serialization.json.*

/** Invoke the pinned private factory unchanged; substitute only its engine/storage. */
internal fun referenceClient(
    engine: HttpClientEngine,
    redirects: Boolean,
    storage: CookiesStorage,
): HttpClient {
  val factory = Class.forName("cn.edu.ubaa.api.local.LocalConnectionAuthKt").getDeclaredMethod(
      "buildLocalUpstreamClient",
      java.lang.Boolean.TYPE,
      CookiesStorage::class.java,
      HttpClientEngine::class.java,
  )
  factory.isAccessible = true
  return factory.invoke(null, redirects, storage, engine) as HttpClient
}

internal fun HttpRequestData.wireValue(): JsonObject {
  val text = when (val content = body) {
    is TextContent -> content.text
    is OutgoingContent.ByteArrayContent -> content.bytes().decodeToString()
    is OutgoingContent.NoContent -> ""
    else -> error("Unsupported synthetic request body")
  }
  val fields = headers.entries().associate { it.key.lowercase() to it.value.joinToString(", ") }.toMutableMap()
  body.contentType?.let { fields.putIfAbsent("content-type", it.toString()) }
  return buildJsonObject {
    put("method", method.value); put("url", url.toString()); put("body", text)
    put("headers", buildJsonObject { fields.forEach { (key, value) -> put(key, value) } })
  }
}
