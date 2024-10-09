local util = require("spec.util")

describe(".", function()
   describe("on records", function()
      it("ok", util.check([[
         local x = { foo = "f" }
         print(x.foo)
      ]]))

      it("fail", util.check_type_error([[
         local x = { foo = "f" }
         print(x.bar)
      ]], {
         { y = 2, x = 18, msg = "invalid key 'bar' in record 'x'" }
      }))
   end)

   describe("on raw tables", function()
      it("using table", util.check([[
         local x: table = { [true] = 12, [false] = 13 }
         x.foo = 9
         print(x.foo)
      ]]))

      it("using {any:any}", util.check([[
         local x: {any:any} = {}
         x.foo = 9
         x["hello"] = 12
         x[false] = "world"
         print(x.foo)
      ]]))
   end)

   describe("on maps with enum keys", function()
      it("ok", util.check([[
         global record R
             record StrategyType
                 -- ...
             end
             enum StrategyName
                "BestEffort"
                "Precise"
             end
             Strategy: {StrategyName:StrategyType}
             fn: function(name: string, n: number, strategy: R.StrategyType): nil
         end

         R.fn("hello", 1000, R.Strategy.Precise)
         R.fn("hello", 1000, R.Strategy.BestEffort)
      ]]))

      it("fail", util.check_type_error([[
         global record R
             record StrategyType
                 -- ...
             end
             enum StrategyName
                "BestEffort"
                "Precise"
             end
             Strategy: {StrategyName:StrategyType}
             fn: function(name: string, n: number, strategy: R.StrategyType): nil
         end

         R.fn("hello", 1000, R.Strategy.Invalid)
      ]], {
         { y = 13, x = 41, msg = "wrong index type: got string \"Invalid\", expected StrategyName" }
      }))
   end)
end)
