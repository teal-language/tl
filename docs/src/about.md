## This project's goals

This project comes from the desire of a practical Lua dialect for
programming-in-the-large. This is inspired by the experiences working on [two
large](http://konghq.com) [Lua applications](http://luarocks.org).

The goal of the language is to be a dialect of Lua as much as TypeScript is a
dialect of JavaScript. So yes, it is on the one hand a different language
(there are new keywords such as `global` for example) but on the other hand it
is pretty much recognizable as "Lua + typing".

It aims to integrate to pretty much any Lua environment, since it's a
"transpiler" that generates plain Lua and has no dependencies. The goal is to
support at least both the latest PUC-Rio Lua and the latest LuaJIT as output
targets.

Minimalism (for some vague definition of minimalism!) is a design goal for
both conceptual and practical reasons: conceptually to match the nature of
Lua, and practical so that I can manage developing it. :)

My very first concrete goal for Teal's development was to have the compiler
typecheck itself; that was achieved already: Teal is written in Teal.

The next big goal is to have it typecheck the source code of a complete Lua
application such as LuaRocks. That's something I wanted since the Typed Lua
days back in 2015. That's a big goal and once I get there I'll dare call this
"production ready", since it's used in a real-world program, though it should
be usable even before we get there! The language has already proven useful
when creating [a new Lua module](https://github.com/hishamhm/tabular).

Teal is being created in hopes it will be useful for myself and hopefully
others. I'm trying to keep it small and long-term manageable, and would love
to see a community of users and contributors grow around it over time!
