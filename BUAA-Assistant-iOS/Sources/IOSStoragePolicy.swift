import Foundation

/// School queries, grades, library data and check-in snapshots live in
/// Application Support. Excluding the root directory from device backups keeps
/// those local-only snapshots out of iCloud backups while leaving the Keychain
/// credential policy unchanged (WhenUnlockedThisDeviceOnly). Personal tasks
/// still use UserDefaults and need a future unified storage migration.
enum IOSStoragePolicy {
  static func excludeSensitiveCachesFromBackup() {
    let fileManager = FileManager.default
    guard let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
      return
    }
    do {
      try fileManager.createDirectory(at: support, withIntermediateDirectories: true)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      var mutableSupport = support
      try mutableSupport.setResourceValues(values)
    } catch {
      AppLog.cacheWriteFailed(feature: "ios-backup-exclusion", error: error)
    }
  }
}
