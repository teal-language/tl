local util = require("spec.util")

describe("union declaration", function()
   it("declares a union", util.check [[
      local t: number | string
   ]])

   it("declares a long union", util.check [[
      local t: number | string | boolean | function(number | string, {string | boolean}):{number | string:string | boolean}
   ]])
end)
