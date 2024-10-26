## array data object for internal use

type
  ArrayObj*[T] {.byref.} = object
    length*: int
    data*: UncheckedArray[T]

template uninitArrObj*[T](arr: var ref ArrayObj[T], L: int): untyped =
  # unsafeNew zeroes memory, so this is not really "uninitialized"
  # different story if default(T) is nonzero though
  unsafeNew(arr, sizeof(arr.length) + L * sizeof(T))
  arr.length = L

when defined(nimPreviewNonVarDestructor) and defined(gcDestructors):
  # needs `ArrayObj` to be `byref`, or at least the parameter
  proc `=destroy`*[T](arr: ArrayObj[T]) =
    for i in 0 ..< arr.length:
      {.cast(raises: []).}:
        `=destroy`(arr.data[i])
else:
  {.push warning[Deprecated]: off.}
  proc `=destroy`*[T](arr: var ArrayObj[T]) =
    for i in 0 ..< arr.length:
      {.cast(raises: []).}:
        `=destroy`(arr.data[i])
  {.pop.}

proc `=wasMoved`*[T](arr: var ArrayObj[T]) {.inline.} =
  arr.length = 0

proc `=trace`*[T](arr: var ArrayObj[T]; env: pointer) =
  for i in 0 ..< arr.length:
    `=trace`(arr.data[i], env)
