## The type `any`

The type `any`, as it name implies, accepts any value, like a dynamically-typed
Lua variable. However, since Teal doesn't know anything about this value, there
isn't much you can do with it, besides comparing for equality and against nil,
and casting it into other values using the `as` operator.

Some Lua libraries use complex dynamic types that can't be easily represented
in Teal. In those cases, using `any` and making explicit casts is our last
resort.
