local tl = require("tl")

describe(".", function()
   describe("on records", function()
      it("ok", function()
         local tokens = tl.lex([[
            local x = { foo = "f" }
            print(x.foo)
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.same({}, errors)
      end)
      it("fail", function()
         local tokens = tl.lex([[
            local x = { foo = "f" }
            print(x.bar)
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.same(1, #errors)
         assert.match("invalid key 'bar' in record 'x'", errors[1].msg, 1, true)
      end)
   end)

   describe("on raw tables", function()
      it("using table", function()
         local tokens = tl.lex([[
            local x: table = {}
            x.foo = 9
            print(x.foo)
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.same({}, errors)
      end)
      it("using {any:any}", function()
         local tokens = tl.lex([[
            local x: {any:any} = { [true] = true, [false] = true }
            x.foo = 9
            print(x.foo)
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.same({}, errors)
      end)
   end)
end)
