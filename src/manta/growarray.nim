import ./[array, uncheckedindex]

type GrowArray*[T] = object
  ## growable wrapper over `Array[T]`, basically the same as `seq[T]`
  length: int
  data: Array[T]

# basic array procs:

proc len*[T](x: GrowArray[T]): int {.inline.} =
  x.length

proc `[]`*[T](x: GrowArray[T], i: UncheckedIndex): lent T {.inline.} =
  x.data[int i]

proc `[]`*[T](x: var GrowArray[T], i: UncheckedIndex): var T {.inline.} =
  x.data[int i]

proc `[]=`*[T](x: var GrowArray[T], i: UncheckedIndex, val: sink T) {.inline.} =
  x.data[int i] = val

proc `[]`*[T](x: GrowArray[T], i: int): lent T {.inline.} =
  rangeCheck i >= 0 and i < x.len
  x.data[i]

proc `[]`*[T](x: var GrowArray[T], i: int): var T {.inline.} =
  rangeCheck i >= 0 and i < x.len
  x.data[i]

proc `[]=`*[T](x: var GrowArray[T], i: int, val: sink T) {.inline.} =
  rangeCheck i >= 0 and i < x.len
  x.data[i] = val

iterator items*[T](x: GrowArray[T]): T =
  let L = x.len
  for i in 0 ..< L:
    yield x.data[i]

iterator mitems*[T](x: var GrowArray[T]): var T =
  let L = x.len
  for i in 0 ..< L:
    yield x.data[i]

iterator pairs*[T](x: GrowArray[T]): (int, T) =
  let L = x.len
  for i in 0 ..< L:
    yield (i, x.data[i])

iterator mpairs*[T](x: var GrowArray[T]): (int, var T) =
  let L = x.len
  for i in 0 ..< L:
    yield (i, x.data[i])

proc initGrowArrayUninit*[T](length: int): GrowArray[T] {.inline.} =
  result = GrowArray[T](length: length, data: initArrayUninit[T](length))

proc initGrowArrayOfCap*[T](cap: int = 4): GrowArray[T] {.inline.} =
  result = GrowArray[T](length: 0, data: initArrayUninit[T](cap))

proc initGrowArray*[T](length: int): GrowArray[T] =
  result = GrowArray[T](length: length, data: initArray[T](length))

proc toGrowArray*[T](arr: sink Array[T]): GrowArray[T] =
  result = GrowArray[T](length: arr.len, data: arr)

proc toGrowArray*[T](arr: openarray[T]): GrowArray[T] =
  result = GrowArray[T](length: arr.len, data: toArray[T](arr))

template toOpenArray*[T](x: GrowArray[T], first, last: int): auto =
  x.data.toOpenArray(first, last)

proc `$`*[T](x: GrowArray[T]): string =
  mixin `$`
  result = "["
  var firstElement = true
  for value in items(x):
    if firstElement:
      firstElement = false
    else:
      result.add(", ")

    when value isnot string and value isnot seq and compiles(value.isNil):
      # this branch should not be necessary
      if value.isNil:
        result.add "nil"
      else:
        result.addQuoted(value)
    else:
      result.addQuoted(value)
  result.add("]")

proc `==`*[T](a, b: GrowArray[T]): bool =
  let len = a.len
  if len != b.len: return false
  for i in 0 ..< len:
    if a[UncheckedIndex(i)] != b[UncheckedIndex(i)]: return false
  true

import hashes

proc hash*[T](a: GrowArray[T]): Hash =
  mixin hash
  result = result !& hash a.len
  for i in 0 ..< a.len:
    result = result !& hash a[UncheckedIndex(i)]
  result = !$ result

# growable functionality:

proc capacity*[T](a: GrowArray[T]): int {.inline.} =
  result = a.data.len

proc setCapacity*[T](a: var GrowArray[T], cap: int) =
  # does not check if cap == a.capacity
  let L = a.len
  var b = initArrayUninit[T](cap)
  for i in 0 ..< L:
    b[i] = move(a[i])
  a = GrowArray[T](length: L, data: move(b))

proc newSize(old: int): int {.inline.} =
  # copied from nim
  if old <= 0: result = 4
  elif old <= high(int16): result = old * 2
  else: result = old div 2 + old # for large arrays * 3/2 is better

proc setLen*[T](a: var GrowArray[T], newLen: int) =
  let oldLen = a.length
  if newLen < oldLen:
    for i in newLen ..< oldLen:
      a.data[UncheckedIndex(i)] = default(T)
  elif newLen > a.capacity:
    setCapacity(a, max(newSize(oldLen), newLen))
    for i in oldLen + 1 ..< newLen:
      a.data[UncheckedIndex(i)] = default(T)
  a.length = newLen

proc setLenUninit*[T](a: var GrowArray[T], newLen: int) {.inline.} =
  let oldLen = a.length
  if newLen > a.capacity:
    setCapacity(a, max(newSize(oldLen), newLen))
  a.length = newLen

proc add*[T](a: var GrowArray[T], item: sink T) =
  let initialLen = a.len
  setLenUninit(a, initialLen + 1)
  a[UncheckedIndex(initialLen)] = item

proc del*[T](a: var GrowArray[T], i: int) =
  swap(a[UncheckedIndex(i)], a[UncheckedIndex(a.len - 1)])
  setLen(a, a.len - 1)

proc pop*[T](a: var GrowArray[T]): T =
  result = default(T)
  swap(result, a[UncheckedIndex(a.len - 1)])
  setLenUninit(a, a.len - 1)

# missing: splice operations, so also insert/delete
