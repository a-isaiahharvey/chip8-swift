import Foundation

public struct Cpu {
  let instructionBufferLength = 100
  let startingPc = 0x200

  enum ProgramCounterUpdate {
    case next
    case skipNext
    case jump(Int)
  }

  public struct Instruction {
    public var address: Int
    public var opcode: Int
    public var display: String
  }

  public var v: [UInt8]
  public var i: Int
  public var pc: Int
  public var sp: Int
  public var stack: [UInt]
  public var shiftQuirkEnabled: Bool
  public var vblankWait: Bool
  public var display: String
  public var instructions: [Instruction]

  init() {
    self.pc = self.startingPc
    self.sp = 0
    self.v = Array(repeating: 0, count: 16)
    self.i = 0
    self.stack = Array(repeating: 0, count: 16)
    self.shiftQuirkEnabled = false
    self.vblankWait = false
    self.display = ""
    self.instructions = []
  }

  public mutating func cycle(_ bus: inout Bus) {
    if bus.input.waiting {
      return
    } else if let request = bus.input.requestResponse {
      self.v[Int(request.register)] = request.keyCode
    }

    if self.pc >= 4096 {
      return
    }

    let opcode = Int(bus.memory[self.pc] << 8) | Int(bus.memory[self.pc + 1])

    let (pcUpdate, display) = self.process(opcode: opcode, &bus)

    let instruction = Instruction(address: self.pc, opcode: opcode, display: display)
    self.push(instruction: instruction)

    switch pcUpdate {
    case .next:
      self.pc += 2
    case .skipNext:
      self.pc += 4
    case .jump(let addr):
      self.pc = addr
    }
  }

  mutating func push(instruction: Instruction) {
    self.instructions.insert(instruction, at: 0)
    if self.instructions.count > instructionBufferLength {
      let _ = self.instructions.popLast()
    }
  }

