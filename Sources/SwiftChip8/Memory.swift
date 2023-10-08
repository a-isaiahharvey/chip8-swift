import Foundation

public struct Memory {
  static let size = 4096
  static let interpreterSize = 512

  static let font: [UInt8] = [
    0xF0, 0x90, 0x90, 0x90, 0xF0,  // 0
    0x20, 0x60, 0x20, 0x20, 0x70,  // 1
    0xF0, 0x10, 0xF0, 0x80, 0xF0,  // 2
    0xF0, 0x10, 0xF0, 0x10, 0xF0,  // 3
    0x90, 0x90, 0xF0, 0x10, 0x10,  // 4
    0xF0, 0x80, 0xF0, 0x10, 0xF0,  // 5
    0xF0, 0x80, 0xF0, 0x90, 0xF0,  // 6
    0xF0, 0x10, 0x20, 0x40, 0x40,  // 7
    0xF0, 0x90, 0xF0, 0x90, 0xF0,  // 8
    0xF0, 0x90, 0xF0, 0x10, 0xF0,  // 9
    0xF0, 0x90, 0xF0, 0x90, 0x90,  // A
    0xE0, 0x90, 0xE0, 0x90, 0xE0,  // B
    0xF0, 0x80, 0x80, 0x80, 0xF0,  // C
    0xE0, 0x90, 0x90, 0x90, 0xE0,  // D
    0xF0, 0x80, 0xF0, 0x80, 0xF0,  // E
    0xF0, 0x80, 0xF0, 0x80, 0x80,  // F
  ]

  var memory: [UInt8]

  public init() {
    self.memory = Array(Memory.font[0..<80])
  }

  public mutating func loadRom(data: [UInt8]) {
    var data = data
    data.resize(
      to: Memory.size - Memory.interpreterSize,
      { _ in
        return 0
      })
    self.memory.replaceSubrange(Memory.interpreterSize...0xFFF, with: data)
  }

  public subscript(position: Int) -> UInt8 {
    get {
      self.memory[position]
    }
    set(newValue) {
      self.memory[position] = newValue
    }
  }
}

extension Array {
  mutating func resize(to newSize: Int, _ appending: ((Int) -> Element)) {
    assert(newSize >= 0, "newSize must be a non-negative number")
    if newSize < self.count {
      self = Array(self[0..<newSize])
    } else if newSize > count {
      let needed = newSize - count
      for i in endIndex..<endIndex + needed {
        self.append(appending(i))
      }
    }
  }
}
