local util = require("spec.util")

describe("boolean argument", function()
   it("accepts a boolean", util.check([[
      local function f(b: boolean)
         if b then
            print("I'm true!")
         end
      end

      f(true)
      f(false)
   ]]))

   it("accepts nil", util.check([[
      local function f(b: boolean)
         if b then
            print("I'm true!")
         end
      end

      f(nil)
   ]]))

   it("rejects non-booleans", util.check_type_error([[
      local function f(b: boolean)
         if b then
            print("I'm true!")
         end
      end

      local type R = record
         b: boolean
      end
      local r: R = {}

      f("hello")
      f(123)
      f({})
      f(r)
      f(function() end)
   ]], {
      { y = 12, msg = 'argument 1: got string "hello", expected boolean' },
      { y = 13, msg = 'argument 1: got integer, expected boolean' },
      { y = 14, msg = 'argument 1: got {}, expected boolean' },
      { y = 15, msg = 'argument 1: got R, expected boolean' },
      { y = 16, msg = 'argument 1: got function(), expected boolean' },
   }))
end)
