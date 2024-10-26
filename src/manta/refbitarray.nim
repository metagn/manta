import ./uncheckedindex

type
  BitArrayObj {.byref.} = object
    length: int
    data: UncheckedArray[byte]
  RefBitArray* = object
    ## ref array optimized for `bool`
    ## pointer sized, all data including length is stored in heap
    impl: ref BitArrayObj

template uninitBitArrObj(arr: var ref BitArrayObj, L: int): untyped =
  unsafeNew(arr, sizeof(arr.length) + L)
  arr.length = L

when defined(nimPreviewNonVarDestructor) and defined(gcDestructors):
  # needs `ArrayObj` to be `byref`, or at least the parameter
  proc `=destroy`*(arr: BitArrayObj) {.inline.} = discard
else:
  {.push warning[Deprecated]: off.}
  proc `=destroy`*(arr: var BitArrayObj) {.inline.} = discard
  {.pop.}

proc `=wasMoved`*(arr: var BitArrayObj) {.inline.} =
  arr.length = 0

proc `=trace`*(arr: var BitArrayObj; env: pointer) {.inline.} = discard

template byteCount(len: int): int = (len + 7) div 8
template byteIndex(ind: UncheckedIndex): int = ind.int div 8
template byteOffset(ind: UncheckedIndex): int = ind.int mod 8
template byteMask(ind: UncheckedIndex): byte = 1.byte shl byteOffset(ind)

proc `=wasMoved`*(arr: var RefBitArray) {.inline, nodestroy.} =
  arr.impl = nil

proc len*(x: RefBitArray): int {.inline.} = x.impl.length

proc `[]`*(arr: RefBitArray, i: UncheckedIndex): bool {.inline.} =
  bool((arr.impl.data[byteIndex(i)] shr byteOffset(i)) and 1)

proc `[]`*(arr: RefBitArray, i: int): bool {.inline.} =
  rangeCheck i >= 0 and i < arr.len
  arr[UncheckedIndex i]

template contains*(arr: RefBitArray, i: int | UncheckedIndex): bool =
  arr[i]

proc incl*(arr: var RefBitArray, i: UncheckedIndex) {.inline.} =
  arr.impl.data[byteIndex(i)] = arr.impl.data[byteIndex(i)] or byteMask(i)

proc excl*(arr: var RefBitArray, i: UncheckedIndex) {.inline.} =
  arr.impl.data[byteIndex(i)] = arr.impl.data[byteIndex(i)] and not byteMask(i)

proc `[]=`*(arr: var RefBitArray, i: UncheckedIndex, val: bool) {.inline.} =
  if val:
    incl(arr, i)
  else:
    excl(arr, i)

proc incl*(arr: var RefBitArray, i: int) {.inline.} =
  rangeCheck i >= 0 and i < arr.len
  arr.incl(UncheckedIndex i)

proc excl*(arr: var RefBitArray, i: int, val: bool) {.inline.} =
  rangeCheck i >= 0 and i < arr.len
  arr.excl(UncheckedIndex i)

proc `[]=`*(arr: var RefBitArray, i: int, val: bool) {.inline.} =
  rangeCheck i >= 0 and i < arr.len
  arr[UncheckedIndex i] = val

iterator items*(arr: RefBitArray): bool =
  let L = arr.len
  let fullBytes = byteIndex(L.UncheckedIndex)
  for i in 0 ..< fullBytes:
    var b = arr.impl.data[i]
    yield bool(b and 1) # bit 1
    b = b shr 1
    yield bool(b and 1) # bit 2
    b = b shr 1
    yield bool(b and 1) # bit 3
    b = b shr 1
    yield bool(b and 1) # bit 4
    b = b shr 1
    yield bool(b and 1) # bit 5
    b = b shr 1
    yield bool(b and 1) # bit 6
    b = b shr 1
    yield bool(b and 1) # bit 7
    b = b shr 1
    yield bool(b and 1) # bit 8
  let offset = byteOffset(arr.len.UncheckedIndex)
  if offset != 0:
    var b = arr.impl.data[fullBytes]
    for i in 0 ..< offset:
      yield bool(b and 1)
      b = b shr 1

proc newBitArrayUninit*(length: int): RefBitArray {.inline.} =
  let heapLen = byteCount(length)
  uninitBitArrObj(result.impl, heapLen)

proc newBitArray*(length: int): RefBitArray =
  let heapLen = byteCount(length)
  uninitBitArrObj(result.impl, heapLen)
  zeroMem(addr result.impl.data, heapLen)

proc toBitArray*(arr: openarray[bool]): RefBitArray =
  result = newBitArrayUninit(arr.len)
  let fullBytes = byteIndex(arr.len.UncheckedIndex)
  for byteI in 0 ..< fullBytes:
    let i = byteI * 8
    result.impl.data[i] = arr[i].byte or
      (arr[i + 1].byte shl 1) or
      (arr[i + 2].byte shl 2) or
      (arr[i + 3].byte shl 3) or
      (arr[i + 4].byte shl 4) or
      (arr[i + 5].byte shl 5) or
      (arr[i + 6].byte shl 6) or
      (arr[i + 7].byte shl 7)
  let offset = byteOffset(arr.len.UncheckedIndex)
  if offset != 0:
    let start = fullBytes * 8
    var b = arr[start].byte
    for i in 1 ..< offset:
      b = b or (arr[start + i].byte shl i)
    result.impl.data[fullBytes] = b

proc `$`*(x: RefBitArray): string =
  result = "["
  var firstElement = true
  for value in items(x):
    if firstElement:
      firstElement = false
    else:
      result.add(", ")

    result.addQuoted(value)
  result.add("]")

const lastByteMasks = [0.byte, 0b1, 0b11, 0b111, 0b1111, 0b11111, 0b111111, 0b1111111, 0b11111111]

proc `==`*(a, b: RefBitArray): bool =
  let len = a.len
  if len != b.len: return false
  if cast[pointer](a.impl) == cast[pointer](b.impl):
    return true
  let fullBytes = byteIndex(len.UncheckedIndex)
  if not equalMem(addr a.impl.data, addr b.impl.data, fullBytes):
    return false
  let offset = byteOffset(len.UncheckedIndex)
  if offset != 0:
    if ((a.impl.data[fullBytes] xor b.impl.data[fullBytes]) and lastByteMasks[offset]) != 0:
      return false
  true

import hashes

proc hash*(a: RefBitArray): Hash =
  let len = a.len
  result = result !& hash len
  let fullBytes = byteIndex(len.UncheckedIndex)
  result = result !& hash (addr a.impl.data).toOpenArray(0, fullBytes - 1)
  let offset = byteOffset(len.UncheckedIndex)
  if offset != 0:
    result = result !& hash(a.impl.data[fullBytes] and lastByteMasks[offset])
  result = !$ result
