local tl = require("tl")
local util = require("spec.util")

describe("preload", function()
   it("exports global types", function ()
      -- ok
      util.mock_io(finally, {
         ["love.d.tl"] = [[
            global love_graphics = record
               print: function(text: string)
            end

            global love = record
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

      local result, err = tl.process("foo.tl", nil, nil, nil, {"love"})

      assert.same(nil, err)
      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
      assert.same({}, result.unknowns)
   end)
   it("can require multiple modules", function()
      -- ok
      util.mock_io(finally, {
         ["love.d.tl"] = [[
            global love_graphics = record
               print: function(text: string)
            end

            global love = record
               draw: function()
               graphics: love_graphics
            end
         ]],
         ["hate.d.tl"] = [[
            global hate_graphics = record
               print: function(text: string)
            end

            global hate = record
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

      local result, err = tl.process("foo.tl", nil, nil, nil, {"love", "hate"})

      assert.same(nil, err)
      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)
      assert.same({}, result.unknowns)
   end)
   it("returns an error when a module doesn't exist", function ()
      -- ok
      util.mock_io(finally, {
         ["foo.tl"] = [[
            function love.draw()
               love.graphics.print("<3")
            end
         ]],
      })

      local result, err = tl.process("foo.tl", nil, nil, nil, {"love"})

      assert.same(nil, result)
      assert.is_not_nil(err)
    end)
end)
