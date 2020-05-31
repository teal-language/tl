local tl = require("tl")
local util = require("spec.util")

describe("pcall", function()
   it("checks the correct input arguments", function()
      local tokens = tl.lex([[
         local function f(a: string, b: number)
         end

         local pok = pcall(f, 123, "hello")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast, false, "test.lua")
      assert.match("argument 2: got number, expected string", errors[1].msg, 1, true)
   end)

   it("pcalls through pcall", function()
      -- ok
      util.mock_io(finally, {
         ["foo.tl"] = [[
            local function f(s: string): number
               return 123
            end
            local a, b, d = pcall(pcall, f, "num")

            assert(a == true)
            assert(b == true)
            assert(d == 123)
         ]],
      })
      local result, err = tl.process("foo.tl")

      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
      assert.same({}, result.unknowns)
   end)

   it("pcalls through pcall through pcall", function()
      -- ok
      util.mock_io(finally, {
         ["foo.tl"] = [[
            local function f(s: string): number
               return 123
            end
            local a, b, c, d = pcall(pcall, pcall, f, "num")

            assert(a == true)
            assert(b == true)
            assert(c == true)
            assert(d == 123)
         ]],
      })
      local result, err = tl.process("foo.tl")

      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
      assert.same({}, result.unknowns)
   end)

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
      assert.same({}, result.unknowns)
   end)

   it("returns the correct output arguments", function()
      local tokens = tl.lex([[
         local function f(a: string, b: number): {string}, boolean
            return {"hello", "world"}, true
         end

         local pok, strs, yep = pcall(f, "hello", 123)
         print(strs[1]:upper())
         local xyz: number = yep
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast, false, "test.lua")
      assert.match("xyz: got boolean, expected number", errors[1].msg, 1, true)
   end)
end)
