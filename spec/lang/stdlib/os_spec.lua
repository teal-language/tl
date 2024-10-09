local util = require("spec.util")

describe("os", function()

   describe("date", function()
      it("with no arguments returns as string", util.check([[
         print("today is " .. os.date())
      ]]))

      it("can return a table if requested", util.check([[
         local utctable = os.date("!*t")
         print(utctable.year)
         print(utctable.month)
         print(utctable.day)

         local futuretable = os.date("*t", os.time() + 3600)
         print(futuretable.year)
         print(futuretable.month)
         print(futuretable.day)
      ]]))

      it("can return a string if another format is given", util.check([[
         print("Today is " .. os.date("%A, %F"))
      ]]))
   end)

end)
