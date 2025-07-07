local util = require("spec.block-util")

describe("assert", function()
   it("propagates its known facts even with locals", util.check_type_error([[
      local function f(): string | boolean
         return true
      end

      local myassert = assert

      local x: string | boolean
      local y: string | boolean
      myassert(x is string)
      print(x .. "!")
      print(y .. "!")
      x = f()
      print(x .. "!")
   ]], {
      { y = 11, msg = "cannot use operator '..' for types string | boolean and string" },
      { y = 13, msg = "cannot use operator '..' for types string | boolean and string" },
   }))

   it("ignores additional arguments", util.check([[
      local f = assert(io.open("nonexistent.txt"))
   ]]))

end)
