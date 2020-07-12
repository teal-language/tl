local util = require("spec.util")

describe("typecheck errors", function()
   it("type errors include filename", util.check_type_error([[
      local x: string = 1
   ]], {
      { filename = "foo.tl" }
   }))

   it("type errors in a required package include filename of required file", function ()
      util.mock_io(finally, {
         ["bar.tl"] = "local x: string = 1",
      })
      util.check_type_error([[
         local bar = require "bar"
      ]], {
         { filename = "bar.tl" }
      })
   end)

   it("unknowns include filename", util.lax_check([[
      local x: string = b
   ]], {
      { msg = "b", filename = "foo.lua" }
   }))

   it("unknowns in a required package include filename of required file", function ()
      util.mock_io(finally, {
         ["bar.lua"] = "local x: string = b"
      })
      util.lax_check([[
         local bar = require "bar"
      ]], {
         { msg = "b", filename = "bar.lua" }
      })
   end)
end)
