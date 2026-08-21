local tl = require('tl')
local lua_generator = require('teal.gen.lua_generator')

describe('macro body for-loop control variables', function()
   it('allows a numeric for body to write to the control variable', function()
      local code = [[
         local macro thrice!(x: Expression)
            local out = block('statements')
            for i = 1, 3 do
               i = i + 10
               table.insert(out, `$x`)
            end
            return out
         end

         thrice!(print('hi'))
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_generator.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub("^%s+", ""):gsub("%s+$", "")
      assert.same("print('hi'); print('hi'); print('hi')", out)
   end)

   it('allows a generic for body to write to the control variable', function()
      local code = [[
         local macro each!(x: Expression)
            local out = block('statements')
            for word in ('a b'):gmatch('%a+') do
               word = word .. '!'
               table.insert(out, `$x`)
            end
            return out
         end

         each!(print('hi'))
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_generator.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub("^%s+", ""):gsub("%s+$", "")
      assert.same("print('hi'); print('hi')", out)
   end)

   it('does not disturb loops that never write the control variable', function()
      local code = [[
         local macro twice!(x: Expression)
            local out = block('statements')
            for _ = 1, 2 do
               table.insert(out, `$x`)
            end
            return out
         end

         twice!(print('hi'))
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local out, err = lua_generator.generate(ast, '5.4')
      assert.is_nil(err)
      out = out:gsub("^%s+", ""):gsub("%s+$", "")
      assert.same("print('hi'); print('hi')", out)
   end)
end)