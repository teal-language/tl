local util = require("spec.util")

describe("parentheses", function()
   describe("type checking", function()
      it("flow expected type through parentheses (regression test for #553)", util.check([[
         local enum Type
            "add"
            "change"
            "delete"
         end

         local function foo(a: integer, b: integer): Type
            return ((a == 0 and "delete") or b == 0 and ("add")) or "change"
         end
      ]]))
   end)
end)
