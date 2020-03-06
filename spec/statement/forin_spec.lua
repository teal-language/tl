local tl = require("tl")
local util = require("spec.util")

describe("forin", function()
   it("with a single variable", function()
      local tokens = tl.lex([[
         local t = { 1, 2, 3 }
         for i in ipairs(t) do
            print(i)
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   it("with two variables", function()
      local tokens = tl.lex([[
         local t = { 1, 2, 3 }
         for i, v in ipairs(t) do
            print(i, v)
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   it("with an explicit iterator", function()
      local tokens = tl.lex([[
         local function iter(t): number
         end
         local t = { 1, 2, 3 }
         for i in iter, t do
            print(i + 1)
         end
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
   describe("regressions", function()
      it("accepts nested unresolved values", util.lax_check([[
         function fun(xss)
           for _, xs in pairs(xss) do
             for _, x in pairs(xs) do
               for _, u in ipairs({}) do
                local v = x[u]
                _, v = next(v)
               end
             end
           end
         end
      ]], {
         { msg = "xss" },
         { msg = "_" },
         { msg = "xs" },
         { msg = "_" },
         { msg = "x" },
         { msg = "u" },
         { msg = "v" },
      }))
   end)
end)
