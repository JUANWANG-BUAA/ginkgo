import CryptoKit
import Foundation

enum CgyySigner {
  static let appKey = "8fceb735082b5a529312040b58ea780b"
  private static let prefix = "c640ca392cd45fb3a55b00a63a86c618"
  private static let removeKeys: Set<String> = [
    "gmtCreate", "gmtModified", "creator", "modifier", "id", "_index", "_rowKey"
  ]

  static func sign(path: String, parameters: [String: String], timestamp: Int64) -> String {
    let normalizedPath = path.hasPrefix("/") ? path : "/" + path
    var payload = prefix + normalizedPath
    for key in parameters.keys.sorted() where removeKeys.contains(key) == false {
      guard let value = parameters[key], value.isEmpty == false else { continue }
      payload += key + value
    }
    payload += String(timestamp) + " " + prefix
    return Insecure.MD5.hash(data: Data(payload.utf8))
      .map { String(format: "%02x", $0) }
      .joined()
  }

  static func withNoCache(_ parameters: [String: String], timestamp: Int64) -> [String: String] {
    guard parameters["nocache"] == nil else { return parameters }
    var result = parameters
    result["nocache"] = String(timestamp)
    return result
  }
}