  mutating func process(opcode: Int, _ bus: inout Bus) -> (ProgramCounterUpdate, String) {
    let x = (opcode & 0x0F00) >> 8
    let y = (opcode & 0x00F0) >> 4
    let nn = UInt8(opcode & 0x00FF)
    let nnn = opcode & 0x0FFF

    switch (opcode & 0xF000) >> 12 {
    // 0___
    case 0x0:
      switch opcode & 0x000F {
      // 00E0
      case 0x0000: return self.op00e0(&bus)

      // 00EE
      case 0x000E: return self.op00ee()

      // invalid
      default:
        print("Invalid 0x0___ instruction: \(String(format: "%X", opcode))")
        let display = "Invalid Instruction"
        return (ProgramCounterUpdate.next, display)
      }

    // 1nnn
    case 0x1: return self.op1nnn(nnn)

    // 2nnn
    case 0x2: return self.op2nnn(nnn)

    // 3xnn
    case 0x3: return self.op3xnn(x, nn)

    // 4Xnn
    case 0x4: return self.op4xnn(x, nn)

    // 5xy0
    case 0x5: return self.op5xy0(x, y)

    // 6xnn
    case 0x6: return self.op6xnn(x, nn)

    // 7xnn
    case 0x7: return self.op7xnn(x, nn)

    // 8___
    case 0x8:
      switch opcode & 0x000F {
      // 8xy0
      case 0x0: return self.op8xy0(x, y)

      // 8xy1
      case 0x1: return self.op8xy1(x, y)

      // 8xy2
      case 0x2: return self.op8xy2(x, y)

      // 8xy3
      case 0x3: return self.op8xy3(x, y)

      // 8xy4
      case 0x4: return self.op8xy4(x, y)

      // 8xy5
      case 0x5: return self.op8xy5(x, y)

      // 8xy6
      case 0x6: return self.op8xy6(x, y)

      // 8xy7
      case 0x7: return self.op8xy7(x, y)

      // 8xyE
      case 0xE: return self.op8xye(x, y)

      // invalid
      default:
        let display = "Invalid Instruction"
        print("Invalid 8XY_ instruction: \(String(format: "%X", opcode))")
        return (ProgramCounterUpdate.next, display)
      }

    // 9xy0
    case 9: return self.op9xy0(x, y)

    // Annn
    case 0xA: return self.opAnnn(nnn)

    // Bnnn
    case 0xB: return self.opBnnn(nnn)

    // Cxnn
    case 0xC: return self.opCxnn(x, nn)

    // Dxyn
    case 0xD: return self.opDxyn(&bus, opcode, x, y)

    // E___
    case 0xE:
      switch opcode & 0x000F {
      // Ex9E
      case 0x000E: return self.opEx9e(x, &bus)

      // ExA1
      case 0x0001: return self.opExa1(x, &bus)

      // invalid
      default:
        let display = "Invalid Instruction"
        print("Invalid EX__ instruction: \(String(format: "%X", opcode))")
        return (ProgramCounterUpdate.next, display)
      }

    // F___
    case 0xF:
      switch opcode & 0x00FF {
      // Fx07
      case 0x0007: return self.opFx07(x, &bus)

      // Fx0A
      case 0x000A: return self.opfx0a(&bus, x)

      // Fx15
      case 0x0015: return self.opFx15(x, &bus)

      // Fx18
      case 0x0018: return self.opFx18(x, &bus)

      // Fx1E
      case 0x001E: return self.opFx1e(x)

      // Fx29
      case 0x0029: return self.opFx29(x)

      // Fx33
      case 0x0033: return self.opFx33(x, &bus)

      // Fx55
      case 0x0055: return self.opFx55(x, &bus)

      // Fx65
      case 0x0065: return self.opFx65(x, &bus)

      // invalid
      default:
        let display = "Invalid Instruction"
        print("Invalid FX__ instruction: \(String(format: "%X", opcode))")
        return (ProgramCounterUpdate.next, display)
      }

    default:
      let display = "Invalid Instruction"
      print("Unknown opcode: \(String(format: "%X", opcode))")
      return (ProgramCounterUpdate.next, display)

    }
  }

  mutating func opFx65(_ x: Int, _ bus: inout Bus) -> (ProgramCounterUpdate, String) {
    let display = "Read memory at I into V0 to V\(String(format: "%X", x))"

    for i in 0...x {
      self.v[i] = bus.memory[self.i]
      self.i += 1
    }

    return (ProgramCounterUpdate.next, display)
  }

  mutating func opFx55(_ x: Int, _ bus: inout Bus) -> (ProgramCounterUpdate, String) {
    let display = "Store V0 to V\(String(format: "%X", x)) starting at I"
    for i in 0...x {
      bus.memory[self.i] = self.v[i]
      self.i += 1
    }

    return (ProgramCounterUpdate.next, display)
  }

  mutating func opFx33(_ x: Int, _ bus: inout Bus) -> (ProgramCounterUpdate, String) {
    let display = "Store BCD of \(self.v[x]) starting at I"
    bus.memory[self.i] = (self.v[x] / 100) % 10
    bus.memory[self.i + 1] = (self.v[x] / 10) % 10
    bus.memory[self.i + 2] = self.v[x] % 10

    return (ProgramCounterUpdate.next, display)
  }

  mutating func opFx29(_ x: Int) -> (ProgramCounterUpdate, String) {
    let display = "Set I to addr of sprite digit \(self.v[x])"
    self.i = 5 * Int(self.v[x])

    return (ProgramCounterUpdate.next, display)
  }

  mutating func opFx1e(_ x: Int) -> (ProgramCounterUpdate, String) {
    let display = "Set I to I + V\(String(format: "%X", x))"
    self.i += Int(self.v[x])

    return (ProgramCounterUpdate.next, display)
  }

