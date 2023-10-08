import Foundation

public struct KeyRequestResponse {
  public var keyCode: UInt8
  public var register: UInt
}

public struct Input {
  public var state: [Bool]
  public var waiting: Bool
  public var requestReg: UInt
  public var requestResponse: KeyRequestResponse?

  public init() {
    self.state = Array()
    self.waiting = false
    self.requestReg = 0
    self.requestResponse = nil
  }

  public mutating func update(_ keyCode: UInt8, _ pressed: Bool) {
    let keyIndex = Int(keyCode)

    if self.state[keyIndex] == pressed {
      return
    }

    self.state[keyIndex] = pressed

    if pressed && self.waiting {
      self.waiting = false
      self.requestResponse = KeyRequestResponse(keyCode: keyCode, register: self.requestReg)
    }
  }

  public mutating func requestKeyPress(_ register: UInt) {
    self.waiting = true
    self.requestReg = register
  }

  public func isKeyPressed(_ keyCode: UInt8) -> Bool {
    self.state[Int(keyCode)]
  }

}
