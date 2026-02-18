local util = require("spec.util")

describe("forin", function()
   it("5.3: doesn't generate control variable that is local to the iteration", util.gen([[
      local mypairs: function({string:string}): (function(string): (string, string))

      local t: {string:string} = { k1 = "a", k2 = "b", k3 = "c" }

      for k, v in mypairs(t) do
         k = k .. "!"
         print(k)
         k = "yes"
         print(k)
      end
   ]], [[
      local mypairs

      local t = { k1 = "a", k2 = "b", k3 = "c" }

      for k, v in mypairs(t) do
         k = k .. "!"
         print(k)
         k = "yes"
         print(k)
      end
   ]], "5.3"))

   it("5.4: generates control variable that is local to the iteration", util.gen([[
      local t: {string:string} = { k1 = "a", k2 = "b", k3 = "c" }

      for k, v in pairs(t) do
         k = k .. "!"
         print(k)
         k = "yes"
         print(k)
      end
   ]], [[
      local t = { k1 = "a", k2 = "b", k3 = "c" }

      for k, v in pairs(t) do local k = k
         k = k .. "!"
         print(k)
         k = "yes"
         print(k)
      end
   ]], "5.4"))

   it("5.4: does not generate control variable if not assigned to", util.gen([[
      local t: {string:string} = { k1 = "a", k2 = "b", k3 = "c" }

      for k, v in pairs(t) do
         local k2 = k .. "!"
         print(k2)
         k2 = "yes"
         print(k2)
      end
   ]], [[
      local t = { k1 = "a", k2 = "b", k3 = "c" }

      for k, v in pairs(t) do
         local k2 = k .. "!"
         print(k2)
         k2 = "yes"
         print(k2)
      end
   ]], "5.4"))
end)
