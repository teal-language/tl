local tl = require("tl")

describe("tl.get_types", function()
   it("skips over label nodes (#393)", function()
      local env = tl.init_env()
      env.report_types = true
      local result = assert(tl.check_string([[
         local function a()
            ::continue::
         end
      ]], env))

      local tr, trenv = tl.get_types(result)
      assert(tr)
      assert(trenv)
   end)

   it("reports resolved type on poly function calls", function()
      local env = tl.init_env()
      env.report_types = true
      local result = assert(tl.check_string([[
         local record R
            f: function(string)
            f: function(integer)
         end

         R.f("hello")
      ]], env))

      local tr, trenv = tl.get_types(result)
      local y = 6
      local x = 11
      local type_at_y_x = tr.by_pos[""][y][x]
      assert(tr.types[type_at_y_x].str == "function(string)")
   end)

   it("reports record functions in record field list", function()
      local env = tl.init_env()
      env.report_types = true
      local result = assert(tl.check_string([[
         local record Point
            x: number
            y: number
         end

         function Point:init(x: number, y: number)
            self.x = x
            self.y = y
         end
      ]], env))

      local tr, trenv = tl.get_types(result)
      local y = 1
      local x = 10
      local type_at_y_x = tr.by_pos[""][y][x]
      assert(tr.types[type_at_y_x].str == "Point")
      local fields = {}
      for k, _ in pairs(tr.types[type_at_y_x].fields) do
         table.insert(fields, k)
      end
      table.sort(fields)
      assert.same(fields, {"init", "x", "y"})
   end)
end)
