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

type
  Owner = ref object
    name: string
    subjects: RefArray[Subject]
  Subject = ref object
    name: string
    owner: Owner

proc `$`(x: Owner): string =
  if x == nil:
    result = "nil owner"
  else:
    result = "owner " & x.name & " with subjects"
    for s in x.subjects:
      result.add(" ")
      result.add(s.name)
proc `$`(x: Subject): string =
  result = "subject " & x.name & " with "
  if x.owner == nil:
    result.add("nil owner")
  else:
    result.add("owner " & $x.owner.name)

test "simple cycle":
  # does not work for Nim < 2.0.10
  var owner = Owner(name: "O")
  var subjectA = Subject(name: "A", owner: owner)
  var subjectB = Subject(name: "B", owner: owner)
  owner.subjects = toRefArray([subjectA, subjectB])
  check $owner == "owner O with subjects A B"
  check $subjectA == "subject A with owner O"
  check $subjectB == "subject B with owner O"

test "reference semantics":
  var x = toRefArray([1, 2, 3])
  let y = x
  x[1] = 5
  check x == toRefArray([1, 5, 3])
  check y == toRefArray([1, 5, 3])
  check x == y
