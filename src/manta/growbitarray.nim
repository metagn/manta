import ./uncheckedindex

type GrowBitArray* = object
  ## growable version of BitArray
  ## uses 3 words, with 2 words for stack optimization
  len, cap: int
  data: pointer

type HeapDataImpl = ref UncheckedArray[byte]

const maxStackLen = 2 * sizeof(int) * 8

template byteCount(len: int): int = (len + 7) div 8
template byteIndex(ind: UncheckedIndex): int = ind.int div 8
template byteOffset(ind: UncheckedIndex): int = ind.int mod 8
template byteMask(ind: UncheckedIndex): byte = 1.byte shl byteOffset(ind)
template wordIndex(ind: UncheckedIndex): int = ind.int div (8 * sizeof(int))
template wordOffset(ind: UncheckedIndex): int = ind.int mod (8 * sizeof(int))
template wordMask(ind: UncheckedIndex): uint = 1.uint shl wordOffset(ind)

template isHeap(arr: GrowBitArray): bool =
  arr.len > maxStackLen

when defined(nimAllowNonVarDestructor) and defined(gcDestructors):
  proc `=destroy`*(arr: GrowBitArray) =
    if arr.isHeap:
      `=destroy`(cast[HeapDataImpl](arr.data))
else:
  proc `=destroy`*(arr: var GrowBitArray) =
    if arr.isHeap:
      `=destroy`(cast[ptr HeapDataImpl](addr arr.data)[])

proc `=wasMoved`*(arr: var GrowBitArray) =
  arr.len = 0
  arr.cap = 0
  arr.data = nil

proc `=trace`*(arr: var GrowBitArray; env: pointer) =
  if arr.isHeap:
    `=trace`(cast[ptr HeapDataImpl](addr arr.data)[], env)

proc `=sink`*(dest: var GrowBitArray, src: GrowBitArray) =
  dest.len = src.len
  dest.cap = src.cap
  if src.isHeap:
    `=sink`(cast[ptr HeapDataImpl](addr dest.data)[], cast[HeapDataImpl](src.data))
  else:
    dest.data = src.data

proc `=copy`*(dest: var GrowBitArray, src: GrowBitArray) =
  dest.len = src.len
  dest.cap = src.cap
  if src.isHeap:
    let byteLen = byteCount(src.len)
    unsafeNew(cast[ptr HeapDataImpl](addr dest.data)[], byteLen)
    copyMem(dest.data, src.data, byteLen)
  else:
    dest.data = src.data

proc `=dup`*(arr: GrowBitArray): GrowBitArray =
  if arr.isHeap:
    result = GrowBitArray(len: arr.len, cap: arr.cap, data: nil)
    let byteLen = byteCount(result.len)
    unsafeNew(cast[ptr HeapDataImpl](addr result.data)[], byteLen)
    copyMem(result.data, arr.data, byteLen)
  else:
    result = arr

proc len*(x: GrowBitArray): int {.inline.} = x.len

proc `[]`*(arr: GrowBitArray, i: UncheckedIndex): bool {.inline.} =
  if arr.isHeap:
    let data = cast[HeapDataImpl](arr.data)
    bool((data[byteIndex(i)] shr byteOffset(i)) and 1)
  else:
    let data = if bool(wordIndex(i)): cast[uint](arr.data) else: cast[uint](arr.cap)
    bool((data shr wordOffset(i)) and 1)

proc `[]`*(arr: GrowBitArray, i: int): bool {.inline.} =
  rangeCheck i >= 0 and i < arr.len
  arr[UncheckedIndex i]

template contains*(arr: GrowBitArray, i: int | UncheckedIndex): bool =
  arr[i]

proc incl*(arr: var GrowBitArray, i: UncheckedIndex) {.inline.} =
  if arr.isHeap:
    let data = cast[HeapDataImpl](arr.data)
    data[byteIndex(i)] = data[byteIndex(i)] or byteMask(i)
  else:
    let data = if bool(wordIndex(i)): cast[ptr uint](addr arr.data) else: cast[ptr uint](addr arr.cap)
    data[] = data[] or wordMask(i)

