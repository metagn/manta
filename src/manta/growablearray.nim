import ./[array, uncheckedindex]

type GrowableArray*[T] = object
  ## growable wrapper over `Array[T]`, basically the same as `seq[T]`
  length: int
  data: Array[T]

# basic array procs:

proc len*[T](x: GrowableArray[T]): int {.inline.} =
  x.length

proc `[]`*[T](x: GrowableArray[T], i: UncheckedIndex): lent T {.inline.} =
  x.data[int i]

proc `[]`*[T](x: var GrowableArray[T], i: UncheckedIndex): var T {.inline.} =
  x.data[int i]

proc `[]=`*[T](x: var GrowableArray[T], i: UncheckedIndex, val: sink T) {.inline.} =
  x.data[int i] = val

proc `[]`*[T](x: GrowableArray[T], i: int): lent T {.inline.} =
  rangeCheck i >= 0 and i < x.len
  x.data[i]

proc `[]`*[T](x: var GrowableArray[T], i: int): var T {.inline.} =
  rangeCheck i >= 0 and i < x.len
  x.data[i]

proc `[]=`*[T](x: var GrowableArray[T], i: int, val: sink T) {.inline.} =
  rangeCheck i >= 0 and i < x.len
  x.data[i] = val

iterator items*[T](x: GrowableArray[T]): T =
  let L = x.len
  for i in 0 ..< L:
    yield x.data[i]

iterator mitems*[T](x: var GrowableArray[T]): var T =
  let L = x.len
  for i in 0 ..< L:
    yield x.data[i]

iterator pairs*[T](x: GrowableArray[T]): (int, T) =
  let L = x.len
  for i in 0 ..< L:
    yield (i, x.data[i])

iterator mpairs*[T](x: var GrowableArray[T]): (int, var T) =
  let L = x.len
  for i in 0 ..< L:
    yield (i, x.data[i])

proc newGrowableArrayUninit*[T](length: int): GrowableArray[T] {.inline.} =
  result = GrowableArray[T](length: length, data: newArrayUninit[T](length))

proc newGrowableArrayOfCap*[T](cap: int = 4): GrowableArray[T] {.inline.} =
  result = GrowableArray[T](length: 0, data: newArrayUninit[T](cap))

proc newGrowableArray*[T](length: int): GrowableArray[T] =
  result = GrowableArray[T](length: length, data: newArray[T](length))

proc toGrowableArray*[T](arr: openarray[T]): GrowableArray[T] =
  result = GrowableArray[T](length: arr.len, data: toArray[T](arr))

template toOpenArray*[T](x: GrowableArray[T], first, last: int): auto =
  x.data.toOpenArray(first, last)

proc `$`*[T](x: GrowableArray[T]): string =
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

proc `==`*[T](a, b: GrowableArray[T]): bool =
  let len = a.len
  if len != b.len: return false
  for i in 0 ..< len:
    if a[UncheckedIndex(i)] != b[UncheckedIndex(i)]: return false
  true

import hashes

proc hash*[T](a: GrowableArray[T]): Hash =
  mixin hash
  result = result !& hash a.len
  for i in 0 ..< a.len:
    result = result !& hash a[UncheckedIndex(i)]
  result = !$ result

# growable functionality:

proc capacity*[T](a: GrowableArray[T]): int {.inline.} =
  result = a.data.len

proc setCapacity*[T](a: var GrowableArray[T], cap: int) =
  # does not check if cap == a.capacity
  let L = a.len
  var b = newArrayUninit[T](cap)
  for i in 0 ..< L:
    b[i] = move(a[i])
  a = GrowableArray[T](length: L, data: move(b))

proc newSize(old: int): int {.inline.} =
  # copied from nim
  if old <= 0: result = 4
  elif old <= high(int16): result = old * 2
  else: result = old div 2 + old # for large arrays * 3/2 is better

proc setLen*[T](a: var GrowableArray[T], newLen: int) =
  let oldLen = a.length
  if newLen < oldLen:
    for i in newLen ..< oldLen:
      a.data[UncheckedIndex(i)] = default(T)
  elif newLen > a.capacity:
    setCapacity(a, max(newSize(oldLen), newLen))
    for i in oldLen + 1 ..< newLen:
      a.data[UncheckedIndex(i)] = default(T)
  a.length = newLen

proc setLenUninit*[T](a: var GrowableArray[T], newLen: int) {.inline.} =
  let oldLen = a.length
  if newLen > a.capacity:
    setCapacity(a, max(newSize(oldLen), newLen))
  a.length = newLen

proc add*[T](a: var GrowableArray[T], item: sink T) =
  let initialLen = a.len
  setLenUninit(a, initialLen + 1)
  a[UncheckedIndex(initialLen)] = item

proc del*[T](a: var GrowableArray[T], i: int) =
  swap(a[UncheckedIndex(i)], a[UncheckedIndex(a.len - 1)])
  setLen(a, a.len - 1)

proc pop*[T](a: var GrowableArray[T]): T =
  result = default(T)
  swap(result, a[UncheckedIndex(a.len - 1)])
  setLenUninit(a, a.len - 1)

# missing: splice operations, so also insert/delete
