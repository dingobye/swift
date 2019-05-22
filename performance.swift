// This file presents the code to measure the performance of 
// isPower(of:) implementation. The relevant pitch thread is 
// https://forums.swift.org/t/adding-ispowerof2-to-binaryinteger/24087

import Foundation


// DoubleWidth<> is defined in swift/test/Prototypes/DoubleWidth.swift.gyb
typealias UInt128 = DoubleWidth<UInt64>
typealias UInt256 = DoubleWidth<UInt128>
typealias UInt512 = DoubleWidth<UInt256>
typealias UInt1024 = DoubleWidth<UInt512>
typealias Int128 = DoubleWidth<Int64>
typealias Int256 = DoubleWidth<Int128>
typealias Int512 = DoubleWidth<Int256>
typealias Int1024 = DoubleWidth<Int512>

// _BigInt<> is defined in swift/test/Prototypes/BigInt.swift
typealias BigInt = _BigInt<UInt>


extension BinaryInteger {
  @inlinable
  public func isPower(of base: Self) -> Bool {
    // Fast path when base is one of the common cases.
    if base == 2 { return self._isPowerOfTwo_words }
    if base == 10 { return self._isPowerOfTen }
    if base._isPowerOfTwo_words { return self._isPowerOf(powerOfTwo: base) }
    // Slow path for other bases.
    return self._slowIsPower(of: base)
  }

  @inlinable @inline(__always)
  internal var _isPowerOfTwo_classic: Bool {
    return self > 0 && self & (self - 1) == 0
  }

  @inlinable
  internal var _isPowerOfTwo_words: Bool {
    let words = self.words
    precondition(words.isEmpty == false)
    // If the type is represented in a single word, perform the classic check.
    if words.count == 1 {
      let word = words[words.startIndex]
      return word > 0 && word & (word - 1) == 0
    }

    // Return false if it is negative by checking the most significant word.
    if Self.isSigned && Int(bitPattern: words[words.endIndex - 1]) < 0 {
      return false
    }
    // Check if there is exactly one non-zero word and it is a power of two.
    var foundPowerOfTwoWord = false
    for i in words.startIndex..<words.endIndex {
      let word: UInt = words[i]
      if word == 0 { continue }
      if foundPowerOfTwoWord { return false }
      if word & (word - 1) != 0 { return false }
      foundPowerOfTwoWord = true
    }
    return foundPowerOfTwoWord
  }

  @inlinable @inline(__always)
  internal var _isPowerOfTwo_cttz: Bool {
    return (self > 0) && (self == (1 as Self) << self.trailingZeroBitCount)
  }

  // The algorithm below is taken from Nevin's comments.
  // https://forums.swift.org/t/adding-ispowerof2-to-binaryinteger/24087/31
  @inlinable
  internal func _isPowerOf(powerOfTwo base: Self) -> Bool {
    precondition(base._isPowerOfTwo_words)
    guard self._isPowerOfTwo_words else { return false }
    return trailingZeroBitCount.isMultiple(of: base.trailingZeroBitCount)
  }

  // The algorithm below is taken from Michel Fortin's comments.
  // https://forums.swift.org/t/adding-ispowerof2-to-binaryinteger/24087/38
  @usableFromInline
  internal var _isPowerOfTen: Bool {
    let exponent = self.trailingZeroBitCount
    switch exponent {
    case 0:  return self == 1 as UInt8
    case 1:  return self == 10 as UInt8
    case 2:  return self == 100 as UInt8
    case 3:  return self == 1000 as UInt16
    case 4:  return self == 10000 as UInt16
    case 5:  return self == 100000 as UInt32
    case 6:  return self == 1000000 as UInt32
    case 7:  return self == 10000000 as UInt32
    case 8:  return self == 100000000 as UInt32
    case 9:  return self == 1000000000 as UInt32
    case 10: return self == 10000000000 as UInt64
    case 11: return self == 100000000000 as UInt64
    case 12: return self == 1000000000000 as UInt64
    case 13: return self == 10000000000000 as UInt64
    case 14: return self == 100000000000000 as UInt64
    case 15: return self == 1000000000000000 as UInt64
    case 16: return self == 10000000000000000 as UInt64
    case 17: return self == 100000000000000000 as UInt64
    case 18: return self == 1000000000000000000 as UInt64
    case 19: return self == 10000000000000000000 as UInt64
    default:
      // If this is 64-bit or less we can't have a higher power of 10
      if self.bitWidth <= 64 { return false }

      // Quickly check if parts of the bit pattern fits the power of 10.
      //
      // 10^0                                     1
      // 10^1                                  1_01_0
      // 10^2                               1_10_01_00
      // 10^3                             111_11_01_000
      // 10^4                          100111_00_01_0000
      // 10^5                        11000011_01_01_00000
      // 10^6                      1111010000_10_01_000000
      // 10^7                   1001100010010_11_01_0000000
      // 10^8                 101111101011110_00_01_00000000
      // 10^9               11101110011010110_01_01_000000000
      // 10^10           10010101000000101111_10_01_0000000000
      // ...
      // Column 1 is some "gibberish", which cannot be checked easily
      // Column 2 is always the last two bits of the exponent
      // Column 3 is always 01
      // Column 4 is the trailing zeros, in equal number to the exponent value
      //
      // We check if Column 2 matches the last two bits of the exponent and
      // Column 3 matches 0b01.
      guard (self >> exponent)._lowWord & 0b1111 ==
        ((exponent << 2) | 0b01) & 0b1111 else { return false }

      // Now time for the slow path.
      return self._slowIsPower(of: 10)
    }
  }