proc excl*(arr: var GrowBitArray, i: UncheckedIndex) {.inline.} =
  if arr.isHeap:
    let data = cast[HeapDataImpl](arr.data)
    data[byteIndex(i)] = data[byteIndex(i)] and not byteMask(i)
  else:
    let data = if bool(wordIndex(i)): cast[ptr uint](addr arr.data) else: cast[ptr uint](addr arr.cap)
    data[] = data[] and not wordMask(i)

proc `[]=`*(arr: var GrowBitArray, i: UncheckedIndex, val: bool) {.inline.} =
  if val:
    incl(arr, i)
  else:
    excl(arr, i)

proc incl*(arr: var GrowBitArray, i: int) {.inline.} =
  rangeCheck i >= 0 and i < arr.len
  arr.incl(UncheckedIndex i)

proc excl*(arr: var GrowBitArray, i: int, val: bool) {.inline.} =
  rangeCheck i >= 0 and i < arr.len
  arr.excl(UncheckedIndex i)

proc `[]=`*(arr: var GrowBitArray, i: int, val: bool) {.inline.} =
  rangeCheck i >= 0 and i < arr.len
  arr[UncheckedIndex i] = val

iterator items*(arr: GrowBitArray): bool =
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
  elif wordIndex(UncheckedIndex(L - 1)) < 1:
    var b = cast[uint](arr.cap)
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
  else:
    var b = cast[uint](arr.cap)
    let fullBytes = byteIndex(L.UncheckedIndex)
    for i in 0 ..< sizeof(int):
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
    b = cast[uint](arr.data)
    for i in sizeof(uint) ..< fullBytes:
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

proc initGrowBitArrayUninit*(length: int): GrowBitArray {.inline.} =
  result = GrowBitArray(len: length)
  if length > maxStackLen:
    result.cap = byteCount(length)
    unsafeNew(cast[ptr HeapDataImpl](addr result.data)[], result.cap)

proc initGrowBitArray*(length: int): GrowBitArray =
  result = GrowBitArray(len: length)
  if length > maxStackLen:
    result.cap = byteCount(length)
    unsafeNew(cast[ptr HeapDataImpl](addr result.data)[], result.cap)
    zeroMem(result.data, result.cap)
  else:
    result.cap = 0
    result.data = nil

proc toGrowBitArray*(arr: openarray[bool]): GrowBitArray =
  result = initGrowBitArrayUninit(arr.len)
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
    data = cast[ptr UncheckedArray[byte]](addr result.cap)
    when cpuEndian == bigEndian:
      impl(true)
  when cpuEndian == littleEndian:
    impl(false)

proc `$`*(x: GrowBitArray): string =
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

proc `==`*(a, b: GrowBitArray): bool =
  let len = a.len
  if len != b.len: return false
  if len > maxStackLen:
    if a.data == b.data: return true
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
  elif wordIndex(UncheckedIndex(len - 1)) > 0:
    a.cap == b.cap and
      truncWord(cast[uint](a.data), len) == truncWord(cast[uint](b.data), len)
  else:
    truncWord(cast[uint](a.cap), len) == truncWord(cast[uint](b.cap), len)

import hashes

proc hash*(a: GrowBitArray): Hash =
  let len = a.len
  result = result !& hash len
  if len > maxStackLen:
    let data = cast[ptr UncheckedArray[byte]](a.data)
    let fullBytes = byteIndex(len.UncheckedIndex)
    result = result !& hash data.toOpenArray(0, fullBytes - 1)
    let offset = byteOffset(len.UncheckedIndex)
    if offset != 0:
      result = result !& hash(data[fullBytes] and lastByteMasks[offset])
  elif wordIndex(UncheckedIndex(len - 1)) > 0:
    result = result !& hash cast[uint](a.cap)
    result = result !& hash truncWord(cast[uint](a.data), len)
  else:
    result = result !& hash truncWord(cast[uint](a.cap), len)
  result = !$ result

# growable functionality:
# XXX suspicious

proc capacity*(a: GrowBitArray): int {.inline.} =
  if a.isHeap:
    result = a.cap # in bytes
  else:
    result = 0

