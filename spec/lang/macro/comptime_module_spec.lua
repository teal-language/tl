local tl = require("tl")
local lua_gen = require("teal.gen.lua_generator")
local util = require("spec.util")

describe("comptime macro modules", function()
   it("imports .m.tl expression macros and erases comptime declarations", function()
      util.mock_io(finally, {
         ["mod.m.tl"] = [[
            local macro inc!(x: Expression): Expression
               return `$x + 1`
            end

            return {
               inc = inc,
            }
         ]],
         ["main.tl"] = [[
            local m<comptime> = require "mod"
            local y = m.inc!(2)
         ]],
      })

      local result, err = tl.check_file("main.tl")
      assert.is_nil(err)
      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)

      local out, gen_err = lua_gen.generate(result.ast, "5.4")
      assert.is_nil(gen_err)
      out = out:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      assert.match("local y = 2 %+ 1", out)
      assert.is_nil(out:match("local m"))
   end)

   it("supports exported macro aliases from return mapping", function()
      util.mock_io(finally, {
         ["mod.m.tl"] = [[
            local macro inc!(x: Expression): Expression
               return `$x + 1`
            end

            return {
               plus_one = inc,
            }
         ]],
         ["main.tl"] = [[
            local m<comptime> = require "mod"
            local y = m.plus_one!(10)
         ]],
      })

      local result, err = tl.check_file("main.tl")
      assert.is_nil(err)
      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)

      local out, gen_err = lua_gen.generate(result.ast, "5.4")
      assert.is_nil(gen_err)
      out = out:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      assert.match("local y = 10 %+ 1", out)
   end)

   it("supports Statement macro arguments from imported signatures", function()
      util.mock_io(finally, {
         ["mod.m.tl"] = [[
            local macro wrap!(s: Statement, e: Expression): Statement
               local out = block("statements")
               table.insert(out, s)
               table.insert(out, `print($e)`)
               return out
            end

            return {
               wrap = wrap,
            }
         ]],
         ["main.tl"] = [[
            local m<comptime> = require "mod"

            m.wrap!(
               for _, x in ipairs({1, 2}) do
                  print(x)
               end,
               "ok"
            )
         ]],
      })

      local result, err = tl.check_file("main.tl")
      assert.is_nil(err)
      assert.same({}, result.syntax_errors)
      assert.same({}, result.type_errors)

      local out, gen_err = lua_gen.generate(result.ast, "5.4")
      assert.is_nil(gen_err)
      out = out:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
      assert.match("for _, x in ipairs%(%{ 1, 2 %}%) do print%(x%) end; print%(\"ok\"%)", out)
   end)

   it("reports invalid export mappings in macro modules", function()
      util.mock_io(finally, {
         ["bad.m.tl"] = [[
            local macro inc!(x: Expression): Expression
               return `$x + 1`
            end

            return {
               inc = nope,
            }
         ]],
         ["main.tl"] = [[
            local m<comptime> = require "bad"
            local y = 1
         ]],
      })

      local result, err = tl.check_file("main.tl")
      assert.is_nil(err)
      assert.truthy(#result.syntax_errors > 0)

      local found = false
      for _, e in ipairs(result.syntax_errors) do
         if e.msg:match("exported macro 'inc' refers to unknown local macro 'nope'") then
            found = true
            break
         end
      end
      assert.is_true(found)
   end)
end)
