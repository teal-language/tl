local util = require("spec.util")

describe("string literal code generation", function()
   it("generates Lua 5.1 compatible escape sequences in string literals", util.gen([[
      local _hex_bytes = "\xDe\xAD\xbE\xef\x05"
      local _unicode = "hello \u{4e16}\u{754C}"
      local _whitespace_removal = "hello\z

      , world!"
      local _source_new_lines_get_preserved = 0
      local _works_with_slashes = "\\\x123 \\x123"
   ]], [[
      local _hex_bytes = "\222\173\190\239\005"
      local _unicode = "hello \228\184\150\231\149\140"
      local _whitespace_removal = "hello, world!"


      local _source_new_lines_get_preserved = 0
      local _works_with_slashes = "\\\0183 \\x123"
   ]], "5.1"))

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
   ]==], "5.1"))

   for _, version in ipairs { "5.1", "5.3", "5.4" } do
      local source = [[local _hex = "\xaa\xbb\xcc"]]
      local expected = version == "5.1"
         and [[local _hex = "\170\187\204"]]
         or source
      it(
         version == "5.1"
            and "does not make substitutions when target is 5.1"
            or "does make substitutions when target is not 5.1",
         util.gen(source, expected, version)
      )
   end
end)
