import strutils

type
  Flags = enum
    Negative

  BigInt* = tuple
    limbs: seq[uint32]
    flags: set[Flags]

const maxInt = int64(high uint32)

proc normalize(a: var BigInt) =
  for i in countdown(a.limbs.high, 0):
    if a.limbs[i] > 0'u32:
      a.limbs.setLen(i+1)
      return
  a.limbs.setLen(1)

proc initBigInt*(vals: seq[uint32], flags: set[Flags] = {}): BigInt =
  result.limbs = vals
  result.flags = flags

proc initBigInt*[T: int|int16|int32|uint|uint16|uint32](val: T): BigInt =
  # TODO: int64
  result.limbs = @[uint32(abs(int64(val)))]
  result.flags = {}
  if int64(val) < 0:
    result.flags.incl(Negative)

const null = initBigInt(0)
const one = initBigInt(1)

proc unsignedCmp(a: BigInt, b: int32): int64 =
  result = int64(a.limbs.len) - 1

  if result != 0:
    return

  result = int64(a.limbs[0]) - int64(b)

proc unsignedCmp(a: int32, b: BigInt): int64 =
  -unsignedCmp(b, a)

proc unsignedCmp(a, b: BigInt): int64 =
  result = int64(a.limbs.len) - int64(b.limbs.len)

  if result != 0:
    return

  for i in countdown(a.limbs.high, 0):
    result = int64(a.limbs[i]) - int64(b.limbs[i])

    if result != 0:
      return

