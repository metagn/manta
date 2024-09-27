when (compiles do: import nimbleutils/bridge):
  import nimbleutils/bridge
else:
  import unittest

import manta/refarray

type Foo = ref object
  x: int
proc foo(x: int): Foo = Foo(x: x)
proc `$`*(f: Foo): string = "foo(" & $f.x & ")"

test "basic type":
  var f: RefArray[RefArray[Foo]]
  block:
    var a = @[foo(1), foo(2), foo(3), foo(4), foo(5)].toRefArray()
    check $a == "[foo(1), foo(2), foo(3), foo(4), foo(5)]"
    a[2] = foo 7
    check $a == "[foo(1), foo(2), foo(7), foo(4), foo(5)]"
    f = [a].toRefArray
  block: # after leaving block
    check $f == "[[foo(1), foo(2), foo(7), foo(4), foo(5)]]"

type Tree = object
  case atom: bool
  of false:
    node: RefArray[Tree]
  of true:
    leaf: int
proc `$`(x: Tree): string =
  if x.atom:
    $x.leaf
  else:
    $x.node
proc tree(arr: varargs[Tree]): Tree =
  Tree(atom: false, node: toRefArray(arr))
proc leaf(x: int): Tree = Tree(atom: true, leaf: x)

test "tree":
  let x = tree(leaf(1), tree(leaf(2), tree(leaf(3), tree(leaf(4), tree(leaf(5))))))
  check $x == "[1, [2, [3, [4, [5]]]]]"

test "reference semantics":
  var x = toRefArray([1, 2, 3])
  let y = x
  x[1] = 5
  check x == toRefArray([1, 5, 3])
  check y == toRefArray([1, 5, 3])
  check x == y
