import Network
import SwiftUI

/// Reports reachability changes as refresh hints. A satisfied path does not
/// guarantee that a particular school service is available.
final class NetworkPathObserver: ObservableObject {
  @Published private(set) var isConnected: Bool?

  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "Ginkgo.network-path")

  init() {
    monitor.pathUpdateHandler = { [weak self] path in
      let isSatisfied = path.status == .satisfied
      DispatchQueue.main.async {
        guard let self else { return }
        self.isConnected = isSatisfied
      }
    }
    monitor.start(queue: queue)
  }

  deinit {
    monitor.cancel()
  }
}
