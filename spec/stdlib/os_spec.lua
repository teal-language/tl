local util = require("spec.util")

describe("os", function()

   describe("date", function()
      it("with no arguments returns as string", util.check [[
         print("today is " .. os.date())
      ]])

      it("with arguments returns as string or a table", util.check [[
         local utctable = os.date("!*t")
         if not utctable is string then
            print(utctable.year)
            print(utctable.month)
            print(utctable.day)
         end
      ]])
   end)

end)
