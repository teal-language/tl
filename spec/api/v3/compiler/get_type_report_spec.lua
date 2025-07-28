local util = require("spec.util")
local teal = require("teal")

local function compiler_get_type_report(code)
   local compiler = teal.compiler()
   compiler:enable_type_reporting(true)
   local input = compiler:input(code)
   input:check()

   local tr = compiler:get_type_report()
   return tr
end

describe("Compiler.get_type_report", function()
   it("skips over label nodes (#393)", function()
      local tr = compiler_get_type_report([[
         local function a()
            ::continue::
         end
      ]])
      assert(tr)
   end)

   it("reports resolved type on poly function calls", function()
      local tr = compiler_get_type_report([[
         local record R
            f: function(string)
            f: function(integer)

            g: function<X>(string, X): {X}
            g: function<T>(integer, T): T
         end

         R.f("hello")
         R.f(9)
         local z = R.g(123, "hello")
      ]])

      local y = 9
      local x = 11
      local type_at_y_x = tr.by_pos["<input>.tl"][y][x]
      assert.same(tr.types[type_at_y_x].str, "function(string)")

      y = 11
      x = 21
      type_at_y_x = tr.by_pos["<input>.tl"][y][x]
      assert.same(tr.types[type_at_y_x].str, "function(integer, T): T")
   end)

   it("reports record functions in record field list", function()
      local tr = compiler_get_type_report([[
         local record Point
            x: number
            y: number
         end

         function Point:init(x: number, y: number)
            self.x = x
            self.y = y
         end
      ]])

      local y = 1
      local x = 10
      local type_at_y_x = tr.by_pos["<input>.tl"][y][x]
      assert(tr.types[type_at_y_x].str == "Point")
      local fields = {}
      for k, _ in pairs(tr.types[type_at_y_x].fields) do
         table.insert(fields, k)
      end
      table.sort(fields)
      assert.same(fields, {"init", "x", "y"})
   end)

   it("reports inherited interface fields in record field list, case 1 (#852)", function()
      local tr = compiler_get_type_report([[
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
      ]])

      local y = 5
      local x = 10
      local type_at_y_x = tr.by_pos["<input>.tl"][y][x]
      assert(tr.types[type_at_y_x].str == "Foo")
      local fields = {}
      for k, _ in pairs(tr.types[type_at_y_x].fields) do
         table.insert(fields, k)
      end
      table.sort(fields)
      assert.same(fields, {"bar", "qux"})
   end)

   it("reports inherited interface fields in record field list, case 2 (#852)", function()
      local tr = compiler_get_type_report([[
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
      ]])

      local y = 5
      local x = 10
      local type_at_y_x = tr.by_pos["<input>.tl"][y][x]
      assert(tr.types[type_at_y_x].str == "Foo")
      local fields = {}
      for k, _ in pairs(tr.types[type_at_y_x].fields) do
         table.insert(fields, k)
      end
      table.sort(fields)
      assert.same(fields, {"bar", "qux"})
   end)

   it("reports inherited interface fields in record field list, case 3 (#852)", function()
      local tr = compiler_get_type_report([[
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
      ]])

      local y = 5
      local x = 10
      local type_at_y_x = tr.by_pos["<input>.tl"][y][x]
      assert(tr.types[type_at_y_x].str == "Foo")
      local fields = {}
      for k, _ in pairs(tr.types[type_at_y_x].fields) do
         table.insert(fields, k)
      end
      table.sort(fields)
      assert.same(fields, {"bar", "qux"})
   end)

   it("reports reference of a nominal type", function()
      local tr = compiler_get_type_report([[
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
      ]])

      local y = 7
      local x = 24
      local type_at_y_x = tr.by_pos["<input>.tl"][y][x]
      local ti = tr.types[type_at_y_x]
      assert(ti)
      assert.same(ti.str, "Operator")
      assert(ti.ref)
      local ti_ref = tr.types[ti.ref]
      assert(ti ~= ti.ref)
      assert.same(ti_ref.str, "Operator")
   end)

   it("reports self of a record function (#884)", function()
      local tr = compiler_get_type_report([[
         local record mod
             foo1: function(self)
             foo2: function(self)
         end

         function mod:foo1()
         end

         function mod.foo2(self: mod)
         end
      ]])

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
      local tr = compiler_get_type_report([[
         local record rec
            metamethod __eq: function(rec, rec): boolean
         end
      ]])

      local y = 1
      local x = 10
      local rec_type_id = tr.by_pos["<input>.tl"][y][x]
      local rec_type = tr.types[rec_type_id]
      assert(rec_type)
      assert.same(rec_type.str, "rec")
      assert(rec_type.meta_fields)
      assert(rec_type.meta_fields.__eq)
   end)

   it("reports typeargs of records", function()
      local tr = compiler_get_type_report([[
         local record R<T, U>
         end
      ]])

      local y = 1
      local x = 10
      local type_at_y_x = tr.by_pos["<input>.tl"][y][x]
      assert(tr.types[type_at_y_x].str == "R<T, U>")
      assert(tr.types[type_at_y_x].typeargs)
      assert(tr.types[type_at_y_x].typeargs[1])
      assert.same(tr.types[type_at_y_x].typeargs[1][1], "T")
      assert.same(tr.types[type_at_y_x].typeargs[1][2], nil)
      assert(tr.types[type_at_y_x].typeargs[2])
      assert.same(tr.types[type_at_y_x].typeargs[2][1], "U")
      assert.same(tr.types[type_at_y_x].typeargs[2][2], nil)
   end)
   it("reports typeargs of interfaces", function()
      local tr = compiler_get_type_report([[
         local interface I<T, U>
         end
      ]])

      local y = 1
      local x = 10
      local type_at_y_x = tr.by_pos["<input>.tl"][y][x]
      assert(tr.types[type_at_y_x].str == "I<T, U>")
      assert(tr.types[type_at_y_x].typeargs)
      assert(tr.types[type_at_y_x].typeargs[1])
      assert.same(tr.types[type_at_y_x].typeargs[1][1], "T")
      assert.same(tr.types[type_at_y_x].typeargs[1][2], nil)
      assert(tr.types[type_at_y_x].typeargs[2])
      assert.same(tr.types[type_at_y_x].typeargs[2][1], "U")
      assert.same(tr.types[type_at_y_x].typeargs[2][2], nil)
   end)
   it("reports typeargs of generic functions", function()
      local tr = compiler_get_type_report([[
         local function f<T, U>()
         end
      ]])

      local y = 1
      local x = 10
      local type_at_y_x = tr.by_pos["<input>.tl"][y][x]
      assert(tr.types[type_at_y_x].str == "function<T, U>()")
      assert(tr.types[type_at_y_x].typeargs)
      assert(tr.types[type_at_y_x].typeargs[1])
      assert.same(tr.types[type_at_y_x].typeargs[1][1], "T")
      assert.same(tr.types[type_at_y_x].typeargs[1][2], nil)
      assert(tr.types[type_at_y_x].typeargs[2])
      assert.same(tr.types[type_at_y_x].typeargs[2][1], "U")
      assert.same(tr.types[type_at_y_x].typeargs[2][2], nil)
   end)
   it("reports constrained typeargs of generic functions", function()
      local tr = compiler_get_type_report([[
         local interface I
         end

         local function f<T is I, U>()
         end
      ]])

      local cy = 4
      local cx = 32
      local constraint_type_at_y_x = tr.by_pos["<input>.tl"][cy][cx]
      assert(tr.types[constraint_type_at_y_x].str == "I")
      local fy = 4
      local fx = 10
      local func_type_at_y_x = tr.by_pos["<input>.tl"][fy][fx]
      assert(tr.types[func_type_at_y_x].str == "function<T is I, U>()")
      assert(tr.types[func_type_at_y_x].typeargs)
      assert(tr.types[func_type_at_y_x].typeargs[1])
      assert.same(tr.types[func_type_at_y_x].typeargs[1][1], "T")
      assert.same(tr.types[func_type_at_y_x].typeargs[1][2], constraint_type_at_y_x)
      assert(tr.types[func_type_at_y_x].typeargs[2])
      assert.same(tr.types[func_type_at_y_x].typeargs[2][1], "U")
      assert.same(tr.types[func_type_at_y_x].typeargs[2][2], nil)
   end)
end)
