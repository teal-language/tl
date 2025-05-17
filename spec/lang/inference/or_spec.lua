
local util = require("spec.util")

describe("inference in 'or' expressions", function()
   it("`v is T and v or _` for a truthy T infers that _ is of type not-T (#878)", util.check([[
      local record R end

      local function convert(_: string): R end

      local u: string | R
      local _r: R = u is R
         and u
         or convert(u)
   ]]))
   it("or expressions work in function args", util.check([[
      local function test(_s: string, _x ?: integer) end

      local function do_the_test(y ?: integer)
         test("", y)
         test("", y or 0)
      end
   ]]))
   it("doesn't immediately convert to any", util.check([[
      local a: any = 5 or 7
      local a_is_integer: integer = a
   ]]))
   it("works with expected types", util.check([[
      local a: integer|string = 5 or "string"
   ]]))
   it("works with sub and superclasses", util.check([[
      local interface Super end
      local interface SubA is Super end
      local interface SubB is Super end

      local sa: SubA
      local sb: SubB

      local sc: Super = sa or sb
   ]]))
   it("does not drop nominal type on assignment, avoiding ambiguity", util.check_warnings([[
      local interface Type
      end

      local record UnionType is Type
         types: {Type}
      end

      local function g(t: Type): Type
         return t
      end

      local function f(t: Type)
         t = g(t)
         local _ = t is UnionType and t.types or { t }
      end
   ]], {
      { msg = "unused function f" }
   }, {}))

   it("infers `A|B or B` to `A|B`, avoiding ambiguity", util.check_warnings([[
      local record A where self.field == "a"
         field: string
      end
      local record B where self.field == "b"
         field: string
      end

      local ab: A|B
      local b: B

      local c = ab or b
   ]], {
      { msg = "unused variable c: A | B" }
   }, {}))
end)
