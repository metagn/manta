import ./uncheckedindex

type BitArray* = object
  ## array optimized for `bool`
  ## uses 2 words, second word is data if the length is less than or equal to word size,
  ## pointer to data if more
  len: int
  data: pointer

type HeapDataImpl = ref UncheckedArray[byte]

const maxStackLen = sizeof(int) * 8

template byteCount(len: int): int = (len + 7) div 8
template byteIndex(ind: UncheckedIndex): int = ind.int div 8
template byteOffset(ind: UncheckedIndex): int = ind.int mod 8
template byteMask(ind: UncheckedIndex): byte = 1.byte shl byteOffset(ind)
template wordOffset(ind: UncheckedIndex): int = ind.int mod (8 * sizeof(int))
template wordMask(ind: UncheckedIndex): uint = 1.uint shl wordOffset(ind)

template isHeap(arr: BitArray): bool =
  arr.len > maxStackLen

when defined(nimAllowNonVarDestructor) and defined(gcDestructors):
  proc `=destroy`*(arr: BitArray) =
    if arr.isHeap:
      `=destroy`(cast[HeapDataImpl](arr.data))
else:
  proc `=destroy`*(arr: var BitArray) =
    if arr.isHeap:
      `=destroy`(cast[ptr HeapDataImpl](addr arr.data)[])

proc `=wasMoved`*(arr: var BitArray) =
  arr.len = 0
  arr.data = nil

proc `=trace`*(arr: var BitArray; env: pointer) =
  if arr.isHeap:
    `=trace`(cast[ptr HeapDataImpl](addr arr.data)[], env)

proc `=sink`*(dest: var BitArray, src: BitArray) =
  dest.len = src.len
  if src.isHeap:
    `=sink`(cast[ptr HeapDataImpl](addr dest.data)[], cast[HeapDataImpl](src.data))
  else:
    dest.data = src.data

proc `=copy`*(dest: var BitArray, src: BitArray) =
  dest.len = src.len
  if src.isHeap:
    let byteLen = byteCount(src.len)
    unsafeNew(cast[ptr HeapDataImpl](addr dest.data)[], byteLen)
    copyMem(dest.data, src.data, byteLen)
  else:
    dest.data = src.data

proc `=dup`*(arr: BitArray): BitArray =
  if arr.isHeap:
    result = BitArray(len: arr.len, data: nil)
    let byteLen = byteCount(result.len)
    unsafeNew(cast[ptr HeapDataImpl](addr result.data)[], byteLen)
    copyMem(result.data, arr.data, byteLen)
  else:
    result = arr

proc len*(x: BitArray): int {.inline.} = x.len

proc `[]`*(arr: BitArray, i: UncheckedIndex): bool {.inline.} =
  if arr.isHeap:
    let data = cast[HeapDataImpl](arr.data)
    bool((data[byteIndex(i)] shr byteOffset(i)) and 1)
  else:
    let data = cast[uint](arr.data)
    bool((data shr int(i)) and 1)

proc `[]`*(arr: BitArray, i: int): bool {.inline.} =
  rangeCheck i >= 0 and i < arr.len
  arr[UncheckedIndex i]

template contains*(arr: BitArray, i: int | UncheckedIndex): bool =
  arr[i]

proc incl*(arr: var BitArray, i: UncheckedIndex) {.inline.} =
  if arr.isHeap:
    let data = cast[HeapDataImpl](arr.data)
    data[byteIndex(i)] = data[byteIndex(i)] or byteMask(i)
  else:
    let data = cast[uint](arr.data)
    arr.data = cast[pointer](data or wordMask(i))

proc excl*(arr: var BitArray, i: UncheckedIndex) {.inline.} =
  if arr.isHeap:
    let data = cast[HeapDataImpl](arr.data)
    data[byteIndex(i)] = data[byteIndex(i)] and not byteMask(i)
  else:
    let data = cast[uint](arr.data)
    arr.data = cast[pointer](data and not wordMask(i))

proc `[]=`*(arr: var BitArray, i: UncheckedIndex, val: bool) {.inline.} =
  if val:
    incl(arr, i)
  else:
    excl(arr, i)

