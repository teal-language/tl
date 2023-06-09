local tl = require("tl")
local util = require("spec.util")

describe("pcall", function()
   it("can't pcall nothing", util.check_type_error([[
      local pok = pcall()
   ]], {
      { msg = "given 0, expects at least 1" }
   }))

   it("checks the correct input arguments", util.check_type_error([[
      local function f(a: string, b: number)
      end

      local pok = pcall(f, 123, "hello")
   ]], {
      { msg = "argument 2: got integer, expected string" }
   }))

   it("pcalls through pcall", util.check([[
      local function f(s: string): number
         return 123
      end
      local a, b, d = pcall(pcall, f, "num")

      assert(a == true)
      assert(b == true)
      assert(d == 123)
   ]]))

   it("pcalls through pcall through pcall", util.check([[
      local function f(s: string): number
         return 123
      end
      local a, b, c, d = pcall(pcall, pcall, f, "num")

      assert(a == true)
      assert(b == true)
      assert(c == true)
      assert(d == 123)
   ]]))

   it("pcalls through other magical stdlib functions", function()
      -- ok
      util.mock_io(finally, {
         ["num.tl"] = [[
            return 123
         ]],
         ["foo.tl"] = [[
            local a, b, c, d = pcall(pcall, pcall, require, "num")

            assert(a == true)
            assert(b == true)
            assert(c == true)
            assert(d == 123)
         ]],
      })
      local result, err = tl.process("foo.tl")

      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
   end)

   it("returns the correct output arguments", util.check_type_error([[
      local function f(a: string, b: number): {string}, boolean
         return {"hello", "world"}, true
      end

      local pok, strs, yep = pcall(f, "hello", 123)
      print(strs[1]:upper())
      local xyz: number = yep
   ]], {
      { msg = "xyz: got boolean, expected number" }
   }))

   it("does not warn when passed a method as the first argument", util.check_warnings([[
      local record Text
         text: string
      end
      function Text:print(): nil
         if self.text == nil then
            error("Text is nil")
         end
         print(self.text)
      end
      local myText: Text = {}
      local ok, err = pcall(myText.print, myText)
      if not ok then
         print(err)
      end
   ]], {}, {}))

   it("checks the correct input arguments when passed a method as the first argument", util.check_type_error([[
      local record Text
         text: string
      end
      function Text:print(): nil
         if self.text == nil then
            error("Text is nil")
         end
         print(self.text)
      end
      local myText: Text = {}
      local ok, err = pcall(myText.print, 12)
      if not ok then
         print(err)
      end
   ]], {
      { msg = "argument 2: got integer, expected Text" }
   }))
end)
