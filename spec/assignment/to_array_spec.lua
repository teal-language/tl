local tl = require("tl")
local util = require("spec.util")

describe("assignment to array", function()
   it("check array type", util.check_type_error([[
      local a: {string}
      a = 100
      a = {"a", 100}
   ]], {
      { y = 2, msg = "got integer, expected {string}" },
      { y = 3, msg = "expected an array: at index 2: got integer, expected string" },
   }))

   it("resolves arity of function returns", util.check([[
      local function f(): number
         return 2
      end
      local m: {number} = { f() }
   ]]))

   it("check expansion of expression inside array", util.check_type_error([[
      local function f(): string, number
         return "hello", 123
      end
      local a: {string}
      a = { f() }
   ]], {
      { y = 5, msg = "expected an array: at index 2: got number, expected string" },
   }))

   it("accept expression", util.check([[
      local self = {
         fmt = "hello"
      }
      local str = "hello"
      local a = {str:sub(2, 10)}
   ]]))

   it("catches a syntax error", util.check_syntax_error([[
      local self = {
         ["fmt"] = {
            x = 123,
            y = 234,
         }
         ["bla"] = {
            z = 345,
            w = 456,
         }
      }
   ]], {
      { y = 6, x = 10, msg = "cannot index this expression" },
      { y = 6, msg = "syntax error" },
      { y = 6, msg = "expected an expression" },
      { y = 7, msg = "syntax error, expected one of: '}', ','" },
      { y = 10, msg = "syntax error" },
   }))

   it("a tuple resolves to an array without nominals producing duplicates (#337)", util.check_warnings([[
      local type Alias = string
      local t = {"a", "a"} as {Alias, Alias}
      local a, b = table.unpack(t)
   ]], {
      { msg = "unused variable a: Alias" },
      { msg = "unused variable b: Alias" },
   }))

end)
