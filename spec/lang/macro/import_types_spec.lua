local tl = require('tl')
local lua_gen = require('teal.gen.lua_generator')

describe('macro import_types', function()
   it('expands import_types at read time', function()
      local code = [[
         local macro import_types!(var: Expression, modname: Expression, ...: Expression): Statement
            expect(var, "variable")
            expect(modname, "string")
            local out = block("statements")
            table.insert(out, ```local $var = require($modname)```)
            for i = 1, select("#", ...) do
               local b = select(i, ...)
               expect(b, "variable")
               table.insert(out, ```local type $b = $var.$b```)
            end
            return out
         end

         import_types!(my, "mymod", T, U)
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local lua, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      assert.match('local my = require%(%s*"mymod"%s*%)', lua)
   end)

   it('lua generator ignores macros by default', function()
      local ast, errs = tl.parse([[ local macro foo!(): Block end ]])
      assert.same({}, errs)
      local lua, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      assert.same('', lua)
   end)
end)
