import CommonCrypto
import Foundation

/// URL codec shared by the narrowly scoped WebVPN auth and iclass read paths.
enum WebVPNRouter {
  private static let gatewayHost = "d.buaa.edu.cn"
  private static let key = Data("wrdvpnisthebest!".utf8)

  static func wrap(_ upstreamURL: URL) throws -> URL {
    guard let upstream = URLComponents(url: upstreamURL, resolvingAgainstBaseURL: false),
          let scheme = upstream.scheme,
          let host = upstream.host else {
      throw URLError(.badURL)
    }
    guard host.caseInsensitiveCompare(gatewayHost) != .orderedSame else { return upstreamURL }

    let port = upstream.port
    let protocolPart: String
    if (scheme == "http" && (port == nil || port == 80)) || (scheme == "https" && (port == nil || port == 443)) {
      protocolPart = scheme
    } else if let port {
      protocolPart = "\(scheme)-\(port)"
    } else {
      protocolPart = scheme
    }

    let encodedHost = try encryptHost(host)
    var gateway = URLComponents()
    gateway.scheme = "https"
    gateway.host = gatewayHost
    gateway.percentEncodedPath = "/\(protocolPart)/\(encodedHost)\(upstream.percentEncodedPath)"
    gateway.percentEncodedQuery = upstream.percentEncodedQuery
    gateway.percentEncodedFragment = upstream.percentEncodedFragment
    guard let url = gateway.url else { throw URLError(.badURL) }
    return url
  }

  /// Mirrors UBAA: unknown gateway-owned URLs remain intact instead of being rejected.
  static func unwrap(_ gatewayURL: URL) -> URL? {
    guard let gateway = URLComponents(url: gatewayURL, resolvingAgainstBaseURL: false) else {
      return nil
    }
    guard gateway.host?.caseInsensitiveCompare(gatewayHost) == .orderedSame else {
      return gatewayURL
    }

    let path = gateway.percentEncodedPath
    let segments = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    guard segments.count >= 2 else { return gatewayURL }
    let protocolParts = segments[0].split(separator: "-", maxSplits: 1).map(String.init)
    guard let scheme = protocolParts.first, ["http", "https", "ws", "wss"].contains(scheme),
          let host = try? decryptHost(segments[1]) else {
      return gatewayURL
    }

    let prefix = "/\(segments[0])/\(segments[1])"
    let remainder = String(path.dropFirst(prefix.count))
    var upstream = URLComponents()
    upstream.scheme = scheme
    upstream.host = host
    if protocolParts.count == 2 {
      guard let port = Int(protocolParts[1]), (1...65535).contains(port) else { return gatewayURL }
      upstream.port = port
    }
    upstream.percentEncodedPath = remainder
    upstream.percentEncodedQuery = gateway.percentEncodedQuery
    upstream.percentEncodedFragment = gateway.percentEncodedFragment
    return upstream.url ?? gatewayURL
  }

  static func isGatewayURL(_ url: URL?) -> Bool {
    url?.host?.caseInsensitiveCompare(gatewayHost) == .orderedSame
  }

  static func resolveRedirect(_ location: String, relativeTo upstreamURL: URL) -> URL? {
    let target = location.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !target.isEmpty else { return nil }

    if let absoluteURL = URL(string: target), absoluteURL.scheme != nil {
      return unwrap(absoluteURL)
    }
    if ["/https/", "/http/", "/https-", "/http-", "/wss/", "/ws/", "/wss-", "/ws-"]
      .contains(where: target.hasPrefix) {
      guard let gatewayURL = URL(string: "https://\(gatewayHost)\(target)") else { return nil }
      return unwrap(gatewayURL)
    }
    return URL(string: target, relativeTo: upstreamURL)?.absoluteURL
  }

  private static func encryptHost(_ host: String) throws -> String {
    var plaintext = Data(host.utf8)
    plaintext.append(Data(repeating: 0, count: (16 - plaintext.count % 16) % 16))
    let encrypted = try crypt(plaintext, operation: CCOperation(kCCEncrypt), iv: key)
    return key.hexString + encrypted.prefix(host.utf8.count).hexString
  }

  private static func decryptHost(_ encodedHost: String) throws -> String {
    guard encodedHost.count >= 32, let iv = Data(hex: String(encodedHost.prefix(32))) else {
      throw URLError(.badServerResponse)
    }
    let cipherHex = String(encodedHost.dropFirst(32))
    guard let ciphertext = Data(hex: cipherHex) else { throw URLError(.badServerResponse) }
    let plaintext = try crypt(ciphertext, operation: CCOperation(kCCDecrypt), iv: iv)
    let hostLength = encodedHost.count / 2 - 16
    guard hostLength > 0, plaintext.count >= hostLength,
          let host = String(data: plaintext.prefix(hostLength), encoding: .utf8), !host.isEmpty else {
      throw URLError(.badServerResponse)
    }
    return host
  }

  private static func crypt(_ input: Data, operation: CCOperation, iv: Data) throws -> Data {
    var cryptor: CCCryptorRef?
    let createStatus = key.withUnsafeBytes { keyBytes in
      iv.withUnsafeBytes { ivBytes in
        CCCryptorCreateWithMode(
          operation,
          CCMode(kCCModeCFB),
          CCAlgorithm(kCCAlgorithmAES),
          CCPadding(ccNoPadding),
          ivBytes.baseAddress,
          keyBytes.baseAddress,
          key.count,
          nil,
          0,
          0,
          CCModeOptions(0),
          &cryptor
        )
      }
    }
    guard createStatus == kCCSuccess, let cryptor else { throw URLError(.badServerResponse) }
    defer { CCCryptorRelease(cryptor) }

    var output = Data(count: input.count + kCCBlockSizeAES128)
    let outputCapacity = output.count
    var updateLength: size_t = 0
    let updateStatus = input.withUnsafeBytes { inputBytes in
      output.withUnsafeMutableBytes { outputBytes in
        CCCryptorUpdate(cryptor, inputBytes.baseAddress, input.count, outputBytes.baseAddress, outputCapacity, &updateLength)
      }
    }
    guard updateStatus == kCCSuccess else { throw URLError(.badServerResponse) }

    var finalLength: size_t = 0
    let finalStatus = output.withUnsafeMutableBytes { outputBytes in
      CCCryptorFinal(
        cryptor,
        outputBytes.baseAddress?.advanced(by: Int(updateLength)),
        outputCapacity - Int(updateLength),
        &finalLength
      )
    }
    guard finalStatus == kCCSuccess else { throw URLError(.badServerResponse) }
    output.count = Int(updateLength + finalLength)
    return output
  }
}

private extension Data {
  var hexString: String {
    map { String(format: "%02x", $0) }.joined()
  }

  init?(hex: String) {
    guard hex.count.isMultiple(of: 2) else { return nil }
    var result = Data()
    result.reserveCapacity(hex.count / 2)
    var index = hex.startIndex
    while index < hex.endIndex {
      let next = hex.index(index, offsetBy: 2)
      guard let byte = UInt8(hex[index..<next], radix: 16) else { return nil }
      result.append(byte)
      index = next
    }
    self = result
  }
}