proc cmp*(a, b: BigInt): int64 =
  if Negative in a.flags and a.limbs != @[0'u32]:
    if Negative in b.flags and b.limbs != @[0'u32]:
      return unsignedCmp(b, a)
    else:
      return -1
  else:
    if Negative in b.flags:
      return 1
    else:
      return unsignedCmp(a, b)

proc cmp*(a: int32, b: BigInt): int64 =
  if a < 0:
    if Negative in b.flags and b.limbs != @[0'u32]:
      return unsignedCmp(b, a)
    else:
      return -1
  else:
    if Negative in b.flags:
      return 1
    else:
      return unsignedCmp(a, b)

proc cmp*(a: BigInt, b: int32): int64 =
  if Negative in a.flags and a.limbs != @[0'u32]:
    if b < 0:
      return unsignedCmp(b, a)
    else:
      return -1
  else:
    if b < 0:
      return 1
    else:
      return unsignedCmp(a, b)

proc `<` *(a, b: BigInt): bool = cmp(a, b) < 0
proc `<` *(a: BigInt, b: int32): bool = cmp(a, b) < 0
proc `<` *(a: int32, b: BigInt): bool = cmp(a, b) < 0

proc `<=` *(a, b: BigInt): bool = cmp(a, b) <= 0
proc `<=` *(a: BigInt, b: int32): bool = cmp(a, b) <= 0
proc `<=` *(a: int32, b: BigInt): bool = cmp(a, b) <= 0

proc `==` *(a, b: BigInt): bool = cmp(a, b) == 0
proc `==` *(a: BigInt, b: int32): bool = cmp(a, b) == 0
proc `==` *(a: int32, b: BigInt): bool = cmp(a, b) == 0

template addParts(toAdd) =
  tmp += toAdd
  a.limbs[i] = uint32(tmp)
  tmp = tmp shr 32

proc unsignedAdditionInt(a: var BigInt, b: BigInt, c: int32) =
  var tmp: uint64

  let bl = b.limbs.len
  const cl = 1
  const m = 1

  a.limbs.setLen(bl)

  tmp = uint64(b.limbs[0]) + uint64(c)
  a.limbs[0] = uint32(tmp)
  tmp = tmp shr 32

  for i in m .. < bl:
    addParts(uint64(b.limbs[i]))

  if tmp > 0'u64:
    a.limbs.add(uint32(tmp))

  a.flags.excl(Negative)

# Works when a = b
proc unsignedAddition(a: var BigInt, b, c: BigInt) =
  var tmp: uint64

  let
    bl = b.limbs.len
    cl = c.limbs.len
  var m = if bl < cl: bl else: cl

  a.limbs.setLen(if bl < cl: cl else: bl)

  for i in 0 .. < m:
    addParts(uint64(b.limbs[i]) + uint64(c.limbs[i]))

  if bl < cl:
    for i in m .. < cl:
      addParts(uint64(c.limbs[i]))
  else:
    for i in m .. < bl:
      addParts(uint64(b.limbs[i]))

  if tmp > 0'u64:
    a.limbs.add(uint32(tmp))

  a.flags.excl(Negative)

proc negate(a: var BigInt) =
  if Negative in a.flags:
    a.flags.excl(Negative)
  else:
    a.flags.incl(Negative)

# Works when a = b
# Assumes positive parameters and b > c
template realUnsignedSubtractionInt(a: var BigInt, b: BigInt, c: int32) =
  var tmp: int64

  let bl = b.limbs.len
  const cl = 1
  const m = cl

  a.limbs.setLen(bl)

  block:
    const i = 0
    tmp = int64(uint32.high) + 1 + int64(b.limbs[i]) - int64(c)
    a.limbs[i] = uint32(tmp)
    tmp = 1 - (tmp shr 32)

  for i in m .. < bl:
    tmp = int64(uint32.high) + 1 + int64(b.limbs[i]) - tmp
    a.limbs[i] = uint32(tmp)
    tmp = 1 - (tmp shr 32)
  a.flags.excl(Negative)

  normalize(a)

  if tmp > 0:
    a.limbs.add(uint32(tmp))

# Works when a = b
# Assumes positive parameters and b > c
template realUnsignedSubtraction(a: var BigInt, b, c: BigInt) =
  var tmp: int64

  let
    bl = b.limbs.len
    cl = c.limbs.len
  var m = if bl < cl: bl else: cl

  a.limbs.setLen(if bl < cl: cl else: bl)

  for i in 0 .. < m:
    tmp = int64(uint32.high) + 1 + int64(b.limbs[i]) - int64(c.limbs[i]) - tmp
    a.limbs[i] = uint32(tmp)
    tmp = 1 - (tmp shr 32)

  if bl < cl:
    for i in m .. < cl:
      tmp = int64(uint32.high) + 1 - int64(c.limbs[i]) - tmp
      a.limbs[i] = uint32(tmp)
      tmp = 1 - (tmp shr 32)
    a.flags.incl(Negative)
  else:
    for i in m .. < bl:
      tmp = int64(uint32.high) + 1 + int64(b.limbs[i]) - tmp
      a.limbs[i] = uint32(tmp)
      tmp = 1 - (tmp shr 32)
    a.flags.excl(Negative)

  normalize(a)

  if tmp > 0:
    a.limbs.add(uint32(tmp))

proc unsignedSubtractionInt(a: var BigInt, b: BigInt, c: int32) =
  if unsignedCmp(b, c) >= 0:
    realUnsignedSubtractionInt(a, b, c)
  else:
    # TODO: is this right?
    realUnsignedSubtractionInt(a, b, c)
    negate(a)

proc unsignedSubtraction(a: var BigInt, b, c: BigInt) =
  if unsignedCmp(b, c) > 0:
    realUnsignedSubtraction(a, b, c)
  else:
    realUnsignedSubtraction(a, c, b)
    negate(a)

proc additionInt(a: var BigInt, b: BigInt, c: int32) =
  if Negative in b.flags:
    if c < 0:
      unsignedAdditionInt(a, b, c)
      a.flags.incl(Negative)
    else:
      # TODO: is this right?
      unsignedSubtractionInt(a, b, c)
  else:
    if c < 0:
      var c = -c
      unsignedSubtractionInt(a, b, c)
    else:
      unsignedAdditionInt(a, b, c)

proc addition(a: var BigInt, b, c: BigInt) =
  if Negative in b.flags:
    if Negative in c.flags:
      unsignedAddition(a, b, c)
      a.flags.incl(Negative)
    else:
      unsignedSubtraction(a, c, b)
  else:
    if Negative in c.flags:
      unsignedSubtraction(a, b, c)
    else:
      unsignedAddition(a, b, c)

proc `+` *(a: BigInt, b: int32): BigInt=
  result = null
  additionInt(result, a, b)

proc `+` *(a, b: BigInt): BigInt=
  result = null
  addition(result, a, b)

template `+=` *(a: var BigInt, b: BigInt) =
  var c = a
  addition(a, c, b)

template `+=` *(a: var BigInt, b: int32) =
  var c = a
  additionInt(a, c, b)

template optAddInt*{x = y + z}(x,y: BigInt, z: int32) = additionInt(x, y, z)

template optAdd*{x = y + z}(x,y,z: BigInt) = addition(x, y, z)

proc subtractionInt(a: var BigInt, b: BigInt, c: int32) =
  if Negative in b.flags:
    if c < 0:
      # TODO: is this right?
      unsignedSubtractionInt(a, b, c)
      a.flags.incl(Negative)
    else:
      unsignedAdditionInt(a, b, c)
      a.flags.incl(Negative)
  else:
    if c < 0:
      unsignedAdditionInt(a, b, c)
    else:
      unsignedSubtractionInt(a, b, c)

proc subtraction(a: var BigInt, b, c: BigInt) =
  if Negative in b.flags:
    if Negative in c.flags:
      unsignedSubtraction(a, c, b)
    else:
      unsignedAddition(a, b, c)
      a.flags.incl(Negative)
  else:
    if Negative in c.flags:
      unsignedAddition(a, b, c)
    else:
      unsignedSubtraction(a, b, c)

proc `-` *(a: BigInt, b: int32): BigInt=
  result = null
  subtractionInt(result, a, b)

template `-=` *(a: var BigInt, b: int32) =
  var c = a
  subtractionInt(a, c, b)

proc `-` *(a, b: BigInt): BigInt=
  result = null
  subtraction(result, a, b)

template `-=` *(a: var BigInt, b: BigInt) =
  var c = a
  subtraction(a, c, b)

template optSub*{x = y - z}(x,y,z: BigInt) = subtraction(x, y, z)

template unsignedMultiplicationInt(a: BigInt, b: BigInt, c: int32, bl) =
  for i in 0 .. < bl:
    tmp += uint64(b.limbs[i]) * uint64(c)
    a.limbs[i] = uint32(tmp)
    tmp = tmp shr 32

  a.limbs[bl] = uint32(tmp)
  tmp = tmp shr 32

  normalize(a)

template unsignedMultiplication(a: BigInt, b, c: BigInt, bl, cl) =
  for i in 0 .. < bl:
    tmp += uint64(b.limbs[i]) * uint64(c.limbs[0])
    a.limbs[i] = uint32(tmp)
    tmp = tmp shr 32

  for i in bl .. < bl + cl:
    a.limbs[i] = 0

  var pos = bl

  while tmp > 0'u64:
    a.limbs[pos] = uint32(tmp)
    tmp = tmp shr 32
    pos.inc()

  for j in 1 .. < cl:
    for i in 0 .. < bl:
      tmp += uint64(a.limbs[j + i]) + uint64(b.limbs[i]) * uint64(c.limbs[j])
      a.limbs[j + i] = uint32(tmp)
      tmp = tmp shr 32

    pos = j + bl
    while tmp > 0'u64:
      tmp += uint64(a.limbs[pos])
      a.limbs[pos] = uint32(tmp)
      tmp = tmp shr 32
      pos.inc()

  normalize(a)

# This doesn't work when a = b
proc multiplicationInt(a: var BigInt, b: BigInt, c: int32) =
  let bl = b.limbs.len
  var
    tmp, tmp2, tmp3: uint64

  a.limbs.setLen(bl + 1)

  unsignedMultiplicationInt(a, b, c, bl)

  if Negative in b.flags:
    if c < 0:
      a.flags.excl(Negative)
    else:
      a.flags.incl(Negative)
  else:
    if c < 0:
      a.flags.incl(Negative)
    else:
      a.flags.excl(Negative)

# This doesn't work when a = b
proc multiplication(a: var BigInt, b, c: BigInt) =
  let
    bl = b.limbs.len
    cl = c.limbs.len
  var
    tmp, tmp2, tmp3: uint64

  a.limbs.setLen(bl + cl)

  if cl > bl:
    unsignedMultiplication(a, c, b, cl, bl)
  else:
    unsignedMultiplication(a, b, c, bl, cl)

  if Negative in b.flags:
    if Negative in c.flags:
      a.flags.excl(Negative)
    else:
      a.flags.incl(Negative)
  else:
    if Negative in c.flags:
      a.flags.incl(Negative)
    else:
      a.flags.excl(Negative)

proc `*` *(a: BigInt, b: int32): BigInt =
  result = null
  multiplicationInt(result, a, b)

template `*=` *(a: var BigInt, b: int32) =
  var c = a
  multiplicationInt(a, c, b)

proc `*` *(a, b: BigInt): BigInt =
  result = null
  multiplication(result, a, b)

template `*=` *(a: var BigInt, b: BigInt) =
  var c = a
  multiplication(a, c, b)

template optMulInt*{x = `*`(y, z)}(x: BigInt{noalias}, y: BigInt, z: int32) = multiplicationInt(x, y, z)

template optMulSameInt*{x = `*`(x, z)}(x: BigInt, z: int32) = x *= z

template optMul*{x = `*`(y, z)}(x: BigInt{noalias}, y, z: BigInt) = multiplication(x, y, z)

template optMulSame*{x = `*`(x, z)}(x,z: BigInt) = x *= z

# Works when a = b
proc shiftRight(a: var BigInt, b: BigInt, c: int) =
  a.limbs.setLen(b.limbs.len)
  var carry: uint64
  let d = c div 32
  let e = c mod 32
  let mask: uint32 = 1'u32 shl uint32(e) - 1

  for i in countdown(b.limbs.high, d):
    let acc: uint64 = (carry shl 32) or b.limbs[i]
    carry = uint32(acc and mask)
    a.limbs[i - d] = uint32(acc shr uint32(e))

  a.limbs.setLen(a.limbs.len - d)

  if a.limbs.len > 1 and a.limbs[a.limbs.high] == 0:
    a.limbs.setLen(a.limbs.high)

proc `shr` *(x: BigInt, y: int): BigInt =
  result = null
  shiftRight(result, x, y)

template optShr*{x = y shr z}(x, y: BigInt, z) = shiftRight(x, y, z)

# Works when a = b
proc shiftLeft(a: var BigInt, b: BigInt, c: int) =
  a.limbs.setLen(b.limbs.len)
  var carry: uint32

  for i in 0..b.limbs.high:
    let acc = (uint64(b.limbs[i]) shl uint64(c)) or carry
    a.limbs[i] = uint32(acc)
    carry = uint32(acc shr 32)

  if carry > 0'u32:
    a.limbs.add(carry)

proc `shl` *(x: BigInt, y: int): BigInt =
  result = null
  shiftLeft(result, x, y)

template optShl*{x = y shl z}(x, y: BigInt, z) = shiftLeft(x, y, z)

proc reset*(a: var BigInt) =
  a.limbs.setLen(1)
  a.limbs[0] = 0
  a.flags = {}

proc unsignedDivRem(q: var BigInt, r: var uint32, n: BigInt, d: uint32) =
  q.limbs.setLen(n.limbs.len)
  r = 0

  for i in countdown(n.limbs.high, 0):
    let tmp: uint64 = uint64(n.limbs[i]) + uint64(r) shl 32
    q.limbs[i] = uint32(tmp div d)
    r = uint32(tmp mod d)

  while q.limbs.len > 1 and q.limbs[q.limbs.high] == 0:
    q.limbs.setLen(q.limbs.high)

proc bits(d: uint32): int =
  const bitLengths = [0, 1, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 4, 4, 4, 4,
                      5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]
  var d = d

  while d >= 32'u32:
    result += 6
    d = d shr 6
  result += bitLengths[int(d)]

# From Knuth and Python
proc unsignedDivRem(q, r: var BigInt, n, d: BigInt) =
  var
    nn = n.limbs.len
    dn = d.limbs.len

  if nn == 0:
    q.reset()
    r.reset()
  elif nn < dn:
    r = n
    q.reset()
  elif dn == 1:
    var x: uint32
    unsignedDivRem(q, x, n, d.limbs[0])
    r.limbs.setLen(1)
    r.limbs[0] = x
    r.flags = {}
  else:
    assert nn >= dn and dn >= 2
    var carry: uint64

    # normalize
    let ls = 32 - bits(d.limbs[d.limbs.high])
    r = d shl ls
    q = n shl ls
    if q.limbs.len > n.limbs.len or q.limbs[q.limbs.high] >= r.limbs[r.limbs.high]:
      q.limbs.add(0'u32)
      inc(nn)

    let k = nn - dn
    assert k >= 0
    var a = null
    a.limbs.setLen(k)
    let wm1 = r.limbs[r.limbs.high]
    let wm2 = r.limbs[r.limbs.high-1]
    var ak = k

    var zhi = 0.initBigInt
    var z = 0.initBigInt
    var qib = 0.initBigInt
    var q1b = 0.initBigInt

    for v in countdown(k-1, 0):
      # estimate quotient digit, may rarely overestimate by 1
      let vtop = q.limbs[v + dn]
      assert vtop <= wm1
      let vv = (uint64(vtop) shl 32) or q.limbs[v+dn-1]
      var q1 = uint64(vv) div wm1
      var r1 = uint64(vv) mod wm1

      while (uint64(wm2)*q1) > ((r1 shl 32) or q.limbs[v+dn-2]):
        dec(q1)
        r1 += wm1
        if r1 > uint64(uint32.high):
          break

      assert q1 <= uint64(uint32.high)

      q1b.limbs[0] = uint32(q1)

      # subtract
      zhi.reset()
      for i in 0 .. <dn:
        z.reset()
        z.limbs[0] = r.limbs[i]
        z *= q1b
        z.flags.incl Negative
        z += zhi
        qib.limbs[0] = q.limbs[v+i]
        z += qib
        q.limbs[v+i] = not z.limbs[0] + 1
        if z.limbs.len > 1:
          zhi.limbs[0] = z.limbs[1] + 1
          zhi.flags.incl Negative
        elif z < 0:
          zhi.limbs[0] = 1
          zhi.flags.incl Negative
        else:
          zhi.reset()

      # add back if was too large (rare branch)
      if vtop.initBigInt + zhi < 0:
        carry = 0
        for i in 0 .. <dn:
          carry += q.limbs[v+i] + r.limbs[i]
          q.limbs[v+i] = uint32(carry)
          carry = carry shr 32
        dec(q1)

      # store quotient digit
      assert q1 <= uint64(uint32.high)
      dec(ak)
      a.limbs[ak] = uint32(q1)

    # unshift remainder, we reuse w1 to store the result
    q.limbs.setLen(dn)
    r = q shr ls

    normalize(r)
    q = a
    normalize(q)

proc division(q, r: var BigInt, n, d: BigInt) =
  unsignedDivRem(q, r, n, d)

  # set signs
  if n < 0 xor d < 0:
    q.flags.incl(Negative)
  else:
    q.flags.excl(Negative)

  if n < 0 and r != 0:
    r.flags.incl(Negative)
  else:
    r.flags.excl(Negative)

  # divrem -> divmod
  if (r < 0 and d > 0) or
     (r > 0 and d < 0):
    r += d
    q -= one

proc division(q, r: var BigInt, n: BigInt, d: int32) =
  r.reset()
  # TODO: is this correct?
  unsignedDivRem(q, r.limbs[0], n, uint32(d))

  # set signs
  if n < 0 xor d < 0:
    q.flags.incl(Negative)
  else:
    q.flags.excl(Negative)

  if n < 0 and r != 0:
    r.flags.incl(Negative)
  else:
    r.flags.excl(Negative)

  # divrem -> divmod
  if (r < 0 and d > 0) or
     (r > 0 and d < 0):
    r += d
    q -= one

proc `div` *(a: BigInt, b: int32): BigInt =
  result = null
  var tmp = null
  division(result, tmp, a, b)

proc `div` *(a, b: BigInt): BigInt =
  result = null
  var tmp = null
  division(result, tmp, a, b)

proc `mod` *(a: BigInt, b: int32): BigInt =
  result = null
  var tmp = null
  division(tmp, result, a, b)

proc `mod` *(a, b: BigInt): BigInt =
  result = null
  var tmp = null
  division(tmp, result, a, b)

proc `divmod` *(a: BigInt, b: int32): tuple[q, r: BigInt] =
  result.q = null
  result.r = null
  division(result.q, result.r, a, b)

proc `divmod` *(a, b: BigInt): tuple[q, r: BigInt] =
  result.q = null
  result.r = null
  division(result.q, result.r, a, b)

# TODO: This doesn't work because it's applied before the other rules, which
# should take precedence. This also doesn't work for x = y etc
#template optDiv*{x = y div z}(x,y,z: BigInt) =
#  var tmp = null
#  division(x, tmp, y, z)
#
#template optMod*{x = y mod z}(x,y,z: BigInt) =
#  var tmp = null
#  division(tmp, x, y, z)

template optDivMod*{w = y div z; x = y mod z}(w,x,y,z: BigInt) =
  division(w, x, y, z)

template optDivMod2*{w = x div z; x = x mod z}(w,x,z: BigInt) =
  var tmp = x
  division(w, x, tmp, z)

template optDivMod3*{w = w div z; x = w mod z}(w,x,z: BigInt) =
  var tmp = w
  division(w, x, tmp, z)

template optDivMod4*{w = y mod z; x = y div z}(w,x,y,z: BigInt) =
  division(x, w, y, z)

template optDivMod5*{w = x mod z; x = x div z}(w,x,z: BigInt) =
  var tmp = x
  division(x, w, tmp, z)

template optDivMod6*{w = w mod z; x = w div z}(w,x,z: BigInt) =
  var tmp = w
  division(x, w, tmp, z)

const digits = "0123456789abcdefghijklmnopqrstuvwxyz"

const multiples = [2,4,8,16,32]

proc calcSizes(): array[2..36, int] =
  for i in 2..36:
    var x = int64(uint32.high) div i # 1 less so we actually fit
    while x > 0:
      x = x div i
      result[i].inc()

#const sizes: array[2..36, int] = [31,20,15,13,12,11,10,10,9,9,8,8,8,8,7,7,7,7,7,7,7,7,6,6,6,6,6,6,6,6,6,6,6,6,6]

# not working with consts
let sizes = calcSizes()

proc toStringMultipleTwo(a: BigInt, base: range[2..36] = 16): string =
  assert(base in multiples)
  var
    size = sizes[base] + 1
    cs = newStringOfCap(size)

  result = newStringOfCap(size * a.limbs.len + 1)
  if Negative in a.flags:
    result.add('-')
  #result.add("0x")

  # Special case for the highest
  var x = a.limbs[a.limbs.high]
  while x > 0'u32:
    cs.add(digits[int(x mod base)])
    x = x div base
  for j in countdown(cs.high, 0):
    result.add(cs[j])

  cs.setLen(size)

  for i in countdown(a.limbs.high - 1, 0):
    var x = a.limbs[i]
    for i in 0 .. < size:
      cs[size - i - 1] = digits[int(x mod base)]
      x = x div base
    result.add(cs)

  if result.len == 0:
    result.add('0')

proc reverse(a: string): string =
  result = newString(a.len)
  for i, c in a:
    result[a.high - i] = c

proc `^`* [T](base, exp: T): T =
  var
    base = base
    exp = exp
  result = 1

  while exp != 0:
    if (exp and 1) != 0:
      result *= base
    exp = exp shr 1
    base *= base

proc pow*(base: int32|BigInt, exp: int32|BigInt): BigInt =
  when type(base) is BigInt:
    var base = base
  else:
    var base = initBigInt(base)
  var exp = exp
  result = one

  while exp != 0:
    if (exp mod 2) > 0:
      result *= base
    exp = exp shr 1
    var tmp = base
    base *= tmp

proc toString*(a: BigInt, base: range[2..36] = 10): string =
  if base in multiples:
    return toStringMultipleTwo(a, base)

  var
    tmp = a
    c = 0'u32
    d = uint32(base) ^ uint32(sizes[base])
    s = ""

  result = ""

  if Negative in a.flags:
    tmp.flags.excl(Negative)
    result.add('-')

  while tmp > 0:
    unsignedDivRem(tmp, c, tmp, d)
    for i in 1 .. sizes[base]:
      s.add(digits[int(c mod base)])
      c = c div base

  var lastDigit = s.high
  while lastDigit > 0:
    if s[lastDigit] != '0':
      break
    dec lastDigit

  s.setLen(lastDigit+1)
  if s.len == 0: s = "0"
  result.add(reverse(s))

proc `$`*(a: BigInt) : string = toString(a, 10)

proc initBigInt*(str: string, base: range[2..36] = 10): BigInt =
  result.limbs = @[0'u32]
  result.flags = {}

  var mul = one
  let size = sizes[base]
  var first = 0
  var str = str
  var fs: set[Flags]

  if str[0] == '-':
    first = 1
    fs.incl(Negative)
    str[0] = '0'

  for i in countdown((str.high div size) * size, 0, size):
    var smul = 1'u32
    var num: uint32
    for j in countdown(min(i + size - 1, str.high), max(i, first)):
      let c = toLower(str[j])

      # This is pretty expensive
      if not (c in digits[0..base]):
        raise newException(ValueError, "Invalid input: " & str[j])

      case c
      of '0'..'9': num += smul * uint32(ord(c) - ord('0'))
      of 'a'..'z': num += smul * uint32(ord(c) - ord('a') + 10)
      else: raise newException(ValueError, "Invalid input: " & str[j])

      smul *= base
    result += mul * initBigInt(num)
    mul *= initBigInt(smul)

  result.flags = fs

proc inc*(a: var BigInt, b: BigInt) =
  var c = a
  addition(a, c, b)

proc inc*(a: var BigInt, b: int32 = 1) =
  var c = a
  additionInt(a, c, b)

proc dec*(a: var BigInt, b: BigInt) =
  var c = a
  subtraction(a, c, b)

proc dec*(a: var BigInt, b: int32 = 1) =
  var c = a
  subtractionInt(a, c, b)

iterator countdown*(a, b: BigInt, step: int32 = 1): BigInt {.inline.} =
  var res = a
  while res >= b:
    yield res
    dec(res, step)

iterator countup*(a, b: BigInt, step: int32 = 1): BigInt {.inline.} =
  var res = a
  while res <= b:
    yield res
    inc(res, step)

iterator `..`*(a, b: BigInt): BigInt {.inline.} =
  var res = a
  while res <= b:
    yield res
    inc res

when isMainModule:
  # We're about twice as slow as GMP in these microbenchmarks:

  # 4.8 s vs 3.9 s GMP
  #var a = initBigInt(1337)
  #var b = initBigInt(42)
  #var c = initBigInt(0)

  #for i in 0..200000:
  #  c = a + b
  #  b = a + c
  #  a = b + c
  #c += c

  # 1.0 s vs 0.7 s GMP
  #var a = initBigInt(0xFFFFFFFF'u32)
  #var b = initBigInt(0xFFFFFFFF'u32)
  #var c = initBigInt(0)

  #for i in 0..20_000:
  #  c = a * b
  #  a = c * b

  #var a = initBigInt(@[0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32])
  #var b = initBigInt(@[0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32])
  #var c = initBigInt(0)

  # 0.5 s vs 0.2 s GMP
  #var a = initBigInt(@[0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32])
  #var b = initBigInt(@[0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32, 0xFFFFFFFF'u32])
  #var c = initBigInt(0)
  #for i in 0..10_000_000:
  #  c = a * b

  #var a = initBigInt(1000000000)
  #var b = initBigInt(1000000000)
  #var c = a+a+a+a+a+a+a+a+a+a+a+a+a+a+a+a+a+a
  #echo c.toString()

  #var a = initBigInt(@[0xFEDCBA98'u32, 0xFFFFFFFF'u32, 0x12345678'u32, 0xFFFFFFFF'u32])
  #var b = initBigInt(0)
  #echo a
  #b = a shl 205
  #echo b
  #a = a shl 205
  #echo a
  #for i in 0..100000000:
  #  shiftLeft(b, a, 24)
  #echo b
  #shiftLeft(a, b, 24)
  #echo a
  #shiftRight(a, b, 20000)
  #echo a

  #echo a
  #c = a * b
  #echo c
  #for i in 0..50000:
  #  a *= b
  #echo a

  #echo cmp(a,a)
  #echo cmp(a,b)
  #echo cmp(b,a)
  #echo cmp(a,c)
  #echo cmp(c,a)
  #echo cmp(b,c)
  #echo cmp(b,b)
  #echo cmp(c,c)

  #for i in 0..1000000:
  #  var x = initBigInt("0000111122223333444455556666777788889999")
  #var x = initBigInt("0000111122223333444455556666777788889999", 16)
  #var x = initBigInt("11", 16)
  #echo x
  #var y = initBigInt("-0000110000000000000000000000000000000000", 16)
  #var y = initBigInt("-11", 16)
  #echo y

  #var a = initBigInt("222222222222222222222222222222222222222222222222222222222222222222222222222222", 16)
  #var b = initBigInt("1111111111111111111111111111111111111111111111111111111111111111111111111", 16)
  #var q = initBigInt(0)
  #var r = initBigInt(0)
  #division(q,r,a,b)
  #echo q.limbs
  #echo r.limbs

  #var a = initBigInt("fffffffffffffffffffffffff", 16)
  #var b = initBigInt("fffffffffffffffffffffffff", 16)
  #echo a
  #echo b
  #echo a * b

  #var a = initBigInt("111122223333444455556666777788889999", 10)
  #var b = 0'u32
  #var c = initBigInt(0)

  #echo a.limbs
  #division(c, b, a, 100)
  #echo c
  #echo b

  #echo a.toString(10)

  #var a = initBigInt("111122223333444455556666777788889999", 10)
  #var b = initBigInt(0)
  #var c = initBigInt(0)

  #echo a.limbs
  #division(c, b, a, initBigInt("556666777788889999", 10))
  #echo c
  #echo b

  #echo a.toString(10)

  #var a = initBigInt(@[4294967295'u32, 0'u32, 1'u32])
  #var b = initBigInt(0)
  #a = a shl 31
  ##var b = a shl 1
  #for i in countdown(a.limbs.high, 0):
  #  stdout.write(toHex(int64(a.limbs[i]), 8) & " ")
  #echo "\n ----- "
  #for i in countdown(b.limbs.high, 0):
  #  stdout.write(toHex(int64(b.limbs[i]), 8) & " ")

  #var a = initBigInt(0)
  #a.limbs.setLen(20001)
  #for i in 0..20000:
  #  a.limbs[i] = 0xFF_FF_FF_FF'u32
  ##a.limbs[20001] = 0b0000_0001_1111_1111_1111_1111_1111_1111'u32

  #var a = initBigInt(-13)
  #var b = initBigInt(-10)
  #echo a div b
  #echo a mod b
  #echo a.toString(10)

  #var a = initBigInt(3)
  #var b = initBigInt("100000000000000000")
  #echo a - b

  #a = a div b
  #echo a

  #var a = initBigInt("114563644360333347700372329626168316793115507959307062949710523744989695464449225205841634915762626460598360592957710138104092802289353468061413012636613144333838896336671958767939732533712207225240881417306586834931980305973362337217612343305405994503389889956658191787743071027072639968990356716036687103663834079725347692146897315979003906250")
  #var b = initBigInt("37110314837047916227882694320360675271152660126976564204341054165582659066313003251294342658387330791109263639054518846261243201776403745881386398672927926765573625696633292384950281404347174511630802572216125672511290566438440980352276195055462659645876962628295015910491909958529441748144812127421727850262294140657104435376822948455810546875")
  ##var c = a div b
  #var d = a mod b
  ##echo c
  #echo a
  #echo b
  #echo d

  #var a = initBigInt(3225)
  #var b = initBigInt(240)
  #a += b
  #echo a

  #var a = initBigInt("176206390484111649670565285281535494096573857183344276918667663963221676301197729485410008095645976019172170391040222532126288730386146435153818474132388709061170722938476941658754628345275176986460943315899031023622489897390090425887600422373020323833947861264392150228054803318242325151623477497569678695274872363196564000211830423270100846173925887876497546308817147991387816212128421014623672280450790006161488181500288969289620708421445635520413947028146871017121332770732190770726575692877757534865394691433859985510087629268621329076774293546349631593330716567725109440366992918345112005896305414469484767723908970046328045488303702537173428410107925617484663656273404571746913676830920092271554113099319300324096636450399568799275846937847473892408009795197569885285496759648162838267229246514158878204348299246423803547265912214453433448276097598585130404095115054589087489833596463142739580441144264799646634855889715254306793212890625")
  #var b = initBigInt(0)
  #var acc = initBigInt("861210082732066541532665887925299303579512781038289409489470886836236995532341661502300077529662592103949902897170235705942880440590653121006900618559776768310816610553371337447706999981577599375587341186749682484082350039871662512708747027935794011364002882479290935571588018504174265039105934908825594902472830871614778292875382370917452638932983308796613574868097761220057870728168147915772008453100610713188736271915262792413408620656544871809262305724051465756524682416577887280505693119967339110566033625292183037852238710834633719668887688918151471745620796224928388087679593585646815738655018105979481430851232357068527760908700832334635544169865534008118045857792961830603167249028302420612456968287955659132951856711104091884763609192744199821311720800038359880293199593290902312150930776977888986212927451017185789241644617568344066866602117874714001907745824210773602563102098490105135858430074335956305731087923049926757812500")
  #var c = a * b
  #echo c.limbs
  #echo acc - c

  #var a = initBigInt(0)
  #a.flags.incl Negative
  #var b = initBigInt(1)
  #a -= one
  #echo a

  #var a = initBigInt("1667510816052609025")
  #var b = initBigInt("1667510816052609025")
  #var c = a * b
  #echo a
  #echo b
  #echo c

  #var a = 0.initBigInt
  #var b = 0.initBigInt
  #division(a, b, initBigInt("756628490253123014067933708583503295844929075882239485540431356534910033618830501144105195285364489562157441837796863614070956636498456792910898817389940831543204657474297072356228690296487944931559885281889207062770782744748470400"), initBigInt("115792089237316195423570985008687907853269984665640564039457584007908834671663"))
  #echo a.toString(16)
  #echo "6534371175412604458958908912693048525839811796587982546211129043135405424530153901770406203935164968917121831102336830270909059548152185210409961777233761".initBigInt.toString(16)
  #echo "---"
  #echo b.toString(16)
  #echo "91914383230618135761690975197207778399550061809281766160147273830617914855857".initBigInt.toString(16)

  #var x = initBigInt("2255875222507173014903831549779832674595557833545810114678871681588232398142786344083210556465068007125337448701463750107379031912851019881138289772814467603519957280600094236460918741699178978152447128809716538793960237414981350687")
  #var y = initBigInt("115792089237316195423570985008687907853269984665640564039457584007908834671663")
  #echo "19482118660833131143565059488889132062536031277944370802080045650318995799224424488550052744512926453902359616090610097833707910217541850445599669546171445"
  #echo x div y
  #echo "---"
  #echo "48317604920791681227269902149572831041666497563152549156566744096979700087652"
  #echo x mod y

  #var x: BigInt = @[175614014'u32, 1225800181'u32].initBigInt
  #echo x shr 32

  #var y: BigInt = @[175614014'u32, 1225800181'u32].initBigInt
  #echo y shr 16

  #let two = 2.initBigInt
  #let n = initBigInt "19482118660833131143565059488889132062536031277944370802080045650318995799224424488550052744512926453902359616090610097833707910217541850445599669546171445"
  #for i in countdown(n, two):
  #  echo i
