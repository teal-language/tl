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
end)
