local tl = require("tl")
local util = require("spec.util")

describe(".", function()
   describe("on records", function()
      it("ok", util.check [[
         local x = { foo = "f" }
         print(x.foo)
      ]])

      it("fail", util.check_type_error([[
         local x = { foo = "f" }
         print(x.bar)
      ]], {
         { y = 2, x = 18, msg = "invalid key 'bar' in record 'x'" }
      }))
   end)

   describe("on raw tables", function()
      it("using table", function()
         local tokens = tl.lex([[
            local x: table = { [true] = 12, [false] = 13 }
            x.foo = 9
            print(x.foo)
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.same({}, errors)
      end)
      it("using {any:any}", function()
         local tokens = tl.lex([[
            local x: {any:any} = {}
            x.foo = 9
            x["hello"] = 12
            x[false] = "world"
            print(x.foo)
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.same({}, errors)
      end)
   end)
end)
