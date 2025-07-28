local util = require("spec.util")
local teal = require("teal")

describe("Compiler.require", function()
   it("returns a require error when a module is not found", function()
      local compiler = teal.compiler()
      local module, check_err, req_err = compiler:require("bar.foooo")
      assert.same(nil, module)
      assert.same(nil, check_err)
      assert.same("could not load module 'bar.foooo'", req_err)
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

      local compiler = teal.compiler()

      local module, check_err, req_err = compiler:require("bar.foo")
      assert(module)
      assert.same(0, #check_err.syntax_errors)
      assert.same(0, #check_err.type_errors)
      assert.same(nil, req_err)
   end)
end)
