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
      })()
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
      })()
   end)

   it("type mismatches across modules report their module names", function ()
      util.mock_io(finally, {
         ["aaa.tl"] = [[
            local record aaa
               record Thing
                  x: number
               end
            end
            return aaa
         ]],
         ["bbb.tl"] = [[
            local record bbb
               record Thing
                  x: string
               end
            end
            return bbb
         ]]
      })
      util.check_type_error([[
         local aaa = require("aaa")
         local bbb = require("bbb")

         local b: bbb.Thing = {}

         local function myfunc(a: aaa.Thing)
            print(a.x + 1)
         end

         myfunc(b)
      ]], {
         { msg = "bbb.Thing is not a aaa.Thing" }
      })()
   end)

   it("localized type mismatches across module report their filenames", function ()
      util.mock_io(finally, {
         ["aaa.tl"] = [[
            local record Thing
               x: number
            end

            local record aaa
            end

            function aaa.myfunc(a: Thing)
               print(a.x + 1)
            end

            return aaa
         ]],
         ["bbb.tl"] = [[
            local record bbb

               record Thing
                  x: string
               end
            end
            return bbb
         ]]
      })
      util.check_type_error([[
         local aaa = require("aaa")
         local bbb = require("bbb")

         local Thing = bbb.Thing

         local b: Thing = {}

         aaa.myfunc(b)
      ]], {
         { msg = "argument 1: Thing (defined in bbb.tl:4) is not a Thing (defined in aaa.tl:1)" }
      })()
   end)

   it("type mismatches across local type names report their provenance", function ()
      util.mock_io(finally, {
         ["aaa.tl"] = [[
            local record Thing
               x: number
            end

            local record aaa
            end

            function aaa.myfunc(a: Thing)
               print(a.x + 1)
            end

            return aaa
         ]],
         ["bbb.tl"] = [[
            local record Thing
               x: string
            end

            local record bbb
            end

            function bbb.get_thing(): Thing
               return {}
            end

            return bbb
         ]]
      })
      util.check_type_error([[
         local aaa = require("aaa")
         local bbb = require("bbb")

         local b = bbb.get_thing()

         aaa.myfunc(b)
      ]], {
         { msg = "argument 1: Thing (defined in bbb.tl:1) is not a Thing (defined in aaa.tl:1)" }
      })()
   end)

end)
