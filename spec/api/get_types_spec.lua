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

   it("reports reference of a nominal type", function()
      local env = tl.init_env()
      env.report_types = true
      local result = assert(tl.check_string([[
         local record Operator
             operator: string
         end

         local record Node
             node1: Node
             operator: Operator
         end

         local function node_is_require_call(n: Node): string
             if n.operator and n.operator.operator == "." then
                return node_is_require_call(n.node1)
             end
         end
      ]], env))

      local tr, trenv = tl.get_types(result)
      local y = 7
      local x = 24
      local type_at_y_x = tr.by_pos[""][y][x]
      local ti = tr.types[type_at_y_x]
      assert(ti)
      assert.same(ti.str, "Operator")
      assert(ti.ref)
      local ti_ref = tr.types[ti.ref]
      assert(ti ~= ti.ref)
      assert.same(ti_ref.str, "Operator")
   end)
end)
