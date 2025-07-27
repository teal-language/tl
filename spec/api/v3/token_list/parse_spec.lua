local util = require("spec.util")
local teal = require("teal")

describe("TokenList.parse", function()
   it("can parse Teal code", function()
      local tl_code = [[
         local foo: string = "hello"
         local planet: integer = 3
      ]]

      local compiler = teal.compiler()
      local input = compiler:input(tl_code)
      local token_list = input:lex()
      local parse_tree, err = token_list:parse()

      assert(parse_tree.ast)
   end)

   it("reports syntax errors from the lexer", function()
      local tl_code = [[
         2.e + 1
      ]]

      local compiler = teal.compiler()
      local input = compiler:input(tl_code)
      local token_list = input:lex()
      local parse_tree, err = token_list:parse()

      assert(parse_tree.ast)
      assert.same(1, #err)
      assert.same(err[1].msg, "malformed number")
   end)

   it("reports syntax errors from parsing", function()
      local tl_code = [[
         if if if
      ]]

      local compiler = teal.compiler()
      local input = compiler:input(tl_code)
      local token_list = input:lex()
      local parse_tree, err = token_list:parse()

      assert(parse_tree.ast)
      assert.same(3, #err)
      assert.same(err[1].msg, "syntax error")
      assert.same(err[1].y, 1)
      assert.same(err[1].x, 13)
   end)
end)
