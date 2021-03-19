# zig-itertools
A simple python-style generator implementation.  This library models
generators as a type of self-contained state coupled with a function
that consumes (and may modify) the underlying state of the generator.

Benefits:

- Low overhead - Each genenrator only has struct overhead, and an
  additional function pointer member.

Limitations:

- This kind of mechanism would be unsafe unsafe in terms of
  multithreading
- Very few generators are provided by the library (so far)
- Not a true python generator, as in you can't use a yield statement
  to pause execution in a function, although it could be modeled.

plans:

- Full implementation of the python itertools library minus starMap
    and other iterators
- An eventual cleanup of the user interface, deciding between `next()`
    `nextValue()` and `nextOptional()`, and coming up with clearer
    names for them
- Convenience functions for making generators out of common types
    like slices, arrays, ArrayLists, etc.
- Testing and support for deinitialization of state data so
    generators can own their underlying state


