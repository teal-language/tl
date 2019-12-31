local tl = require("tl")

describe("assignment to nominal record", function()
   it("accepts empty table", function()
      local tokens = tl.lex([[
         local Node = record
            b: boolean
         end
         local x: Node = {}
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("accepts complete table", function()
      local tokens = tl.lex([[
         local R = record
            foo: string
         end
         local AR = record
            {node}
            bar: string
         end
         local Node = record
            b: boolean
            n: number
            m: {number: string}
            a: {boolean}
            r: R
            ar: AR
         end
         local x: Node = {
            b = true,
            n = 1,
            m = {},
            a = {},
            r = {},
            ar = {},
         }
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("accepts incomplete table", function()
      local tokens = tl.lex([[
         local Node = record
            b: boolean
            n: number
         end
         local x: Node = {
            b = true,
         }
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)

   it("fails if table has extra fields", function()
      local tokens = tl.lex([[
         local Node = record
            b: boolean
            n: number
         end
         local x: Node = {
            b = true,
            bla = 12,
         }
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.is_not.same({}, errors)
      assert.match("in local declaration: x: unknown field bla", errors[1].msg, 1, true)
   end)

   it("fails if mismatch", function()
      local tokens = tl.lex([[
         local Node = record
            b: boolean
         end
         local x: Node = 123
      ]])
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.match("in local declaration: x: got number, expected Node", errors[1].msg, 1, true)
   end)
end)
