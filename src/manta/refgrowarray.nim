import ./[array, uncheckedindex]

type
  GrowArrayObj[T] = object
    length, cap: int
    data: UncheckedArray[T]
  RefGrowArray*[T] = ref GrowArrayObj[T]
    ## growable array with reference semantics, pointer sized

template uninitGrowArrObj[T](arr: var ref GrowArrayObj[T], c, L: int): untyped =
  unsafeNew(arr, sizeof(arr.length) + sizeof(arr.cap) + c * sizeof(T))
  arr.length = L
  arr.cap = c

when defined(nimPreviewNonVarDestructor) and defined(gcDestructors):
  # needs `ArrayObj` to be `byref`, or at least the parameter
  proc `=destroy`*[T](arr: GrowArrayObj[T]) =
    for i in 0 ..< arr.length:
      {.cast(raises: []).}:
        `=destroy`(arr.data[i])
else:
  {.push warning[Deprecated]: off.}
  proc `=destroy`*[T](arr: var GrowArrayObj[T]) =
    for i in 0 ..< arr.length:
      {.cast(raises: []).}:
        `=destroy`(arr.data[i])
  {.pop.}

proc `=wasMoved`*[T](arr: var GrowArrayObj[T]) {.inline.} =
  arr.length = 0
  arr.cap = 0

proc `=trace`*[T](arr: var GrowArrayObj[T]; env: pointer) =
  for i in 0 ..< arr.length:
    `=trace`(arr.data[i], env)

# basic array procs:

proc len*[T](x: RefGrowArray[T]): int {.inline.} =
  if x.isNil: 0
  else: x.length

proc `[]`*[T](x: RefGrowArray[T], i: UncheckedIndex): lent T {.inline.} =
  x.data[int i]

proc `[]`*[T](x: var RefGrowArray[T], i: UncheckedIndex): var T {.inline.} =
  x.data[int i]

proc `[]=`*[T](x: RefGrowArray[T], i: UncheckedIndex, val: sink T) {.inline.} =
  x.data[int i] = val

proc `[]`*[T](x: RefGrowArray[T], i: int): lent T {.inline.} =
  rangeCheck i >= 0 and i < x.len
  x.data[i]

proc `[]`*[T](x: var RefGrowArray[T], i: int): var T {.inline.} =
  rangeCheck i >= 0 and i < x.len
  x.data[i]

proc `[]=`*[T](x: var RefGrowArray[T], i: int, val: sink T) {.inline.} =
  rangeCheck i >= 0 and i < x.len
  x.data[i] = val

iterator items*[T](x: RefGrowArray[T]): T =
  let L = x.len
  for i in 0 ..< L:
    yield x.data[i]

iterator mitems*[T](x: var RefGrowArray[T]): var T =
  let L = x.len
  for i in 0 ..< L:
    yield x.data[i]

iterator pairs*[T](x: RefGrowArray[T]): (int, T) =
  let L = x.len
  for i in 0 ..< L:
    yield (i, x.data[i])

iterator mpairs*[T](x: var RefGrowArray[T]): (int, var T) =
  let L = x.len
  for i in 0 ..< L:
    yield (i, x.data[i])

proc newGrowArrayUninit*[T](length: int): RefGrowArray[T] {.inline.} =
  uninitGrowArrObj(result, length, length)

proc newGrowArrayOfCap*[T](cap: int = 4): RefGrowArray[T] {.inline.} =
  uninitGrowArrObj(result, cap, 0)

proc newGrowArray*[T](length: int): RefGrowArray[T] =
  uninitGrowArrObj(result, length, length)
  for i in 0 ..< length:
    result.data[i] = default(T)

proc toGrowArray*[T](arr: openarray[T]): RefGrowArray[T] =
  result = newGrowArray[T](arr.len)
  for i in 0 ..< arr.len:
    result.data[i] = arr[i]

template toOpenArray*[T](x: RefGrowArray[T], first, last: int): auto =
  x.data.toOpenArray(first, last)

proc `$`*[T](x: RefGrowArray[T]): string =
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

proc `==`*[T](a, b: RefGrowArray[T]): bool =
  let len = a.len
  if len != b.len: return false
  for i in 0 ..< len:
    if a[UncheckedIndex(i)] != b[UncheckedIndex(i)]: return false
  true

import hashes

proc hash*[T](a: RefGrowArray[T]): Hash =
  mixin hash
  result = result !& hash a.len
  for i in 0 ..< a.len:
    result = result !& hash a[UncheckedIndex(i)]
  result = !$ result

# growable functionality:

proc capacity*[T](a: RefGrowArray[T]): int {.inline.} =
  result = a.cap

proc setCapacity*[T](a: var RefGrowArray[T], cap: int) =
  # does not check if cap == a.capacity
  let L = a.len
  var b: RefGrowArray[T]
  uninitGrowArrObj(b, cap, L)
  for i in 0 ..< L:
    b[i] = move(a[i])
  a = move b

proc newSize(old: int): int {.inline.} =
  # copied from nim
  if old <= 0: result = 4
  elif old <= high(int16): result = old * 2
  else: result = old div 2 + old # for large arrays * 3/2 is better

proc setLen*[T](a: var RefGrowArray[T], newLen: int) =
  let oldLen = a.length
  if newLen < oldLen:
    for i in newLen ..< oldLen:
      a.data[UncheckedIndex(i)] = default(T)
  elif newLen > a.capacity:
    setCapacity(a, max(newSize(oldLen), newLen))
    for i in oldLen + 1 ..< newLen:
      a.data[UncheckedIndex(i)] = default(T)
  a.length = newLen

proc setLenUninit*[T](a: var RefGrowArray[T], newLen: int) {.inline.} =
  let oldLen = a.length
  if newLen > a.capacity:
    setCapacity(a, max(newSize(oldLen), newLen))
  a.length = newLen

proc add*[T](a: var RefGrowArray[T], item: sink T) =
  let initialLen = a.len
  setLenUninit(a, initialLen + 1)
  a[UncheckedIndex(initialLen)] = item

proc del*[T](a: var RefGrowArray[T], i: int) =
  swap(a[UncheckedIndex(i)], a[UncheckedIndex(a.len - 1)])
  setLen(a, a.len - 1)

proc pop*[T](a: var RefGrowArray[T]): T =
  result = default(T)
  swap(result, a[UncheckedIndex(a.len - 1)])
  setLenUninit(a, a.len - 1)

# missing: splice operations, so also insert/delete
