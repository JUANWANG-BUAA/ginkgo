import Foundation

/// 语义化版本（支持 `v` 前缀与 `-alpha.2` 之类的预发布后缀）。
/// 用于把 App 自身版本与 GitHub Release 的 tag 做比较，判断是否有更新。
struct AppVersion: Comparable, Equatable, CustomStringConvertible {
  let major: Int
  let minor: Int
  let patch: Int
  /// 预发布标识，如 ["alpha", "2"]；空数组表示正式版本。
  let prerelease: [String]

  init?(_ raw: String) {
    var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.hasPrefix("v") || value.hasPrefix("V") { value.removeFirst() }
    if let plus = value.firstIndex(of: "+") { value = String(value[..<plus]) }
    var pre: [String] = []
    if let dash = value.firstIndex(of: "-") {
      pre = value[value.index(after: dash)...].split(separator: ".").map(String.init)
      value = String(value[..<dash])
    }
    let numbers = value.split(separator: ".").compactMap { Int($0) }
    guard numbers.count >= 2 else { return nil }
    major = numbers[0]
    minor = numbers[1]
    patch = numbers.count > 2 ? numbers[2] : 0
    prerelease = pre
  }

  var description: String {
    var value = "\(major).\(minor).\(patch)"
    if !prerelease.isEmpty { value += "-" + prerelease.joined(separator: ".") }
    return value
  }

  static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
    if lhs.major != rhs.major { return lhs.major < rhs.major }
    if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
    if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
    // 语义化版本：正式版 > 预发布版；同为预发布时逐段比较。
    switch (lhs.prerelease.isEmpty, rhs.prerelease.isEmpty) {
    case (true, true): return false
    case (true, false): return false
    case (false, true): return true
    case (false, false): return Self.comparePrerelease(lhs.prerelease, rhs.prerelease) < 0
    }
  }

  private static func comparePrerelease(_ lhs: [String], _ rhs: [String]) -> Int {
    for (left, right) in zip(lhs, rhs) {
      let leftNumber = Int(left)
      let rightNumber = Int(right)
      if let leftNumber, let rightNumber, leftNumber != rightNumber {
        return leftNumber < rightNumber ? -1 : 1
      }
      if leftNumber != nil, rightNumber == nil { return -1 }
      if leftNumber == nil, rightNumber != nil { return 1 }
      if left != right { return left < right ? -1 : 1 }
    }
    if lhs.count == rhs.count { return 0 }
    return lhs.count < rhs.count ? -1 : 1
  }
}