proc moveToStack(a: var GrowBitArray) =
  let src = cast[HeapDataImpl](a.data)
  when cpuEndian == littleEndian:
    moveMem(addr a.cap, cast[pointer](src), 2 * sizeof(int))
  else:
    let dest = cast[ptr UncheckedArray[byte]](addr a.cap)
    for i in 0 ..< 2 * sizeof(int):
      dest[2 * sizeof(int) - i - 1] = src[i]
  `=destroy`(src)

proc moveToHeap(a: var GrowBitArray, dest: ptr UncheckedArray[byte]) =
  when cpuEndian == littleEndian:
    moveMem(dest, addr a.cap, 2 * sizeof(int))
  else:
    var srcData = [cast[uint](a.cap), cast[uint](a.data)]
    moveMem(dest, addr srcData, 2 * sizeof(int))

proc newSize(old: int): int {.inline.} =
  # copied from nim
  if old <= 8: result = 8
  elif old <= high(int16): result = old * 2
  else: result = old div 2 + old # for large arrays * 3/2 is better

proc setLen*(a: var GrowBitArray, newLen: int) =
  let oldLen = a.len
  if newLen > maxStackLen:
    var newHeapLen = byteCount(newLen)
    if oldLen > maxStackLen:
      let oldHeapLen = a.cap # byteCount(oldLen)
      if newHeapLen > oldHeapLen:
        let x = newSize(oldHeapLen)
        if x > newHeapLen: newHeapLen = x
        var newData: HeapDataImpl
        unsafeNew(newData, newHeapLen)
        zeroMem(cast[pointer](newData), newHeapLen)
        moveMem(cast[pointer](newData), cast[pointer](a.data), oldHeapLen)
        a.data = cast[pointer](newData)
        a.cap = newHeapLen
      elif newLen < oldLen:
        for i in newLen ..< oldLen:
          excl a, UncheckedIndex(i)
    else:
      var newData: HeapDataImpl
      unsafeNew(newData, newHeapLen)
      zeroMem(cast[pointer](newData), newHeapLen)
      moveToHeap(a, cast[ptr UncheckedArray[byte]](newData))
      a.data = cast[pointer](newData)
      a.cap = newHeapLen
    a.len = newLen
  else:
    a.len = newLen
    if oldLen > maxStackLen:
      moveToStack(a)
      for i in newLen ..< maxStackLen:
        excl a, UncheckedIndex(i)
    elif newLen < oldLen:
      for i in newLen ..< oldLen:
        excl a, UncheckedIndex(i)

proc setLenUninit*(a: var GrowBitArray, newLen: int) {.inline.} =
  let oldLen = a.len
  if newLen > maxStackLen:
    var newHeapLen = byteCount(newLen)
    if oldLen > maxStackLen:
      let oldHeapLen = a.cap # byteCount(oldLen)
      if newHeapLen > oldHeapLen:
        let x = newSize(oldHeapLen)
        if x > newHeapLen: newHeapLen = x
        var newData: HeapDataImpl
        unsafeNew(newData, newHeapLen)
        moveMem(cast[pointer](newData), cast[pointer](a.data), oldHeapLen)
        a.data = cast[pointer](newData)
        a.cap = newHeapLen
    else:
      var newData: HeapDataImpl
      unsafeNew(newData, newHeapLen)
      moveToHeap(a, cast[ptr UncheckedArray[byte]](newData))
      a.data = cast[pointer](newData)
      a.cap = newHeapLen
  else:
    if oldLen > maxStackLen:
      moveToStack(a)
  a.len = newLen

proc add*(a: var GrowBitArray, item: bool) =
  let initialLen = a.len
  setLenUninit(a, initialLen + 1)
  a[UncheckedIndex(initialLen)] = item

proc del*(a: var GrowBitArray, i: int) =
  let last = a[UncheckedIndex(a.len - 1)]
  a[UncheckedIndex(i)] = last
  setLen(a, a.len - 1)

proc pop*(a: var GrowBitArray): bool =
  result = a[UncheckedIndex(a.len - 1)]
  setLen(a, a.len - 1)

# missing: splice operations, so also insert/delete

