when (compiles do: import nimbleutils/bridge):
  import nimbleutils/bridge
else:
  import unittest

import manta/bitarray

test "basic type":
  var f: BitArray
  block:
    var a = toBitArray([true, true, false, true, false, true])
    checkpoint $cast[(uint, uint)](a)[1]
    check $a == "[true, true, false, true, false, true]"
    a[1] = false
    checkpoint $cast[(uint, uint)](a)[1]
    check $a == "[true, false, false, true, false, true]"
    a[2] = true
    checkpoint $cast[(uint, uint)](a)[1]
    check $a == "[true, false, true, true, false, true]"
    f = a
  block: # after leaving block
    check $f == "[true, false, true, true, false, true]"

test "value semantics":
  var x = toBitArray([true, false, true, false])
  let y = x
  x[3] = true
  check x == toBitArray([true, false, true, true])
  check y == toBitArray([true, false, true, false])
  check x != y

test "larger sizes":
  var s: seq[bool]
  for i in 1..30:
    for j in 1..i:
      s.add(bool(i and 1))
  var s25 = s[0..24]
  let s25bits = toBitArray(s25)
  var s25remadeItems: seq[bool]
  for x in s25bits:
    s25remadeItems.add(x)
  check s25 == s25remadeItems
  var s25remadeIndex: seq[bool]
  for i in 0 ..< s25.len:
    s25remadeIndex.add(s25bits[i])
  check s25 == s25remadeIndex
  check s25remadeItems == s25remadeIndex
  var s45 = s[0..44]
  let s45bits = toBitArray(s45)
  var s45remadeItems: seq[bool]
  for x in s45bits:
    s45remadeItems.add(x)
  check s45 == s45remadeItems
  var s45remadeIndex: seq[bool]
  for i in 0 ..< s45.len:
    s45remadeIndex.add(s45bits[i])
  check s45 == s45remadeIndex
  check s45remadeItems == s45remadeIndex
  var s100 = s[0..99]
  let s100bits = toBitArray(s100)
  var s100remadeItems: seq[bool]
  for x in s100bits:
    s100remadeItems.add(x)
  check s100 == s100remadeItems
  var s100remadeIndex: seq[bool]
  for i in 0 ..< s100.len:
    s100remadeIndex.add(s100bits[i])
  check s100 == s100remadeIndex
  check s100remadeItems == s100remadeIndex
