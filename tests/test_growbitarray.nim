when (compiles do: import nimbleutils/bridge):
  import nimbleutils/bridge
else:
  import unittest

import manta/growbitarray

test "basic type":
  var f: GrowBitArray
  block:
    var a = toGrowBitArray([true, true, false, true, false, true])
    checkpoint repr a
    check $a == "[true, true, false, true, false, true]"
    a[1] = false
    check $a == "[true, false, false, true, false, true]"
    a[2] = true
    check $a == "[true, false, true, true, false, true]"
    f = a
  block: # after leaving block
    check $f == "[true, false, true, true, false, true]"

test "value semantics":
  var x = toGrowBitArray([true, false, true, false])
  let y = x
  x[3] = true
  check x == toGrowBitArray([true, false, true, true])
  check y == toGrowBitArray([true, false, true, false])
  check x != y

test "larger sizes":
  # somewhat broken
  var s: seq[bool]
  for i in 1..20:
    for j in 1..i:
      s.add(bool(i and 1))
  var s25 = s[0..24]
  let s25bits = toGrowBitArray(s25)
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
  let s45bits = toGrowBitArray(s45)
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
  let s100bits = toGrowBitArray(s100)
  var s100remadeItems: seq[bool]
  for x in s100bits:
    s100remadeItems.add(x)
  check s100 == s100remadeItems
  var s100remadeIndex: seq[bool]
  for i in 0 ..< s100.len:
    s100remadeIndex.add(s100bits[i])
  check s100 == s100remadeIndex
  check s100remadeItems == s100remadeIndex

  var s200 = s[0..199]
  var s200bits = toGrowBitArray(s200)
  var s200remadeItems: seq[bool]
  for x in s200bits:
    s200remadeItems.add(x)
  checkpoint $(s200.len, s200remadeItems.len)
  check s200 == s200remadeItems
  var s200remadeIndex: seq[bool]
  for i in 0 ..< s200.len:
    s200remadeIndex.add(s200bits[i])
  check s200 == s200remadeIndex
  check s200remadeItems == s200remadeIndex

  s200bits.setLen(s45.len)
  var s200clippedRemadeItems: seq[bool]
  for x in s200bits:
    s200clippedRemadeItems.add(x)
  check s45 == s200clippedRemadeItems
  var s200clippedRemadeIndex: seq[bool]
  checkpoint $(s200bits.len, s200clippedRemadeItems.len)
  for i in 0 ..< s200bits.len:
    s200clippedRemadeIndex.add(s200bits[i])
  check s45 == s200clippedRemadeIndex
  check s200clippedRemadeItems == s200clippedRemadeIndex

  s200bits.setLen(s200.len)
  var newS200 = s200
  for i in s45.len ..< s200.len:
    s200bits[i] = not s[i]
    newS200[i] = not s[i]
  var s200grownRemadeItems: seq[bool]
  for x in s200bits:
    s200grownRemadeItems.add(x)
  check newS200 == s200grownRemadeItems
  var s200grownRemadeIndex: seq[bool]
  checkpoint $(s200bits.len, s200grownRemadeItems.len)
  for i in 0 ..< s200bits.len:
    s200grownRemadeIndex.add(s200bits[i])
  check newS200 == s200grownRemadeIndex
  check s200grownRemadeItems == s200grownRemadeIndex
  let newS200Bits = toGrowBitArray(newS200)
  check s200bits == newS200Bits
