local util = require("spec.util")
local teal = require("teal")

describe("teal.search_module", function()
   it("returns a search error when a module is not found", function()
      local filename, search_err = teal.search_module("bar.foooo")
      assert.same(nil, filename)
      assert.is_table(search_err)
      assert.match("no file '.*bar[/\\]foooo.tl'", search_err[1])
   end)

   it("processes a module file given a Lua module name", function()
      util.mock_io(finally, {
         ["bar/foo.tl"] = [[
            local record Foo<T>
               bar: T
            end
            local type FooInteger = Foo<integer>
            return FooInteger
         ]],
      })

      local filename, search_err = teal.search_module("bar.foo")
      assert.matches("^.[/\\]bar[/\\]foo.tl$", filename)
      assert.same(nil, search_err)
   end)

   it("does not resolve .m.tl files by default", function()
      util.mock_io(finally, {
         ["bar/foo.m.tl"] = [[
            local macro inc!(x: Expression): Expression
               return `$x + 1`
            end

            return {
               inc = inc,
            }
         ]],
      })

      local filename, search_err = teal.search_module("bar.foo")
      assert.same(nil, filename)
      assert.is_table(search_err)
      local joined = table.concat(search_err, "\n")
      assert.match("foo%.tl", joined)
      assert.is_nil(joined:match("foo%.m%.tl"))
   end)
end)
