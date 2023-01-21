local util = require("spec.util")

describe("assignment to maps", function()
   it("resolves a record to a map", util.check([[
      local m: {string:number} = {
         hello = 123,
         world = 234,
      }
   ]]))

   it("resolves arity of function returns", util.check([[
      local function f(): number
         return 2
      end
      local x = "hello"
      local m: {string:number} = { [x] = f() }
   ]]))

   it("resolves strings to enum", util.check([[
      local type Direction = enum
         "north"
         "south"
         "east"
         "west"
      end
      local m: {string:Direction} = {
         hello = "north",
         world = "south",
      }
   ]]))

   it("resolves empty tables in values to nominals (regression test for #332)", util.check([[
      local keystr = "aaaa"

      local record user_login_count_t
      end

      local data:{string: user_login_count_t} = {
         key={},
         [keystr]={}
      }

      for k, v in pairs(data) do
         print(k, v)
      end
   ]]))

   it("does not accept an array-like key in a map", util.check_type_error([[
      local function f(x: {string:any})
      end

      f({"string value", pi=math.pi})
   ]], {
      { msg = "argument 1: in map key: got integer, expected string" }
   }))
end)
