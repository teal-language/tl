local tl = require("tl")

describe("typed varargs", function()
   it("declaration", function()
      local tokens = tl.lex([[
         local function f(a: number, ...: string): boolean
            return true
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("call with multiple arities", function()
      local tokens = tl.lex([[
         local function f(a: number, ...: string): boolean
            return true
         end

         local ok = f(5)
         local ok = f(5, "aa")
         local ok = f(5, "aa", "bbb")
         local ok = f(5, "aa", "bbb", "ccc")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("can expand to multiple variables", function()
      local tokens = tl.lex([[
         local function f(...: string): string
            local s, t = ...
            return s .. t
         end
         local s = f("aa", "bbb")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("can compress to a single variable", function()
      local tokens = tl.lex([[
         local function f(...: string): number
            local s, n: string, number = ..., 12
            return #s + n
         end
         local s = f("aa", "bbb")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
