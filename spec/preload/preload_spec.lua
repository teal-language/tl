local tl = require("tl")
local util = require("spec.util")

describe("preload", function()
   it("exports global types", function ()
      -- ok
      util.mock_io(finally, {
         ["love.d.tl"] = [[
            global type love_graphics = record
               print: function(text: string)
            end

            global type love = record
               draw: function()
               graphics: love_graphics
            end
         ]],
         ["foo.tl"] = [[
            function love.draw()
               love.graphics.print("<3")
            end
         ]],
      })

      local result, err = tl.process("foo.tl", assert(tl.init_env(false, nil, nil, {"love"})))

      assert.same(nil, err)
      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
   end)
   it("can require multiple modules", function()
      -- ok
      util.mock_io(finally, {
         ["love.d.tl"] = [[
            global type love_graphics = record
               print: function(text: string)
            end

            global type love = record
               draw: function()
               graphics: love_graphics
            end
         ]],
         ["hate.d.tl"] = [[
            global type hate_graphics = record
               print: function(text: string)
            end

            global type hate = record
               draw: function()
               graphics: hate_graphics
            end
         ]],
         ["foo.tl"] = [[
            function love.draw()
               love.graphics.print("<3")
            end

            function hate.draw()
               hate.graphics.print(">:(")
            end
         ]],
      })

      local result, err = tl.process("foo.tl", assert(tl.init_env(false, nil, nil, {"love", "hate"})))

      assert.same(nil, err)
      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
   end)
end)
