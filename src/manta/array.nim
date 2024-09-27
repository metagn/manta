import ./arrayobj

type Array*[T] = object
  ## array with constant runtime length and value semantics
  impl: ref ArrayObj[T]

proc `=trace`*[T](arr: var Array[T]; env: pointer) =
  if not arr.impl.isNil:
    for i in 0 ..< arr.impl.length:
      `=trace`(arr.impl.data[i], env)

proc `=sink`*[T](dest: var Array[T], src: Array[T]) =
  `=sink`(dest.impl, src.impl)

proc `=copy`*[T](dest: var Array[T], src: Array[T]) =
  var L: int
  if src.impl.isNil or (L = src.impl.length; L == 0):
    dest.impl = nil
  else:
    uninitArrObj dest.impl, L
    for i in 0 ..< L:
      `=copy`(dest.impl.data[i], src.impl.data[i])

proc `=dup`*[T](src: Array[T]): Array[T] =
  result = Array[T](impl: nil)
  var L: int
  if not src.impl.isNil and (L = src.impl.length; L != 0):
    uninitArrObj result.impl, L
    for i in 0 ..< L:
      `=copy`(result.impl.data[i], src.impl.data[i])

# `=destroy`, `=wasMoved` handled by `ArrayObj`

proc len*[T](x: Array[T]): int {.inline.} =
  if x.impl.isNil: 0
  else: x.impl.length

proc `[]`*[T](x: Array[T], i: int): lent T {.inline.} =
  x.impl.data[i]

proc `[]`*[T](x: var Array[T], i: int): var T {.inline.} =
  x.impl.data[i]

proc `[]=`*[T](x: var Array[T], i: int, val: sink T) {.inline.} =
  x.impl.data[i] = val

iterator items*[T](x: Array[T]): T =
  let L = x.len
  for i in 0 ..< L:
    yield x.impl.data[i]

iterator mitems*[T](x: var Array[T]): var T =
  let L = x.len
  for i in 0 ..< L:
    yield x.impl.data[i]

iterator pairs*[T](x: Array[T]): (int, T) =
  let L = x.len
  for i in 0 ..< L:
    yield (i, x.impl.data[i])

iterator mpairs*[T](x: var Array[T]): (int, var T) =
  let L = x.len
  for i in 0 ..< L:
    yield (i, x.impl.data[i])

proc newArrayUninit*[T](length: int): Array[T] {.inline.} =
  uninitArrObj result.impl, length

proc newArray*[T](length: int): Array[T] =
  uninitArrObj result.impl, length
  for i in 0 ..< length:
    result.impl.data[i] = default(T)

proc toArray*[T](arr: openarray[T]): Array[T] =
  result = newArrayUninit[T](arr.len)
  for i in 0 ..< arr.len:
    result.impl.data[i] = arr[i]

template toOpenArray*[T](x: Array[T], first, last: int): auto =
  toOpenArray(addr x.impl.data, first, last)

proc `$`*[T](x: Array[T]): string =
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

proc `==`*[T](a, b: Array[T]): bool =
  let len = a.len
  if len != b.len: return false
  for i in 0 ..< len:
    if a[i] != b[i]: return false
  true

import hashes

proc hash*[T](a: Array[T]): Hash =
  mixin hash
  result = result !& hash a.len
  for i in 0 ..< a.len:
    result = result !& hash a[i]
  result = !$ result
