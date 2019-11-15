local tl = require("tl")

describe("string method call", function()
   describe("simple", function()
      it("pass", function()
         -- pass
         local tokens = tl.lex([[
            print(("  "):rep(12))
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.same({}, errors)
      end)
      it("fail", function()
         local tokens = tl.lex([[
            print(("  "):rep("foo"))
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.match("error in argument 1:", errors[1].err, 1, true)
      end)
   end)
   describe("with variable", function()
      it("pass", function()
         -- pass
         local tokens = tl.lex([[
            local s = "a"
            s = s:gsub("a", "b") .. "!"
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.same({}, errors)
      end)
      it("fail", function()
         local tokens = tl.lex([[
            local s = "a"
            s = s:gsub(function() end) .. "!"
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.match("error in argument 1:", errors[1].err, 1, true)
      end)
   end)
   describe("chained", function()
      it("pass", function()
         -- pass
         local tokens = tl.lex([[
            print(("xy"):rep(12):sub(1,3))
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.same({}, errors)
      end)
      it("fail", function()
         -- pass
         local tokens = tl.lex([[
            print(("xy"):rep(12):subo(1,3))
         ]])
         local _, ast = tl.parse_program(tokens)
         local errors = tl.type_check(ast)
         assert.same(1, #errors)
         assert.match("invalid key 'subo' in type string", errors[1].err, 1, true)
      end)
   end)
end)
