import Foundation

/// 统一识别 Swift 任务取消与 URLSession 取消，避免把页面切换导致的
/// “cancelled”显示成上游服务错误。
enum RequestCancellation {
  static func isCancellation(_ error: Error) -> Bool {
    if error is CancellationError { return true }
    if let error = error as? URLError, error.code == .cancelled { return true }
    let nsError = error as NSError
    return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
  }
}
