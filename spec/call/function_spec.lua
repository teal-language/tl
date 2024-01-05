util = require("spec.util")

describe("function calls", function()
   it("does not crash attempting to infer an emptytable when there's no return type", util.check_type_error([[
      local function f()
      end

      local x = {}

      x = f()
   ]], {
      { y = 6, msg = "variable is not being assigned a value" },
   }))

   it("can perform recursive calls on varargs (regression test for #727)", util.check([[
      local message:string = "hello world!"

      local function foo(...: string): string
          local n = select("#", ...)
          if n < 3 then
              return ""
          end
          if message ~= "hello world" then
              return foo("hi there", select(2, ...))
          else
              local r = {"hi there", select(2, ...)}
              return foo(table.unpack(r))
          end
      end

      local function bar(...: string): string
          return foo("hi there", select(2, ...))
      end
   ]]))
end)
