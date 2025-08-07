local tl = require('tl')
local lua_gen = require('teal.gen.lua_generator')

describe('macro import_types', function()
   it('parses and generates import_types macro', function()
      local code = [[
         local macro import_types!(var: Block, modname: Block, ...: Block): Block
            expect(var, "identifier")
            expect(modname, "string")
            local out = block("statements")
            table.insert(out, `local $var = require($modname)`)
            for i = 1, select("#", ...) do
               local b = select(i, ...)
               expect(b, "identifier")
               table.insert(out, `local type $b = $var.$b`)
            end
            return out
         end
      ]]
      local ast, errs = tl.parse(code)
      assert.same({}, errs)
      local macro = ast[1]
      local lua, err = lua_gen.generate(macro.body, '5.4')
      assert.is_nil(err)
      assert.match('local function import_types', lua, 1, true)
      assert.match('expect%(%s*var%s*,%s*"identifier"%s*%)', lua)
      assert.match('expect%(%s*modname%s*,%s*"string"%s*%)', lua)
      assert.match('block%(%s*"statements"%s*%)', lua)
      assert.match('clone%(%s*var%s*%)', lua)
      assert.match('clone%(%s*modname%s*%)', lua)
      assert.match('clone%(%s*b%s*%)', lua)
      assert.match('kind%s*=%s*"nominal_type"', lua)
      assert.match('for i = 1, select%("#", %.%.%.%) do', lua)
      assert.match('return out', lua)
   end)

   it('lua generator ignores macros by default', function()
      local ast, errs = tl.parse([[ local macro foo!(): Block end ]])
      assert.same({}, errs)
      local lua, err = lua_gen.generate(ast, '5.4')
      assert.is_nil(err)
      assert.same('', lua)
   end)
end)
