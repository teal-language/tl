local util = require("spec.util")

describe("lax mode", function()
   it("vararg arity of returns (regression test for #55)", util.lax_check([[
      function f1()
              return { data = function () return 1, 2, 3 end }
      end

      function f2()
              local one, two, three
              local data = f1().data
              one, two, three = data()
              return one, two, three
      end

      print(f2())
   ]], {
      { msg = "one" },
      { msg = "two" },
      { msg = "three" },
      { msg = "data" },
   }))

   it("defines lax arity of returns in function literals (#736)", util.lax_check([[
      -- f: function(unknown...):unknown...
      local f = function()
          return function() end
      end

      for a, b in f() do
      end

      -- g: function(unknown...):unknown...
      local function g()
          return function() end
      end

      for x, y in g() do
      end
   ]], {
      { msg = "a" },
      { msg = "b" },
      { msg = "x" },
      { msg = "y" },
   }))
end)
