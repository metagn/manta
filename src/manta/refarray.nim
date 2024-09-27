import ./arrayobj

type RefArray*[T] = object
  ## array with constant runtime length and reference semantics
  impl: ref ArrayObj[T]

proc `=trace`*[T](arr: var RefArray[T]; env: pointer) =
  if not arr.impl.isNil:
    for i in 0 ..< arr.impl.length:
      `=trace`(arr.impl.data[i], env)

# `=copy` and `=sink` not defined, no-ops since reference semantics
# `=destroy`, `=wasMoved` handled by `ArrayObj`

proc len*[T](x: RefArray[T]): int {.inline.} =
  if x.impl.isNil: 0
  else: x.impl.length

proc `[]`*[T](x: RefArray[T], i: int): lent T {.inline.} =
  rangeCheck i >= 0 and i < x.len
  x.impl.data[i]

proc `[]`*[T](x: var RefArray[T], i: int): var T {.inline.} =
  rangeCheck i >= 0 and i < x.len
  x.impl.data[i]

proc `[]=`*[T](x: RefArray[T], i: int, val: sink T) {.inline.} =
  rangeCheck i >= 0 and i < x.len
  x.impl.data[i] = val

iterator items*[T](x: RefArray[T]): T =
  let L = x.len
  for i in 0 ..< L:
    yield x.impl.data[i]

iterator mitems*[T](x: RefArray[T]): var T =
  let L = x.len
  for i in 0 ..< L:
    yield x.impl.data[i]

iterator pairs*[T](x: RefArray[T]): (int, T) =
  let L = x.len
  for i in 0 ..< L:
    yield (i, x.impl.data[i])

iterator mpairs*[T](x: RefArray[T]): (int, var T) =
  let L = x.len
  for i in 0 ..< L:
    yield (i, x.impl.data[i])

proc newRefArrayUninit*[T](length: int): RefArray[T] {.inline.} =
  uninitArrObj result.impl, length

proc newRefArray*[T](length: int): RefArray[T] =
  uninitArrObj result.impl, length
  for i in 0 ..< length:
    result.impl.data[i] = default(T)

proc toRefArray*[T](arr: openarray[T]): RefArray[T] =
  result = newRefArrayUninit[T](arr.len)
  for i in 0 ..< arr.len:
    result.impl.data[i] = arr[i]

template toOpenArray*[T](x: RefArray[T], first, last: int): auto =
  toOpenArray(addr x.impl.data, first, last)

proc `$`*[T](x: RefArray[T]): string =
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

proc `==`*[T](a, b: RefArray[T]): bool =
  let len = a.len
  if len != b.len: return false
  for i in 0 ..< len:
    if a[i] != b[i]: return false
  true

import hashes

proc hash*[T](a: RefArray[T]): Hash =
  mixin hash
  result = result !& hash a.len
  for i in 0 ..< a.len:
    result = result !& hash a[i]
  result = !$ result
