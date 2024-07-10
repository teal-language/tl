local util = require("spec.util")

describe("string literal code generation", function()
   it("generates Lua 5.1 compatible escape sequences in string literals", util.gen([[
      local _hex_bytes = "\xDe\xAD\xbE\xef\x05"
      local _unicode = "hello \u{4e16}\u{754C}"
      local _whitespace_removal = "hello\z

      , world!"
      local _source_new_lines_get_preserved = 0
   ]], [[
      local _hex_bytes = "\222\173\190\239\005"
      local _unicode = "hello \228\184\150\231\149\140"
      local _whitespace_removal = "hello, world!"


      local _source_new_lines_get_preserved = 0
   ]]))

   it("does not substitute escape sequences in [[strings]]", util.gen([==[
      local _literal_string = [[
         foo
         \000\xee\u{ffffff}
         bar
      ]]
   ]==], [==[
      local _literal_string = [[
         foo
         \000\xee\u{ffffff}
         bar
      ]]
   ]==]))
end)
