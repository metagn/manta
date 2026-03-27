when (NimMajor, NimMinor) >= (1, 4):
  when (compiles do: import nimbleutils):
    import nimbleutils
    # https://github.com/metagn/nimbleutils

when not declared(runTests):
  {.error: "tests task not implemented, need nimbleutils".}

# run from project root
runTests(
  backends = {c, cpp},
  optionCombos = @[
    "--mm:orc",
    "--mm:arc",
    "--mm:refc",
    "--mm:orc -d:nimPreviewNonVarDestructor",
    "--mm:arc -d:nimPreviewNonVarDestructor",
    "--mm:refc -d:nimPreviewNonVarDestructor",
  ]
)
