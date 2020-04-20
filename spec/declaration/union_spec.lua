local util = require("spec.util")

describe("union declaration", function()
   it("declares a union", util.check [[
      local t: number | string
   ]])

   it("declares a long union", util.check [[
      local t: number | string | boolean | function(number | string, {string | boolean}):{number | string:string | boolean}
   ]])

   it("unions can be parethesized for readability", util.check [[
      -- with parentheses
      local params1: {string: (string | {string})}
      params1 = { key1 = 'val2', key2 = {'val2', 'val3'}}

      -- without parentheses
      local params2: {string: string | {string}}
      params2 = { key1 = 'val2', key2 = {'val2', 'val3'}}
   ]])
end)
