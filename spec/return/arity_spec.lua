local tl = require("tl")
local util = require("spec.util")

describe("return arity", function()
   describe("with too many directly", function()
      local tokens = tl.lex([[
         local function foo(): number, string
            return 1, "hello", "wat"
         end
      ]])

      local errs = {}
      local _, ast = tl.parse_program(tokens, errs)
      assert.same({}, errs)

      it("rejects in strict", function()
         local errors = tl.type_check(ast)
         assert.match("excess return values", errors[1].err)
      end)

      it("accepts in lax", function()
         local errors = tl.type_check(ast, true)
         assert.same({}, errors)
      end)
   end)

   describe("with too few directly", function()
      local tokens = tl.lex([[
         local function foo(): number, string
            return 1
         end
      ]])

      local errs = {}
      local _, ast = tl.parse_program(tokens, errs)
      assert.same({}, errs)

      it("accepts in strict", function()
         local errors = tl.type_check(ast)
         assert.same({}, errors)
      end)

      it("accepts in lax", function()
         local errors = tl.type_check(ast, true)
         assert.same({}, errors)
      end)
   end)

   describe("with too many indirectly", function()
      local tokens = tl.lex([[
         local function bar(): number, string, string
            return 1, "hello", "wat"
         end

         local function foo(): number, string
            return bar()
         end
      ]])

      local errs = {}
      local _, ast = tl.parse_program(tokens, errs)
      assert.same({}, errs)

      it("rejects in strict", function()
         local errors = tl.type_check(ast)
         assert.match("excess return values", errors[1].err)
      end)

      it("accepts in lax", function()
         local errors = tl.type_check(ast, true)
         assert.same({}, errors)
      end)
   end)

   describe("with too few indirectly", function()
      local tokens = tl.lex([[
         local function bar(): number
            return 1
         end

         local function foo(): number, string
            return bar()
         end
      ]])

      local errs = {}
      local _, ast = tl.parse_program(tokens, errs)
      assert.same({}, errs)

      it("accepts in strict", function()
         local errors = tl.type_check(ast)
         assert.same({}, errors)
      end)

      it("accepts in lax", function()
         local errors = tl.type_check(ast, true)
         assert.same({}, errors)
      end)
   end)

end)
