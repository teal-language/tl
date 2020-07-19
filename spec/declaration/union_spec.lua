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

      -- with extra parentheses
      local params3: {string: ((((string | {string}))))}
      params3 = { key1 = 'val2', key2 = {'val2', 'val3'}}
   ]])

   it("unions can be declared nominally", util.check [[
      -- with parentheses
      local type P1 = (string | {string})
      local params1: {string:P1} = { key1 = 'val2', key2 = {'val2', 'val3'}}

      -- without parentheses
      local type P2 = string | {string}
      local params2: {string:P2} = { key1 = 'val2', key2 = {'val2', 'val3'}}

      -- with extra parentheses
      local type P3 = ((((string | {string}))))
      local params3: {string:P3} = { key1 = 'val2', key2 = {'val2', 'val3'}}
   ]])

   it("cannot declare a union between multiple table types", util.check_type_error([[
      local t: number | {number} | {string:boolean}
   ]], {
      { msg = "cannot discriminate a union between multiple table types" },
   }))

   it("cannot declare a union between multiple records", util.check_type_error([[
      local type R1 = record
         f: string
      end
      local type R2 = record
         g: string
      end
      local t: R1 | R2
   ]], {
      { msg = "cannot discriminate a union between multiple table types" },
   }))

   it("cannot declare a union between multiple function types", util.check_type_error([[
      local t: function():(number) | function():(string)
   ]], {
      { msg = "cannot discriminate a union between multiple function types" },
   }))

   it("cannot declare a union between multiple function types", util.check_type_error([[
      local type F1 = function(): number
      local type F2 = function(): string
      local t: F1|F2
   ]], {
      { msg = "cannot discriminate a union between multiple function types" },
   }))

end)
