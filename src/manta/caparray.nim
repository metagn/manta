import ./[array, uncheckedindex]

type
  CapArrayObj[T] {.byref.} = object
    length, cap: int
    data: UncheckedArray[T]
  CapArray*[T] = object
    ## growable array that stores cap in heap, pointer sized
    ## reference semantics until resize, in which case original is destroyed
    impl: ref CapArrayObj[T]

template uninitCapArrObj[T](arr: var ref CapArrayObj[T], c, L: int): untyped =
  # unsafeNew zeroes memory, so this is not really "uninitialized"
  # different story if default(T) is nonzero though
  unsafeNew(arr, sizeof(arr.length) + sizeof(arr.cap) + c * sizeof(T))
  arr.length = L
  arr.cap = c

when defined(nimPreviewNonVarDestructor) and defined(gcDestructors):
  # needs `CapArrayObj` to be `byref`, or at least the parameter
  proc `=destroy`*[T](arr: CapArrayObj[T]) =
    for i in 0 ..< arr.length:
      {.cast(raises: []).}:
        `=destroy`(arr.data[i])
else:
  {.push warning[Deprecated]: off.}
  proc `=destroy`*[T](arr: var CapArrayObj[T]) =
    for i in 0 ..< arr.length:
      {.cast(raises: []).}:
        `=destroy`(arr.data[i])
  {.pop.}

proc `=wasMoved`*[T](arr: var CapArrayObj[T]) {.inline.} =
  arr.length = 0
  arr.cap = 0

proc `=wasMoved`*[T](arr: var CapArray[T]) {.inline, nodestroy.} =
  arr.impl = nil

proc `=trace`*[T](arr: var CapArrayObj[T]; env: pointer) =
  for i in 0 ..< arr.length:
    `=trace`(arr.data[i], env)

proc `=trace`*[T](arr: var CapArray[T]; env: pointer) =
  if not arr.impl.isNil:
    for i in 0 ..< arr.impl.length:
      `=trace`(arr.impl.data[i], env)

# basic array procs:

proc len*[T](x: CapArray[T]): int {.inline.} =
  if x.impl.isNil: 0
  else: x.impl.length

proc `[]`*[T](x: CapArray[T], i: UncheckedIndex): lent T {.inline.} =
  x.impl.data[int i]

proc `[]`*[T](x: var CapArray[T], i: UncheckedIndex): var T {.inline.} =
  x.impl.data[int i]

proc `[]=`*[T](x: CapArray[T], i: UncheckedIndex, val: sink T) {.inline.} =
  x.impl.data[int i] = val

proc `[]`*[T](x: CapArray[T], i: int): lent T {.inline.} =
  rangeCheck i >= 0 and i < x.len
  x.impl.data[i]

proc `[]`*[T](x: var CapArray[T], i: int): var T {.inline.} =
  rangeCheck i >= 0 and i < x.len
  x.impl.data[i]

proc `[]=`*[T](x: var CapArray[T], i: int, val: sink T) {.inline.} =
  rangeCheck i >= 0 and i < x.len
  x.impl.data[i] = val

iterator items*[T](x: CapArray[T]): T =
  let L = x.len
  for i in 0 ..< L:
    yield x.impl.data[i]

iterator mitems*[T](x: var CapArray[T]): var T =
  let L = x.len
  for i in 0 ..< L:
    yield x.impl.data[i]

iterator pairs*[T](x: CapArray[T]): (int, T) =
  let L = x.len
  for i in 0 ..< L:
    yield (i, x.impl.data[i])

iterator mpairs*[T](x: var CapArray[T]): (int, var T) =
  let L = x.len
  for i in 0 ..< L:
    yield (i, x.impl.data[i])

proc newCapArrayUninit*[T](length: int): CapArray[T] {.inline.} =
  uninitCapArrObj(result.impl, length, length)

proc newCapArrayOfCap*[T](cap: int = 4): CapArray[T] {.inline.} =
  uninitCapArrObj(result.impl, cap, 0)

proc newCapArray*[T](length: int): CapArray[T] =
  uninitCapArrObj(result.impl, length, length)
  for i in 0 ..< length:
    result.impl.data[i] = default(T)

proc toCapArray*[T](arr: openarray[T]): CapArray[T] =
  result = newCapArray[T](arr.len)
  for i in 0 ..< arr.len:
    result.impl.data[i] = arr[i]

proc copy*[T](arr: CapArray[T]): CapArray[T] =
  if arr.impl.isNil: return arr
  uninitCapArrObj(result.impl, arr.impl.cap, arr.impl.length)
  for i in 0 ..< arr.len:
    result[i] = arr[i]

template toOpenArray*[T](x: CapArray[T], first, last: int): auto =
  x.impl.data.toOpenArray(first, last)

proc `$`*[T](x: CapArray[T]): string =
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

proc `==`*[T](a, b: CapArray[T]): bool =
  let len = a.len
  if len != b.len: return false
  for i in 0 ..< len:
    if a[UncheckedIndex(i)] != b[UncheckedIndex(i)]: return false
  true

import hashes

proc hash*[T](a: CapArray[T]): Hash =
  mixin hash
  result = result !& hash a.len
  for i in 0 ..< a.len:
    result = result !& hash a[UncheckedIndex(i)]
  result = !$ result

# growable functionality:

proc capacity*[T](a: CapArray[T]): int {.inline.} =
  result = a.impl.cap

proc setCapacity*[T](a: var CapArray[T], cap: int) =
  # does not check if cap == a.capacity
  let L = a.len
  var b: CapArray[T]
  uninitCapArrObj(b.impl, cap, L)
  for i in 0 ..< L:
    b[i] = move(a[i])
  a = move b

proc newSize(old: int): int {.inline.} =
  # copied from nim
  if old <= 0: result = 4
  elif old <= high(int16): result = old * 2
  else: result = old div 2 + old # for large arrays * 3/2 is better

proc setLen*[T](a: var CapArray[T], newLen: int) =
  let oldLen = a.impl.length
  if newLen < oldLen:
    for i in newLen ..< oldLen:
      a.impl.data[i] = default(T)
  elif newLen > a.capacity:
    setCapacity(a, max(newSize(oldLen), newLen))
    for i in oldLen + 1 ..< newLen:
      a.impl.data[i] = default(T)
  a.impl.length = newLen

proc setLenUninit*[T](a: var CapArray[T], newLen: int) {.inline.} =
  let oldLen = a.impl.length
  if newLen > a.capacity:
    setCapacity(a, max(newSize(oldLen), newLen))
  a.impl.length = newLen

proc add*[T](a: var CapArray[T], item: sink T) =
  let initialLen = a.len
  setLenUninit(a, initialLen + 1)
  a[UncheckedIndex(initialLen)] = item

proc del*[T](a: var CapArray[T], i: int) =
  swap(a[UncheckedIndex(i)], a[UncheckedIndex(a.len - 1)])
  setLen(a, a.len - 1)

proc pop*[T](a: var CapArray[T]): T =
  result = default(T)
  swap(result, a[UncheckedIndex(a.len - 1)])
  setLenUninit(a, a.len - 1)

# missing: splice operations, so also insert/delete
