local util = require("spec.util")

describe("string", function()

   describe("byte", function()
      it("can return multiple values", util.check [[
         local n1, n2 = ("hello"):byte(1, 2)
         print(n1 + n2)
      ]])
   end)

   describe("char", function()
      it("can take multiple intputs", util.check [[
         print(string.char(104, 101, 108, 108, 111) .. "!")
      ]])
   end)

end)
