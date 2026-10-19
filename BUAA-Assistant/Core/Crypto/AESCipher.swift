import CommonCrypto
import Foundation

/// CommonCrypto AES 的一次性加解密。各上游的模式、填充与密钥规则不同（见 API.md 对应章节），
/// 由调用方显式指定；失败（如密钥长度不合法）返回 nil，由调用方映射为自己的业务错误。
enum AESCipher {
  enum Mode {
    case ecb
    case cbc(iv: [UInt8])
  }

  static func encrypt(_ data: Data, key: [UInt8], mode: Mode, pkcs7Padding: Bool = true) -> Data? {
    crypt(CCOperation(kCCEncrypt), data, key: key, mode: mode, pkcs7Padding: pkcs7Padding)
  }

  static func decrypt(_ data: Data, key: [UInt8], mode: Mode, pkcs7Padding: Bool = true) -> Data? {
    crypt(CCOperation(kCCDecrypt), data, key: key, mode: mode, pkcs7Padding: pkcs7Padding)
  }

  private static func crypt(
    _ operation: CCOperation,
    _ data: Data,
    key: [UInt8],
    mode: Mode,
    pkcs7Padding: Bool
  ) -> Data? {
    var options = pkcs7Padding ? CCOptions(kCCOptionPKCS7Padding) : 0
    var iv: [UInt8]?
    switch mode {
    case .ecb: options |= CCOptions(kCCOptionECBMode)
    case .cbc(let vector): iv = vector
    }
    var output = Data(count: data.count + kCCBlockSizeAES128)
    let capacity = output.count
    var length = 0
    let status = output.withUnsafeMutableBytes { outputBytes in
      data.withUnsafeBytes { inputBytes in
        func run(_ ivPointer: UnsafeRawPointer?) -> CCCryptorStatus {
          CCCrypt(
            operation, CCAlgorithm(kCCAlgorithmAES), options,
            key, key.count, ivPointer,
            inputBytes.baseAddress, data.count,
            outputBytes.baseAddress, capacity, &length
          )
        }
        guard let iv else { return run(nil) }
        return iv.withUnsafeBytes { run($0.baseAddress) }
      }
    }
    guard status == kCCSuccess else {
      AppLog.network.error("AES operation failed status=\(status)")
      return nil
    }
    return output.prefix(length)
  }
}
