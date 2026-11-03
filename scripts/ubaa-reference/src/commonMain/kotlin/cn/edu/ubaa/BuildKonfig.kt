package cn.edu.ubaa

// The reference build has no server endpoint; all upstream traffic must use MockEngine.
object BuildKonfig {
  const val VERSION = "offline-reference"
  const val API_ENDPOINT = "https://invalid.invalid"
}