  @usableFromInline
  internal func _slowIsPower(of base: Self) -> Bool {
    // If self is 1, return true.
    if self == 1 { return true }

    // Here if base is 0, 1 or -1, return true iff self equals base.
    if base.magnitude <= 1 { return self == base }
    
    // At this point, we have base.magnitude >= 2. Repeatedly perform
    // multiplication by a factor of base, and check if it can equal self.
    guard self.isMultiple(of: base) else { return false }
    let bound = self / base
    var x: Self = 1
    while x.magnitude < bound.magnitude { x *= base }
    return x == bound
  }
}


extension FixedWidthInteger {
  // Alternative solution to _isPowerOfTwo
  @inlinable @inline(__always)
  public var _isPowerOfTwo_ctpop: Bool {
      return self > 0 && self.nonzeroBitCount == 1
  }
}


extension _BigInt {
  internal var _isPowerOfTwo_BigInt : Bool {
    guard !self.isZero && !self.isNegative else { return false }
    for i in 0..<(_data.count - 1) {
      if _data[i] != 0 { return false }
    }
    precondition(!_data.isEmpty, "A nonzero BigInt must have any element in _data.")
    let w = _data.last!
    precondition(w != 0, "_data has no trailing zero elements")
    return w & (w - 1) == 0
  }
}


@inline(never)
private func timing(title: String, op: ()->()) {
  let t1 = CFAbsoluteTimeGetCurrent() // <------ Start timing
  op()
  let t2 = CFAbsoluteTimeGetCurrent() // <------ End timing
  let d = String(format: "%.6f", t2 - t1)
  print("\(title):  execution time is \(d) s.")
}

@inline(never)
private func task<T: BinaryInteger>(_ title: String, _ n: T, _ isPowerOp: (T)->Bool, _ repeating: Int) {
  timing(title: title, op: {
      var n: T = n
      for _ in 0..<repeating {
          if isPowerOp(n) { n += 1 } else { n -= 1 }
      }
      guard n != 0 else { exit(-1) }
  })
}

private var bitWidthForTestBigInt = 1024

@inline(never)
private func commonTasks<T: BinaryInteger>(_ :T.Type) {
  let isBigInt = T.self == BigInt.self
  var n: T = 1 as T
  n = n << (isBigInt ? (bitWidthForTestBigInt - 1) : (n.bitWidth - 2))
  let repeating = isBigInt ? 1000 : (n.bitWidth < 128 ? 100_000_000 : 100_000)

  task("\(T.self).isPower(of: 2)       ", n, { (x:T)->Bool in x.isPower(of: 2) }, repeating)
  task("\(T.self)._isPowerOfTwo_classic", n, { (x:T)->Bool in x._isPowerOfTwo_classic }, repeating)
  task("\(T.self)._isPowerOfTwo_cttz   ", n, { (x:T)->Bool in x._isPowerOfTwo_cttz }, repeating)
  task("\(T.self)._isPowerOfTwo_words  ", n, { (x:T)->Bool in x._isPowerOfTwo_words }, repeating)
  task("\(T.self)._slowIsPower(of: 2)  ", n, { (x:T)->Bool in x._slowIsPower(of: 2) }, repeating)
  task("\(T.self).isPower(of: 4)       ", n, { (x:T)->Bool in x.isPower(of: 4) }, repeating)
  task("\(T.self)._slowIsPower(of: 4)  ", n, { (x:T)->Bool in x._slowIsPower(of: 4) }, repeating)

  // Set n as the greatest power of 10 representable
  let bound = n / 10
  n = 100 as T
  while n <= bound { n *= 10 }
  task("\(T.self)._isPowerOfTen        ", n, { (x:T)->Bool in x._isPowerOfTen }, repeating)
  task("\(T.self)._slowIsPower(of: 10) ", n, { (x:T)->Bool in x._slowIsPower(of: 10) }, repeating)
}

@inline(never)
private func measure<T: FixedWidthInteger>(_ t:T.Type) {
  let n: T = (1 as T) << (T.bitWidth - 2)
  let repeating = n.bitWidth < 128 ? 100_000_000 : 100_000
  task("\(T.self)._isPowerOfTwo_ctpop  ", n, { (x:T)->Bool in x._isPowerOfTwo_ctpop }, repeating)

  commonTasks(t)
  print("")
}

@inline(never)
private func measureBigInt(bits: Int) {
  bitWidthForTestBigInt = bits
  typealias T = BigInt
  let repeating = 1000
  let n: T = (1 as T) << (bitWidthForTestBigInt - 1)
  task("\(T.self)._isPowerOfTwo_BigInt", n, { (x:T)->Bool in x._isPowerOfTwo_BigInt }, repeating)

  commonTasks(BigInt.self)
  print("")
}


//===-------------------------------------------------------===//
//===--------  Built-in integers
measure(UInt8.self)
measure(UInt16.self)
measure(UInt32.self)
measure(UInt64.self)
measure(Int8.self)
measure(Int16.self)
measure(Int32.self)
measure(Int64.self)


//===---------------------------------------------------------===//
//===--------  DoubleWidth<> from swift/test/Prototypes/DoubleWidth.swift.gyb
measure(UInt128.self)
measure(UInt256.self)
measure(UInt512.self)
measure(UInt1024.self)
measure(Int128.self)
measure(Int256.self)
measure(Int512.self)
measure(Int1024.self)


//===---------------------------------------------------------===//
//===--------  _BigInt<> from swift/test/Prototypes/BigInt.swift
measureBigInt(bits: 1024)
measureBigInt(bits: 32768)

