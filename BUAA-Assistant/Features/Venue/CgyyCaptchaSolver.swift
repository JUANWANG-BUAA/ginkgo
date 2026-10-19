import CoreGraphics
import Foundation
import ImageIO

/// 移植自 UBAA 的滑块验证码图像匹配：对背景和拼图做灰度边缘匹配，
/// 取最佳水平偏移。用户已在会话中明确同意使用自动识别。
enum CgyyCaptchaSolver {
  static func solve(backgroundBase64: String, jigsawBase64: String) throws -> CgyyCaptchaSolution {
    let background = try decode(backgroundBase64, label: "背景图")
    let jigsaw = try decode(jigsawBase64, label: "拼图")
    let offset = try solveOffset(background: background, jigsaw: jigsaw)
    return CgyyCaptchaSolution(offset: offset, pointJSON: "{\"x\":\(offset),\"y\":5}")
  }

  private static func solveOffset(background: CgyyImage, jigsaw: CgyyImage) throws -> Int {
    let backgroundGray = gray(background)
    let jigsawGray = gray(jigsaw)
    let mask = buildMask(jigsaw)
    guard let bounds = boundingBox(mask) else {
      throw CgyyError.captcha("拼图缺少有效掩码")
    }
    let pieceGray = crop(jigsawGray, bounds: bounds)
    let pieceMask = crop(mask, bounds: bounds)
    let backgroundEdges = edgeDetect(backgroundGray)
    let pieceEdges = edgeDetect(pieceGray)

    var bestScore = -Double.greatestFiniteMagnitude
    var bestX = 0
    let yMax = max(0, backgroundEdges.count - pieceEdges.count)
    let xMax = max(0, (backgroundEdges.first?.count ?? 0) - (pieceEdges.first?.count ?? 0))
    guard xMax > 0, yMax >= 0 else { throw CgyyError.captcha("验证码图片尺寸异常") }

    for y in 0...yMax {
      for x in 0...xMax {
        var score = 0.0
        var edgePixels = 0
        var maskPixels = 0
        for py in pieceEdges.indices {
          for px in pieceEdges[py].indices {
            guard pieceMask[py][px] else { continue }
            maskPixels += 1
            let backgroundValue = backgroundEdges[y + py][x + px]
            let pieceValue = pieceEdges[py][px]
            if pieceValue > 0 {
              edgePixels += 1
              score += backgroundValue > 0 ? 3.0 : -1.5
            } else if backgroundValue == 0 {
              score += 0.15
            }
          }
        }
        guard maskPixels > 0, edgePixels > 0 else { continue }
        score /= Double(edgePixels)
        score += Double(maskPixels) * 0.0001
        if score > bestScore {
          bestScore = score
          bestX = x
        }
      }
    }
    guard bestScore > -Double.greatestFiniteMagnitude else {
      throw CgyyError.captcha("无法定位拼图位置")
    }
    return bestX
  }

  private struct CgyyImage {
    let width: Int
    let height: Int
    let pixels: [UInt32]
  }

  private static func decode(_ base64: String, label: String) throws -> CgyyImage {
    let raw = base64.contains("base64,") ? String(base64.split(separator: ",", maxSplits: 1).last ?? "") : base64
    guard let data = Data(base64Encoded: raw, options: [.ignoreUnknownCharacters]) else {
      throw CgyyError.captcha("\(label)不是有效 Base64")
    }
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
      throw CgyyError.captcha("\(label)无法解码")
    }
    let width = image.width
    let height = image.height
    guard width > 0, height > 0 else { throw CgyyError.captcha("\(label)尺寸为空") }
    var pixels = [UInt32](repeating: 0, count: width * height)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
    let success = pixels.withUnsafeMutableBytes { buffer -> Bool in
      guard let context = CGContext(
        data: buffer.baseAddress,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
      ) else { return false }
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return true
    }
    guard success else { throw CgyyError.captcha("\(label)位图上下文创建失败") }
    return CgyyImage(width: width, height: height, pixels: pixels)
  }

  private static func gray(_ image: CgyyImage) -> [[Int]] {
    var result = [[Int]](repeating: [Int](repeating: 0, count: image.width), count: image.height)
    for y in 0..<image.height {
      for x in 0..<image.width {
        let pixel = image.pixels[y * image.width + x]
        let r = Int((pixel >> 16) & 0xff)
        let g = Int((pixel >> 8) & 0xff)
        let b = Int(pixel & 0xff)
        result[y][x] = (r * 30 + g * 59 + b * 11) / 100
      }
    }
    return result
  }

  private static func buildMask(_ image: CgyyImage) -> [[Bool]] {
    var result = [[Bool]](repeating: [Bool](repeating: false, count: image.width), count: image.height)
    for y in 0..<image.height {
      for x in 0..<image.width {
        let pixel = image.pixels[y * image.width + x]
        let alpha = Int((pixel >> 24) & 0xff)
        if alpha > 10 {
          result[y][x] = true
          continue
        }
        let r = Int((pixel >> 16) & 0xff)
        let g = Int((pixel >> 8) & 0xff)
        let b = Int(pixel & 0xff)
        let luminance = (r * 30 + g * 59 + b * 11) / 100
        result[y][x] = luminance < 250
      }
    }
    return result
  }

  private static func edgeDetect(_ gray: [[Int]]) -> [[Int]] {
    let height = gray.count
    let width = gray.first?.count ?? 0
    var result = [[Int]](repeating: [Int](repeating: 0, count: width), count: height)
    for y in 0..<height {
      for x in 0..<width {
        let center = gray[y][x]
        let right = gray[y][min(x + 1, width - 1)]
        let down = gray[min(y + 1, height - 1)][x]
        let edge = abs(center - right) + abs(center - down)
        result[y][x] = edge > 35 ? 255 : 0
      }
    }
    return result
  }

  private static func boundingBox(_ mask: [[Bool]]) -> (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
    var minX = Int.max
    var minY = Int.max
    var maxX = Int.min
    var maxY = Int.min
    for y in mask.indices {
      for x in mask[y].indices where mask[y][x] {
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x)
        maxY = max(maxY, y)
      }
    }
    guard minX != Int.max else { return nil }
    return (minX, minY, maxX, maxY)
  }

  private static func crop(_ source: [[Int]], bounds: (minX: Int, minY: Int, maxX: Int, maxY: Int)) -> [[Int]] {
    let width = bounds.maxX - bounds.minX + 1
    let height = bounds.maxY - bounds.minY + 1
    return (0..<height).map { y in
      (0..<width).map { x in source[bounds.minY + y][bounds.minX + x] }
    }
  }

  private static func crop(_ source: [[Bool]], bounds: (minX: Int, minY: Int, maxX: Int, maxY: Int)) -> [[Bool]] {
    let width = bounds.maxX - bounds.minX + 1
    let height = bounds.maxY - bounds.minY + 1
    return (0..<height).map { y in
      (0..<width).map { x in source[bounds.minY + y][bounds.minX + x] }
    }
  }
}
