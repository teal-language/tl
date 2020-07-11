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
   end)

end)
