# manta

Arrays with constant runtime length in Nim, with destructors to support Nim's memory management, as well as a choice between value (`Array[T]`) or reference (`RefArray[T]`) semantics. Very basic examples in tests. Potential place for more user-managed collection types in the future.

Depends on the [`unsafeNew`](https://nim-lang.org/docs/system.html#unsafeNew%2Cref.T%2CNatural) API from Nim to work which seems to have [existed for a long time](https://github.com/nim-lang/Nim/commit/76885c754a8f51a0ea34f76dd0843b1949ac7fde#diff-c7ae564e61082887ea50f0d58a637cb12fa78261f51aa4eface24ababfeee299) but may be unstable on the new memory management options.
