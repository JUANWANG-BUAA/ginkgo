import Foundation

enum CgyyCrypto {
  static func aesECBEncrypt(_ text: String, key: String) throws -> String {
    let keyBytes = Array(key.utf8)
    guard [16, 24, 32].contains(keyBytes.count) else {
      throw CgyyError.captcha("验证码密钥长度异常")
    }
    guard let encrypted = AESCipher.encrypt(Data(text.utf8), key: keyBytes, mode: .ecb) else {
      throw CgyyError.captcha("AES 加密失败")
    }
    return encrypted.base64EncodedString()
  }

  static func captchaVerification(token: String, pointJSON: String, secretKey: String) throws -> String {
    try aesECBEncrypt("\(token)---\(pointJSON)", key: secretKey)
  }

  static func encryptedPointJSON(_ pointJSON: String, secretKey: String) throws -> String {
    try aesECBEncrypt(pointJSON, key: secretKey)
  }
}