  mutating func opFx18(_ x: Int, _ bus: inout Bus) -> (ProgramCounterUpdate, String) {
    let display = "Set sound timer to V\(String(format: "%X", x)) (\(self.v[x]))"
    bus.clock.soundTimer = UInt8(self.v[x])

    return (ProgramCounterUpdate.next, display)
  }

  mutating func opFx15(_ x: Int, _ bus: inout Bus) -> (ProgramCounterUpdate, String) {
    let display = "Set delay timer to V\(String(format: "%X", x)) (\(self.v[x]))"
    bus.clock.delayTimer = self.v[x]

    return (ProgramCounterUpdate.next, display)
  }

  mutating func opFx07(_ x: Int, _ bus: inout Bus) -> (ProgramCounterUpdate, String) {
    let display = "Set V\(String(format: "%X", x)) to delay timer \(bus.clock.delayTimer)"
    self.v[x] = bus.clock.delayTimer

    return (ProgramCounterUpdate.next, display)
  }

  mutating func opExa1(_ x: Int, _ bus: inout Bus) -> (ProgramCounterUpdate, String) {
    let notPressed = !bus.input.isKeyPressed(self.v[x])
    let display =
      "Skip next instr if key code \(String(format: "%#X", self.v[x])) not pressed (\(notPressed))"

    if notPressed {
      return (ProgramCounterUpdate.skipNext, display)
    } else {
      return (ProgramCounterUpdate.next, display)
    }

  }

  mutating func opEx9e(_ x: Int, _ bus: inout Bus) -> (ProgramCounterUpdate, String) {
    let pressed = bus.input.isKeyPressed(self.v[x])
    let display = "Skip instr if key \(String(format: "%#X", self.v[x])) pressed (\(pressed))"

    if pressed {
      return (ProgramCounterUpdate.skipNext, display)
    } else {
      return (ProgramCounterUpdate.next, display)
    }
  }

  mutating func opDxyn(_ bus: inout Bus, _ opcode: Int, _ x: Int, _ y: Int) -> (
    ProgramCounterUpdate, String
  ) {
    if self.vblankWait {
      while true {
        bus.clock.update()
        if bus.clock.vblankInterrupt {
          break
        }
      }
    }

    let n = opcode & 0xF
    let x = Int(self.v[x]) % Graphics.width
    let y = Int(self.v[y]) % Graphics.height
    let display =
      "Draw \(n) byte sprite from addr \(String(format:"%#06X", self.i)) at point (\(x), \(y))"

    var collision = false
    for i in 0..<n {
      let data = bus.memory[self.i + i]
      collision = bus.graphics.drawByte(x, y + i, data) || collision
    }

    self.v[0xF] =
      if collision {
        1
      } else {
        0
      }

    return (ProgramCounterUpdate.next, display)
  }

  mutating func opCxnn(_ x: Int, _ nn: UInt8) -> (ProgramCounterUpdate, String) {
    var buf: [UInt8] = Array.init(repeating: 0, count: 1)

    buf = buf.map({ _ in
      UInt8.random(in: UInt8.min...UInt8.max)
    })

    let display =
      "Set V\(String(format: "%X", self.v[x])) to \(buf[0]) [rand] AND \(String(format: "%#X", nn))"
    self.v[x] = buf[0] & nn

    return (ProgramCounterUpdate.next, display)
  }

  mutating func opBnnn(_ nnn: Int) -> (ProgramCounterUpdate, String) {
    let display = "Jump to \(String(format: "%#06X", nnn)) + \(String(format: "%#06X", self.v[0]))"
    return (ProgramCounterUpdate.jump(nnn + Int(self.v[0])), display)
  }

  mutating func opAnnn(_ nnn: Int) -> (ProgramCounterUpdate, String) {
    let display = "Set I register to \(String(format: "%#06X", nnn))"
    return (ProgramCounterUpdate.next, display)
  }

