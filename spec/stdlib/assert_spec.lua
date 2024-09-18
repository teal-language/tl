local util = require("spec.util")

describe("assert", function()
   it("propagates its known facts", util.check_type_error([[
      local function f(): string | boolean
         return true
      end

      local x: string | boolean
      local y: string | boolean
      assert(x is string)
      print(x .. "!")
      print(y .. "!")
      x = f()
      print(x .. "!")
   ]], {
      { y = 9, msg = "cannot use operator '..' for types string | boolean and string" },
      { y = 11, msg = "cannot use operator '..' for types string | boolean and string" },
   }))

   it("ignores additional arguments", util.check([[
      local f = assert(io.open("nonexistent.txt"))
   ]]))

end)
