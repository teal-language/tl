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
         { msg = "argument 1: got <unknown type>" },
         { msg = "cannot use operator '..'" },
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
   it("with an iterator declared as a nominal (regression test for #183)", util.check [[
      local type Iterator = function(): string

      local function it(): Iterator
          return nil
      end

      for _, v in it() do
      end
   ]])
   it("with an iterator declared as a function type", util.check [[
      local function it(): function(): string
         return nil
      end

      for _, v in it() do
      end
   ]])
   describe("regressions", function()
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
