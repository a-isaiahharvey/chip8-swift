import Foundation

public struct Bus {
  public var clock: Clock
  public var graphics: Graphics.Buffer
  public var input: Input
  public var memory: Memory

  @available(macOS 12, *)
  public init() {
    self.clock = Clock()
    self.graphics = Graphics.Buffer()
    self.input = Input()
    self.memory = Memory()
  }
}

public struct Chip8 {
  public var processor: Cpu
  public var bus: Bus

  @available(macOS 12, *)
  public init() {
    self.processor = Cpu()
    self.bus = Bus()
  }

  public mutating func step() {
    self.bus.clock.update()
    self.processor.cycle(&self.bus)
  }

  public mutating func loadRom(data: [UInt8]) {
    self.bus.memory.loadRom(data: data)
  }

  public mutating func updateKeyState(_ keyCode: UInt8, _ pressed: Bool) {
    self.bus.input.update(keyCode, pressed)
  }

  @available(macOS 12, *)
  public mutating func reset() {
    self.bus.graphics.clear()
    let graphics = self.bus.graphics
    self.bus = Bus()
    self.bus.graphics = graphics

    let shiftQuirkEnabled = self.processor.shiftQuirkEnabled
    let vblankWait = self.processor.vblankWait
    self.processor = Cpu()
    self.processor.shiftQuirkEnabled = shiftQuirkEnabled
    self.processor.vblankWait = vblankWait
  }

  @available(macOS 12, *)
  public mutating func resetAndLoad(data: [UInt8]) {
    self.reset()
    self.loadRom(data: data)
  }
}