  mutating func op9xy0(_ x: Int, _ y: Int) -> (ProgramCounterUpdate, String) {
    let display =
      "If V\(String(format: "%X", x)) (\(self.v[x])) != V\(String(format: "%X", y)) (\(self.v[x])), skip next instr"

    if self.v[x] == self.v[y] {
      return (ProgramCounterUpdate.next, display)
    } else {
      return (ProgramCounterUpdate.skipNext, display)
    }
  }

  mutating func op8xye(_ x: Int, _ y: Int) -> (ProgramCounterUpdate, String) {
    if self.shiftQuirkEnabled {
      self.v[x] = self.v[y]
    }

    let overflow = (self.v[x] & 0x80) >> 7
    let display = "V\(String(format: "%X", x)) shifted one left, VF = \(overflow)"

    self.v[x] <<= 1
    self.v[0xF] = overflow

    return (ProgramCounterUpdate.next, display)
  }

  mutating func op8xy7(_ x: Int, _ y: Int) -> (ProgramCounterUpdate, String) {
    let (partialValue, overflow) = self.v[y].subtractingReportingOverflow(self.v[x])

    let display =
      "Set V\(String(format: "%X", x)) to (\(self.v[y]) - \(self.v[x])), VF = \(!overflow)"

    self.v[x] = partialValue
    self.v[0xF] = if !overflow { 1 } else { 0 }

    return (ProgramCounterUpdate.next, display)
  }

  mutating func op8xy6(_ x: Int, _ y: Int) -> (ProgramCounterUpdate, String) {
    if self.shiftQuirkEnabled {
      self.v[x] = self.v[y]
    }

    let overflow = self.v[x] & 1
    let display = "V\(String(format: "%x", x)) shifted one right, VF = \(overflow)"

    self.v[x] >>= 1
    self.v[0xF] = overflow

    return (ProgramCounterUpdate.next, display)
  }

  mutating func op8xy5(_ x: Int, _ y: Int) -> (ProgramCounterUpdate, String) {
    let (result, overflow) = self.v[x].subtractingReportingOverflow(self.v[y])
    let display =
      "Set V\(String(format: "%X", x)) to (\(self.v[x]) - \(self.v[y])), VF = \(!overflow)"

    self.v[x] = result
    self.v[0xF] =
      if !overflow {
        1
      } else {
        0
      }

    return (ProgramCounterUpdate.next, display)
  }

  mutating func op8xy4(_ x: Int, _ y: Int) -> (ProgramCounterUpdate, String) {
    let (result, overflow) = self.v[x].subtractingReportingOverflow(self.v[y])
    let display =
      "Set V\(String(format: "%X", x)) to (\(self.v[x]) + \(self.v[y])), VF = \(overflow)"

    self.v[x] = result
    self.v[0xF] = if overflow { 1 } else { 0 }

    return (ProgramCounterUpdate.next, display)
  }

  mutating func op8xy3(_ x: Int, _ y: Int) -> (ProgramCounterUpdate, String) {
    let display =
      "Set V\(String(format: "%X", x)) to V\(String(format: "%X", x)) XOR V\(String(format: "%X", y)) (\(String(format: "%2X", self.v[x])) XOR \(String(format: "%2X", self.v[y])))"

    self.v[x] ^= self.v[y]
    self.v[0xF] = 0
    return (ProgramCounterUpdate.next, display)
  }

  mutating func op8xy2(_ x: Int, _ y: Int) -> (ProgramCounterUpdate, String) {
    let display =
      "Set V\(String(format: "%X", x)) to V\(String(format: "%X", x)) AND V\(String(format: "%X", y)) (\(String(format: "%2X", self.v[x])) AND \(String(format: "%2X", self.v[y])))"

    self.v[x] &= self.v[y]
    self.v[0xF] = 0
    return (ProgramCounterUpdate.next, display)
  }

