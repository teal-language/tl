local util = require("spec.util")

describe("forin", function()
   describe("ipairs", function()
      it("with a single variable", util.check [[
         local t = { 1, 2, 3 }
         for i in ipairs(t) do
            print(i)
         end
      ]])

      it("with two variables", util.check [[
         local t = { 1, 2, 3 }
         for i, v in ipairs(t) do
            print(i, v)
         end
      ]])

      it("with nested ipairs", util.check [[
         local t = { {"a", "b"}, {"c"} }
         for i, a in ipairs(t) do
            for j, b in ipairs(a) do
               print(i, j, "value: " .. b)
            end
         end
      ]])

      it("unknown with nested ipairs", util.lax_check([[
         local t = {}
         for i, a in ipairs(t) do
            for j, b in ipairs(a) do
               print(i, j, "value: " .. b)
            end
         end
      ]], {
         { msg = "a" },
         { msg = "b" },
      }))

      it("rejects nested unknown ipairs", util.check_type_error([[
         local t = {}
         for i, a in ipairs(t) do
            for j, b in ipairs(a) do
               print(i, j, "value: " .. b)
            end
         end
      ]], {
         { msg = "attempting ipairs loop" },
         { msg = "attempting ipairs loop" },
      }))
   end)

   describe("pairs", function()
      it("rejects heterogenous records in pairs", util.check_type_error([[
         local type Rec = record
            n: number
            fun: function(number, number)
         end

         local r: Rec = {}

         function foo(init: Rec)
            for k, v in pairs(init) do
               r[k] = v
            end
         end
      ]], {
         { msg = "attempting pairs loop" },
         { msg = "not all fields have the same type" },
         { msg = "cannot index object of type Rec" },
      }))
   end)

   it("with an explicit iterator", util.check [[
      local function iter(t): number
      end
      local t = { 1, 2, 3 }
      for i in iter, t do
         print(i + 1)
      end
   ]])

   it("with an iterator declared as a function type", util.check [[
      local function it(): function(): string
         return nil
      end

      for v in it() do
      end
   ]])

   it("catches when too many values are passed", util.check_type_error([[
      local function it(): function(): string
         return nil
      end

      for k, v in it() do
      end
   ]], {
      { x = 14, y = 5, msg = "too many variables for this iterator; it produces 1 value" }
   }))

   it("catches when too many values are passed, smart behavior about tuples", util.check_type_error([[
      local record R
         fields: function({number, nil}, string): (function(): string)
         fields: function({number, number}, string): (function(): string, string)
         fields: function({number} | number, string): (function(): string...)
      end

      for a, b in R.fields({1}, "hello") do
         -- if you try to put "for a, b" here you get an error
      end
   ]], {
      { y = 7, "too many variables for this iterator; it produces 1 value" }
   }))

   describe("regression tests", function()
      it("with an iterator declared as a nominal (#183)", util.check [[
         local type Iterator = function(): string

         local function it(): Iterator
             return nil
         end

         for v in it() do
         end
      ]])

      it("type inference for variadic return (#237)", util.check [[
         local function unpacker<T>(arr: {{T}}): function(): T...
            local i = 0
            return function(): T...
               i = i + 1
               if not arr[i] then return end
               return table.unpack(arr[i])
            end
         end

         for a, b in unpacker{{'a', 'b'}, {'c', 'd'}, {'e', 'f'}} do
            print(a .. b)
         end
      ]])

      it("accepts nested unresolved values", util.lax_check([[
         function fun(xss)
           for _, xs in pairs(xss) do
             for _, x in pairs(xs) do
               for _, u in ipairs({}) do
                local v = x[u]
                _, v = next(v)
               end
             end
           end
         end
      ]], {
         { msg = "xss" },
         { msg = "_" },
         { msg = "xs" },
         { msg = "_" },
         { msg = "x" },
         { msg = "u" },
         { msg = "v" },
      }))
   end)
end)
