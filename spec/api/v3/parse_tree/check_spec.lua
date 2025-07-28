local util = require("spec.util")
local teal = require("teal")

describe("ParseTree.check", function()
   it("can check Teal code", function()
      local tl_code = [[
         local foo: string = "hello"
         local planet: integer = 3
      ]]

      local compiler = teal.compiler()
      local input = compiler:input(tl_code)
      local parse_tree = input:parse()
      local module, check_err = parse_tree:check()

      assert(module)
      assert.same(0, #check_err.syntax_errors)
      assert.same(0, #check_err.type_errors)
      assert.same(2, #check_err.warnings)
   end)

   it("reports syntax errors from the lexer", function()
      local tl_code = [[
         2.e + 1
      ]]

      local compiler = teal.compiler()
      local input = compiler:input(tl_code)
      local parse_tree = input:parse()
      local module, check_err = parse_tree:check()

      assert.is_nil(module)
      assert.same(1, #check_err.syntax_errors)
      assert.same(0, #check_err.type_errors)
      assert.same(0, #check_err.warnings)
   end)

   it("reports syntax errors from parsing", function()
      local tl_code = [[
         if if if
      ]]

      local compiler = teal.compiler()
      local input = compiler:input(tl_code)
      local parse_tree = input:parse()
      local module, check_err = parse_tree:check()

      assert.is_nil(module)
      assert.same(3, #check_err.syntax_errors)
      assert.same(0, #check_err.type_errors)
      assert.same(0, #check_err.warnings)
   end)

   it("reports type errors from checking", function()
      local tl_code = [[
         local x: number = "oops"
      ]]

      local compiler = teal.compiler()
      local input = compiler:input(tl_code)
      local parse_tree = input:parse()
      local module, check_err = parse_tree:check()

      assert(module)
      assert.same(0, #check_err.syntax_errors)
      assert.same(1, #check_err.type_errors)
      assert.same(1, #check_err.warnings)
   end)

   it("when type reporting on, return both module and type errors from checking", function()
      local tl_code = [[
         local x: number = "oops"
      ]]

      local compiler = teal.compiler()
      compiler:enable_type_reporting(true)
      local input = compiler:input(tl_code)
      local parse_tree = input:parse()
      local module, check_err = parse_tree:check()

      assert(module)
      assert.same(0, #check_err.syntax_errors)
      assert.same(1, #check_err.type_errors)
      assert.same(1, #check_err.warnings)
   end)
end)
