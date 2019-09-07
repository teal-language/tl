local tl = require("tl")

describe("[]", function()
   describe("on records", function()
      it("ok if indexing by string", function()
         local tokens = tl.lex([[
            local x = { foo = "f" }
            print(x["foo"])
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.same({}, errors)
      end)
      it("ok without declaration if record is homogenous", function()
         -- pass
         local tokens = tl.lex([[
            local x = { foo = 12, bar = 24 }
            local y = "baz"
            local n: number = x[y]
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.same({}, errors)
         -- fail as expected
         local tokens = tl.lex([[
            local x = { foo = 12, bar = 24 }
            local y = "baz"
            local n: string = x[y]
         ]])
         _, ast = tl.parse_program(tokens)
         errors = tl.type_check(ast)
         assert.same(1, #errors)
         assert.match("number is not a string", errors[1].err, 1, true)
      end)
      it("fail if indexing by invalid string", function()
         local tokens = tl.lex([[
            local x = { foo = "f" }
            print(x["bar"])
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.same(1, #errors)
         assert.match("invalid key 'bar' in record type", errors[1].err, 1, true)
      end)
   end)
end)
