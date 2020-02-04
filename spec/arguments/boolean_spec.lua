local util = require("spec.util")
util.init(it)

describe("boolean argument", function()
   util.check("accepts a boolean", [[
      local function f(b: boolean)
         if b then
            print("I'm true!")
         end
      end

      f(true)
      f(false)
   ]])

   util.check("accepts nil", [[
      local function f(b: boolean)
         if b then
            print("I'm true!")
         end
      end

      f(nil)
   ]])

   util.check_type_error("rejects non-booleans", [[
      local function f(b: boolean)
         if b then
            print("I'm true!")
         end
      end

      local R = record
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
      { y = 13, msg = 'argument 1: got number, expected boolean' },
      { y = 14, msg = 'argument 1: got {}, expected boolean' },
      { y = 15, msg = 'argument 1: got R, expected boolean' },
      { y = 16, msg = 'argument 1: got function(), expected boolean' },
   })
end)