  mutating func op8xy1(_ x: Int, _ y: Int) -> (ProgramCounterUpdate, String) {
    let display =
      "Set V\(String(format: "%X", x)) to V\(String(format: "%X", x)) OR V\(String(format: "%X", y)) (\(String(format: "%2X", self.v[x])) OR \(String(format: "%2X", self.v[y])))"
    self.v[x] |= self.v[y]
    self.v[0xF] = 0
    return (ProgramCounterUpdate.next, display)
  }

  mutating func op8xy0(_ x: Int, _ y: Int) -> (ProgramCounterUpdate, String) {
    let display = "Set V\(String(format: "%X", x)) to V\(String(format: "%X", y)) (\(self.v[y]))"
    self.v[x] = self.v[y]

    return (ProgramCounterUpdate.next, display)
  }

  mutating func op7xnn(_ x: Int, _ nn: UInt8) -> (ProgramCounterUpdate, String) {
    let display = "Add \(nn) to V\(String(format: "%X", x))"
    self.v[x] = self.v[x].addingReportingOverflow(nn).partialValue
    return (ProgramCounterUpdate.next, display)
  }

  mutating func op6xnn(_ x: Int, _ nn: UInt8) -> (ProgramCounterUpdate, String) {
    let display = "Set V\(String(format: "%X", x)) to \(nn)"
    self.v[x] = nn

    return (ProgramCounterUpdate.next, display)
  }

  mutating func op5xy0(_ x: Int, _ y: Int) -> (ProgramCounterUpdate, String) {
    let display =
      "If V\(String(format: "%X", x)) (\(self.v[x])) == V\(String(format: "%X", y)) (\(self.v[y]))"

    if self.v[x] == self.v[y] {
      return (ProgramCounterUpdate.skipNext, display)
    } else {
      return (ProgramCounterUpdate.next, display)
    }
  }

  mutating func op4xnn(_ x: Int, _ nn: UInt8) -> (ProgramCounterUpdate, String) {
    let display = "If V\(String(format: "%X", x)) (\(self.v[x]) == \(nn), skip next instr)"

    if self.v[x] == nn {
      return (ProgramCounterUpdate.skipNext, display)
    } else {
      return (ProgramCounterUpdate.next, display)
    }
  }

  mutating func op3xnn(_ x: Int, _ nn: UInt8) -> (ProgramCounterUpdate, String) {
    let display = "If V\(String(format: "%X", x)) (\(self.v[x])) == \(nn), skip next instr"

    if self.v[x] == nn {
      return (ProgramCounterUpdate.skipNext, display)
    } else {
      return (ProgramCounterUpdate.next, display)
    }
  }

  mutating func op2nnn(_ nnn: Int) -> (ProgramCounterUpdate, String) {
    self.stack[self.sp] = UInt(self.pc + 2)
    self.sp += 1
    let display = "Call subroutine at \(String(format: "%#06X"))"

    return (ProgramCounterUpdate.jump(nnn), display)
  }

  mutating func op00e0(_ bus: inout Bus) -> (ProgramCounterUpdate, String) {
    bus.graphics.clear()
    let display = "Clear the screen"
    return (ProgramCounterUpdate.next, display)
  }

  mutating func op00ee() -> (ProgramCounterUpdate, String) {
    self.sp -= 1
    let display = "Return to addr \(String(format: "%#06X", self.stack[self.sp]))"
    return (ProgramCounterUpdate.jump(Int(self.stack[self.sp])), display)
  }

  mutating func op1nnn(_ nnn: Int) -> (ProgramCounterUpdate, String) {
    let display = "Jump to addr \(String(format: "%#06X", nnn))"
    return (ProgramCounterUpdate.jump(nnn), display)
  }

  mutating func opfx0a(_ bus: inout Bus, _ x: Int) -> (ProgramCounterUpdate, String) {
    let display = "Store next key press in V\(String(format: "%X", x))"
    bus.input.requestKeyPress(UInt(x))
    return (ProgramCounterUpdate.next, display)
  }
}
