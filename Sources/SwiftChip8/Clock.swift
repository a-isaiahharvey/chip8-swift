import Foundation

public struct Clock {
  public let timerFrequencyHz = 64.0

  public var delayTimer: UInt8
  public var soundTimer: UInt8
  public var vblankInterrupt: Bool
  public var lastDelay: Date

  @available(macOS 12, *)
  public init() {
    self.delayTimer = 0
    self.soundTimer = 0
    self.vblankInterrupt = false
    self.lastDelay = Date.now
  }

  public mutating func update() {
    let elapsedTime = self.lastDelay.timeIntervalSinceNow

    if elapsedTime >= 1.0 / self.timerFrequencyHz {
      self.delayTimer = max(self.delayTimer - 1, 0)
      self.soundTimer = max(self.soundTimer - 1, 0)
      self.vblankInterrupt = true
      self.lastDelay = Date(timeIntervalSinceNow: 1.0 / self.timerFrequencyHz)
    } else {
      self.vblankInterrupt = false
    }
  }
}
