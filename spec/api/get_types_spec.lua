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

            g: function<X>(string, X): {X}
            g: function<T>(integer, T): T
         end

         R.f("hello")
         R.f(9)
         local z = R.g(123, "hello")
      ]], env))

      local tr, trenv = tl.get_types(result)
      local y = 9
      local x = 11
      local type_at_y_x = tr.by_pos[""][y][x]
      assert.same(tr.types[type_at_y_x].str, "function(string)")

      y = 11
      x = 21
      type_at_y_x = tr.by_pos[""][y][x]
      assert.same(tr.types[type_at_y_x].str, "function(integer, T): T")
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

   it("reports self of a record function (#884)", function()
      local env = tl.init_env()
      env.report_types = true
      local result = assert(tl.check_string([[
         local record mod
             foo1: function(self)
             foo2: function(self)
         end

         function mod:foo1()
         end

         function mod.foo2(self: mod)
         end
      ]], env))

      local tr, trenv = tl.get_types(result)
      assert.same(#tr.symbols, 9)
      local syms = {
         { 1, "@{" },
         { 1, "mod" },
         { 6, "@{" },
         { 6, "self" },
         { 7, "@}" },
         { 9, "@{" },
         { 9, "self" },
         { 10, "@}" },
         { 11, "@}" }
      }
      for i, s in ipairs(tr.symbols) do
         assert.same(s[1], syms[i][1])
         assert.same(s[3], syms[i][2])
      end
   end)

   it("exposes metafields", function()
      local env = tl.init_env()
      env.report_types = true
      local result = assert(tl.check_string([[
         local record rec
            metamethod __eq: function(rec, rec): boolean
         end
      ]], env))

      local tr, trenv = tl.get_types(result)
      local y = 1
      local x = 10
      local rec_type_id = tr.by_pos[""][y][x]
      local rec_type = tr.types[rec_type_id]
      assert(rec_type)
      assert.same(rec_type.str, "rec")
      assert(rec_type.meta_fields)
      assert(rec_type.meta_fields.__eq)
   end)
end)
