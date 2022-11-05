local tl = require("tl")

describe("tl.get_types", function()
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

   it("reports resolved type on poly function calls", function()
      local result = assert(tl.process_string([[
         local record R
            f: function(string)
            f: function(integer)
         end

         R.f("hello")
      ]]))

      local tr, trenv = tl.get_types(result)
      local y = 6
      local x = 11
      local type_at_y_x = tr.by_pos[""][y][x]
      assert(tr.types[type_at_y_x].str == "function(string)")
   end)
end)
