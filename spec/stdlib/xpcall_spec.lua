local tl = require("tl")
local util = require("spec.util")

describe("xpcall", function()
   it("can't xpcall nothing", util.check_type_error([[
      local pok = xpcall()
   ]], {
      { msg = "given 0, expects at least 2" }
   }))

   it("can't xpcall without a message handler", util.check_type_error([[
      local pok = xpcall(function() end)
   ]], {
      { msg = "given 1, expects at least 2" }
   }))

   it("checks the correct input arguments", util.check_type_error([[
      local function f(a: string, b: number)
      end

      local function msgh(err: string) print(err) end

      local pok = xpcall(f, msgh, 123, "hello")
   ]], {
      { msg = "argument 3: got integer, expected string" }
   }))

   it("xpcalls through xpcall", function()
      -- ok
      util.mock_io(finally, {
         ["foo.tl"] = [[
            local function f(s: string): number
               return 123
            end

            local function msgh(err: string) print(err) end

            local a, b, d = xpcall(xpcall, msgh, f, msgh, "num")

            assert(a == true)
            assert(b == true)
            assert(d == 123)
         ]],
      })
      local result, err = tl.process("foo.tl")

      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
   end)

   it("xpcalls through xpcall through xpcall", function()
      -- ok
      util.mock_io(finally, {
         ["foo.tl"] = [[
            local function f(s: string): number
               return 123
            end
            local function msgh(err: string) print(err) end
            local a, b, c, d = xpcall(xpcall, msgh, xpcall, msgh, f, msgh, "num")

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

   it("xpcalls through other magical stdlib functions", function()
      -- ok
      util.mock_io(finally, {
         ["num.tl"] = [[
            return 123
         ]],
         ["foo.tl"] = [[
            local function msgh(err: string) print(err) end
            local a, b, c, d = xpcall(xpcall, msgh, xpcall, msgh, require, msgh, "num")

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

      local function msgh(err: string) print(err) end
      local pok, strs, yep = xpcall(f, msgh, "hello", 123)
      print(strs[1]:upper())
      local xyz: number = yep
   ]], {
      { msg = "xyz: got boolean, expected number" }
   }))

   it("#only type checks the message handler", util.check_type_error([[
      local function f(a: string, b: number)
      end

      local function msgh(err: string, num: number) print(err) end

      local pok = xpcall(f, msgh, 123, "hello")
   ]], {
      { y = 6, x = 29, msg = "in message handler: incompatible number of arguments" },
      { y = 6, x = 35, msg = "argument 3: got integer, expected string" },
   }))

   it("does not warn when passed a method as the first argument", util.check_warnings([[
      local record Text
         text: string
      end

      local function msgh(err: nil) print(err) end

      function Text:print(): nil
         if self.text == nil then
            error("Text is nil")
         end
         print(self.text)
      end
      local myText: Text = {}
      xpcall(myText.print, msgh, myText)
   ]], {}, {}))

   it("checks the correct input arguments when passed a method as the first argument", util.check_type_error([[
      local record Text
         text: string
      end

      local function msgh(err: nil) print(err) end

      function Text:print(): nil
         if self.text == nil then
            error("Text is nil")
         end
         print(self.text)
      end
      local myText: Text = {}
      xpcall(myText.print, msgh, 12)
   ]], {
      { msg = "argument 3: got integer, expected Text" }
   }))

end)
