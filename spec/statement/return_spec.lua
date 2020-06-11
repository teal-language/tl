local tl = require("tl")
local util = require("spec.util")

describe("return", function()
   describe("arity", function()
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
            assert.match("excess return values", errors[1].msg)
         end)

         it("accepts in lax", function()
            local errors = tl.type_check(ast, { lax = true })
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
            local errors = tl.type_check(ast, { lax = true })
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
            assert.match("excess return values", errors[1].msg)
         end)

         it("accepts in lax", function()
            local errors = tl.type_check(ast, { lax = true })
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
            local errors = tl.type_check(ast, { lax = true })
            assert.same({}, errors)
         end)
      end)

   end)

   describe("type checking", function()
      it("checks all returns of a call with proper locations", util.check_type_error([[
         local function foo1(): (boolean, any) return coroutine.resume(nil) end
         local function foo2(): (boolean, string) return coroutine.resume(nil) end
      ]], {
         { y = 2, x = 58, msg = "in return value: got <any type>, expected string" }
      }))
   end)

end)
