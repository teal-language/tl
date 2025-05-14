
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
   it("works with expected types", util.check([[
      local a: integer|string = 5 or "string"
   ]]))
end)
