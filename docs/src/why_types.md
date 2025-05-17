## Why Types

If you're already convinced about the idea of type checking, you may skip this
part. :)

The data in your program has types: Lua is a high-level language, so each
piece of data stored in the memory of the Lua virtual machine has a type:
number, string, function, boolean, userdata, thread, nil or table.

Your program is basically a series of manipulations of data of various types.
The program is correct when it does what it is supposed to do, and that will
only happen when data is matched with other data of the correct types, like
pieces of a puzzle: you can multiply a number by another number, but not by a
boolean; you can call a function, but not a string; and so on.

The variables of a Lua program, however, know nothing about types. You can put
any value in any variable at any time, and if you make a mistake and match
things incorrectly, the program will crash at runtime, or even worse: it will
misbehave... silently.

The variables of Teal do know about types: each variable has an assigned type
and will hold on to that type forever. This way, there's a whole class of
mistakes that the Teal compiler is able to warn you about before the program
even runs.

Of course, it cannot catch every possible mistake in a program, but it should
help you with things like typos in table fields, missing arguments and so on.
It will also make you be more explicit about what kind of data your program is
dealing with: whenever that is not obvious enough, the compiler will ask you
about it and have you document it via types. It will also constantly check
that this "documentation" is not out of date. Coding with types is like pair
programming with the machine.
