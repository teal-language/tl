
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
end)
