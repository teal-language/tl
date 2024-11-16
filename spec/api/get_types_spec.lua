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

   it("reports inherited interface fields in record field list, case 1 (#852)", function()
      local env = tl.init_env()
      env.report_types = true
      local result = assert(tl.check_string([[
         local interface IFoo
            bar: function(self)
         end

         local record Foo is IFoo
            -- Uncommenting this causes 'bar' to be hidden from fields of Foo
            qux:function(Foo)

            -- Using this style doesn't have this problem
            -- qux:function(self)
         end

         function Foo:bar()
         end

         function Foo:qux()
         end

         local record Runner
            foo: Foo
         end

         function Runner:run()
            -- self.foo.
         end
      ]], env))

      local tr, trenv = tl.get_types(result)
      local y = 5
      local x = 10
      local type_at_y_x = tr.by_pos[""][y][x]
      assert(tr.types[type_at_y_x].str == "Foo")
      local fields = {}
      for k, _ in pairs(tr.types[type_at_y_x].fields) do
         table.insert(fields, k)
      end
      table.sort(fields)
      assert.same(fields, {"bar", "qux"})
   end)

   it("reports inherited interface fields in record field list, case 2 (#852)", function()
      local env = tl.init_env()
      env.report_types = true
      local result = assert(tl.check_string([[
         local interface IFoo
            bar: function(self)
         end

         local record Foo is IFoo
            -- Uncommenting this causes 'bar' to be hidden from fields of Foo
            -- qux:function(Foo)

            -- Using this style doesn't have this problem
            qux:function(self)
         end

         function Foo:bar()
         end

         function Foo:qux()
         end

         local record Runner
            foo: Foo
         end

         function Runner:run()
            -- self.foo.
         end
      ]], env))

      local tr, trenv = tl.get_types(result)
      local y = 5
      local x = 10
      local type_at_y_x = tr.by_pos[""][y][x]
      assert(tr.types[type_at_y_x].str == "Foo")
      local fields = {}
      for k, _ in pairs(tr.types[type_at_y_x].fields) do
         table.insert(fields, k)
      end
      table.sort(fields)
      assert.same(fields, {"bar", "qux"})
   end)

   it("reports inherited interface fields in record field list, case 3 (#852)", function()
      local env = tl.init_env()
      env.report_types = true
      local result = assert(tl.check_string([[
         local interface IFoo
            bar: function(self)
         end

         local record Foo is IFoo
            -- Uncommenting this causes 'bar' to be hidden from fields of Foo
            -- qux:function(Foo)

            -- Using this style doesn't have this problem
            -- qux:function(self)
         end

         function Foo:bar()
         end

         function Foo:qux()
         end

         local record Runner
            foo: Foo
         end

         function Runner:run()
            -- self.foo.
         end
      ]], env))

      local tr, trenv = tl.get_types(result)
      local y = 5
      local x = 10
      local type_at_y_x = tr.by_pos[""][y][x]
      assert(tr.types[type_at_y_x].str == "Foo")
      local fields = {}
      for k, _ in pairs(tr.types[type_at_y_x].fields) do
         table.insert(fields, k)
      end
      table.sort(fields)
      assert.same(fields, {"bar", "qux"})
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
