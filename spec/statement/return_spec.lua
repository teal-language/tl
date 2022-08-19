local util = require("spec.util")

describe("return", function()
   describe("arity", function()
      it("with too many directly", util.strict_check_type_error([[
         local function foo(): number, string
            return 1, "hello", "wat"
         end
      ]], {
         { msg = "excess return values" }
      }, {}))

      it("with too few directly", util.strict_and_lax_check([[
         local function foo(): number, string
            return 1
         end
      ]], {}))

      it("with too many indirectly", util.strict_check_type_error([[
         local function bar(): number, string, string
            return 1, "hello", "wat"
         end

         local function foo(): number, string
            return bar()
         end
      ]], {
         { msg = "excess return values" }
      }, {}))

      it("with too few indirectly", util.strict_and_lax_check([[
         local function bar(): number
            return 1
         end

         local function foo(): number, string
            return bar()
         end
      ]], {}))
   end)

   describe("type checking", function()
      it("checks all returns of a call with proper locations", util.check_type_error([[
         local function foo1(): (boolean, any) return coroutine.resume(nil) end
         local function foo2(): (boolean, string) return coroutine.resume(nil) end
      ]], {
         { y = 2, x = 58, msg = "in return value: got <any type>, expected string" }
      }))

      it("expands tuples but not nominals (regression test for #249)", util.check [[
         local type A = number
         local type B = record
           h: unionAorB
           t: unionAorB
         end
         local type unionAorB = A | B

         local function head(n: unionAorB): unionAorB
           if n is B then
             return n.h  --  10
           else
             assert(false, 'head of A; ' .. n as A)
           end
         end
      ]])

      it("flow expected type into return expressions (regression test for #553)", util.check [[
         local enum Type
            "add"
            "change"
            "delete"
         end

         local function foo(a: integer, b: integer): Type
            return a == 0 and "delete" or
                   b == 0 and "add"    or
                              "change"
         end
      ]])
   end)

   describe("module is inferred", function()
      it("from first use (#334)", util.check [[
         if math.random(2) then
            return "hello"
         else
            return "world"
         end
      ]])

      it("detects mismatches (#334)", util.check_type_error([[
         if math.random(2) then
            return "hello"
         else
            return 123
         end
      ]], {
         { msg = "in return value (inferred at foo.tl:2:13): got integer, expected string" }
      }))
   end)

end)
