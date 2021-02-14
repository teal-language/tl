local tl = require("tl")

describe("tl.process", function()
   it("skips over label nodes (#393)", function()
      local result = assert(tl.process_string([[
         local function a()
            ::continue::
         end
      ]]))

      local tr, trenv = tl.get_types(result)
      assert(tr)
      assert(trenv)
   end)
end)