proc incl*(arr: var BitArray, i: int) {.inline.} =
  rangeCheck i >= 0 and i < arr.len
  arr.incl(UncheckedIndex i)

proc excl*(arr: var BitArray, i: int, val: bool) {.inline.} =
  rangeCheck i >= 0 and i < arr.len
  arr.excl(UncheckedIndex i)

proc `[]=`*(arr: var BitArray, i: int, val: bool) {.inline.} =
  rangeCheck i >= 0 and i < arr.len
  arr[UncheckedIndex i] = val

iterator items*(arr: BitArray): bool =
  let L = arr.len
  if L > maxStackLen:
    let data = cast[HeapDataImpl](arr.data)
    let fullBytes = byteIndex(L.UncheckedIndex)
    for i in 0 ..< fullBytes:
      var b = data[i]
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
      var b = data[fullBytes]
      for i in 0 ..< offset:
        yield bool(b and 1)
        b = b shr 1
  else:
    var b = cast[uint](arr.data)
    let fullBytes = byteIndex(L.UncheckedIndex)
    for i in 0 ..< fullBytes:
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
      b = b shr 1
    let offset = byteOffset(arr.len.UncheckedIndex)
    if offset != 0:
      for i in 0 ..< offset:
        yield bool(b and 1)
        b = b shr 1

proc initBitArrayUninit*(length: int): BitArray {.inline.} =
  result = BitArray(len: length)
  if length > maxStackLen:
    unsafeNew(cast[ptr HeapDataImpl](addr result.data)[], byteCount(length))

proc initBitArray*(length: int): BitArray =
  result = BitArray(len: length)
  if length > maxStackLen:
    let heapLen = byteCount(length)
    unsafeNew(cast[ptr HeapDataImpl](addr result.data)[], heapLen)
    zeroMem(result.data, heapLen)
  else:
    result.data = nil

proc toBitArray*(arr: openarray[bool]): BitArray =
  result = initBitArrayUninit(arr.len)
  var data: ptr UncheckedArray[byte]
  template impl(useBigEndian: static bool) =
    let fullBytes = byteIndex(arr.len.UncheckedIndex)
    when useBigEndian:
      let realBytes = byteCount(arr.len)
    for byteI in 0 ..< fullBytes:
      let i = byteI * 8
      data[when useBigEndian: realBytes - byteI - 1 else: byteI] = arr[i].byte or
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
      data[when useBigEndian: 0 else: fullBytes] = b
  if arr.len > maxStackLen:
    data = cast[ptr UncheckedArray[byte]](result.data)
    when cpuEndian == bigEndian:
      impl(false)
  else:
    data = cast[ptr UncheckedArray[byte]](addr result.data)
    when cpuEndian == bigEndian:
      impl(true)
  when cpuEndian == littleEndian:
    impl(false)

proc `$`*(x: BitArray): string =
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
template truncWord(x: uint, L: int): uint =
  x shl L shr L

proc `==`*(a, b: BitArray): bool =
  let len = a.len
  if len != b.len: return false
  if a.data == b.data:
    return true
  elif len > maxStackLen:
    let fullBytes = byteIndex(len.UncheckedIndex)
    if not equalMem(a.data, b.data, fullBytes):
      return false
    let aData = cast[HeapDataImpl](a.data)
    let bData = cast[HeapDataImpl](b.data)
    let offset = byteOffset(len.UncheckedIndex)
    if offset != 0:
      if ((aData[fullBytes] xor bData[fullBytes]) and lastByteMasks[offset]) != 0:
        return false
    true
  else:
    truncWord(cast[uint](a.data), len) == truncWord(cast[uint](b.data), len)

import hashes

proc hash*(a: BitArray): Hash =
  let len = a.len
  result = result !& hash len
  if len > maxStackLen:
    let data = cast[ptr UncheckedArray[byte]](a.data)
    let fullBytes = byteIndex(len.UncheckedIndex)
    result = result !& hash data.toOpenArray(0, fullBytes - 1)
    let offset = byteOffset(len.UncheckedIndex)
    if offset != 0:
      result = result !& hash(data[fullBytes] and lastByteMasks[offset])
  else:
    result = result !& hash truncWord(cast[uint](a.data), len)
  result = !$ result
