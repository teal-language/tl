# Hacking on tl itself

As correctly pointed out in [#51](https://github.com/teal-language/tl/issues/51):

> Creating and testing edits to `tl.tl` can feel a bit awkward because
> changing `tl` itself requires bootstrapping from a "working" version
> of `tl`.

## Keeping tl working

Because of this situation, the tl repository provides a Makefile that
conveniently runs a build and test while making sure that `tl.lua`, which
is the file that ultimately drives the currently-running compiler, keeps
working.

So, when working on `tl.tl`, instead of running `tl gen tl.tl`, run `make`.
This will run `tl gen tl.tl`, but it will also make a backup of `tl.lua`
first, and it will check that the new modified version can still build itself.
If anything goes wrong, it reverts `tl.lua` to the backup and your compiler
still works. If the modified compiler is able to rebuild itself, then
it will run the Busted test suite. If the Busted test suite fails, it will
_not_ revert `tl.lua`, but leave you with the buggy compiler (i.e. a `tl.lua`
that matches the behavior of your current version of `tl.tl`).

If you want to revert only the generated code back to the last committed
state in Git but keep your changes to `tl.tl` around, you can run
`git checkout tl.lua`.

## Avoid circular dependencies

When dealing with a bootstrapped project (a project that uses itself to run),
one has to always be careful to not make the code itself depend on a new
feature when implementing it, otherwise you get into a chicken-and-egg
situation.

For example, when generics were added, the code to support them had to be
written using non-generic types, resorting to `any` and ugly casts. Once
the tests for generics were passing, then the code of `tl.tl` itself was
modified to use it.

If you find yourself in a circular-dependency situation like this (sometimes
it's a bug you need fixed in the compiler and the compiler needs the bug
fixed to run correctly), the last-resort alternative is to copy the fix
manually to `tl.lua`, stripping out the types in your new code by hand,
then running both (you may want to save your changes in a backup commit
before trying it, as you might accidentally overwrite your manual changes!).
Again, this manual editing of `tl.lua` shouldn't generally be necessary
if you take care to not depend on work-in-progress features.

## Sending code contributions

When submitting a pull request, make sure you include in your commits both the
changes to `tl.tl` and `tl.lua`. They should match of course (the `tl.lua`
should be the product of compiling `tl.tl`). In general, Git repositories do
not contain generated files, but we keep both in the repository precisely to
avoid the chicken-and-egg bootstrapping situation (if we didn't, one would
have to have a previous `tl` installation already in order to run `tl` from a
Git repo clone).

When sending a PR that adds a new feature or fixes a bug, please add one or more
relevant tests to the Busted test suite under `spec/`. Adding tests is important
to demonstrate that the PR works and help future maintenance of the project,
as it will check automatically that the change introduced in the PR will keep
working in the future as other changes are made to the project. For bug fixes,
the ideal test is a regression test: a test that would fail when running with
the unmodified version of the compiler, but passes when running the corrected
compiler.
