local tl = require("tl")

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
