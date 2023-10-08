import Foundation

public struct Graphics {
  public static let height = 32
  public static let width = 64
  public static let pixelCount = width * height

  public static let defaultForeground = Rgb(red: 255, green: 255, blue: 255)
  public static let defaultBackground = Rgb(red: 0, green: 0, blue: 0)

  public struct Rgb: Equatable {
    public var red: UInt8
    public var green: UInt8
    public var blue: UInt8

    public func asArray() -> [UInt8] {
      [self.red, self.green, self.blue]
    }

    public static func fromArray(array: [UInt8]) -> Rgb {
      Rgb(red: array[0], green: array[1], blue: array[2])
    }
  }

  public struct Buffer {
    var vram: [Rgb]
    public var foregroundRgb: Rgb
    public var backgroundRgb: Rgb

    public init() {
      self.vram = Array.init(repeating: defaultBackground, count: pixelCount)
      self.foregroundRgb = defaultForeground
      self.backgroundRgb = defaultBackground
    }

    public mutating func drawByte(_ x: Int, _ y: Int, _ data: UInt8) -> Bool {
      if y >= pixelCount / width {
        return false
      }

      let maxX = min(width - x, 8)
      let bitmasks: [UInt8] = [0x80, 0x40, 0x20, 0x10, 0x08, 0x04, 0x02, 0x01]

      var collision = false

      for (b, mask) in bitmasks.enumerated().prefix(maxX) {
        let pos = (width * y) + x + b
        let newPixelActive = (data & mask) != 0
        let oldPixelActive = self.vram[pos] == self.foregroundRgb
        if newPixelActive && oldPixelActive {
          collision = true
        }
        self.vram[pos] =
          if newPixelActive || oldPixelActive {
            self.foregroundRgb
          } else {
            self.backgroundRgb
          }
      }

      return collision
    }

    public mutating func setForegroundColor(foreground: Rgb) {
      let oldColor = self.foregroundRgb
      self.foregroundRgb = foreground

      for index in self.vram.indices where self.vram[index] == oldColor {
        self.vram[index] = foreground
      }
    }

    public mutating func setBackgroundColor(background: Rgb) {
      let oldColor = self.backgroundRgb
      self.backgroundRgb = background

      for index in self.vram.indices where self.vram[index] == oldColor {
        self.vram[index] = background
      }
    }

    public func asRgb() -> [UInt8] {
      var data: [UInt8] = Array.init(repeating: 0, count: pixelCount * 3)

      for (i, pixel) in self.vram.enumerated() {
        let offset = i * 3
        data[offset] = pixel.red
        data[offset + 1] = pixel.green
        data[offset + 2] = pixel.blue
      }

      return data
    }

    public mutating func clear() {
      self.vram = Array.init(repeating: self.backgroundRgb, count: pixelCount)
    }
  }
}
