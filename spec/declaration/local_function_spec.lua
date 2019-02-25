local tl = require("tl")

describe("local function", function()
   it("declaration", function()
      local tokens = tl.lex([[
         local function f(a: number, b: string): boolean
            return #b == a
         end
         local ok = f(3, "abc")
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end)
