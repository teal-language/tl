local assert = require("luassert")
local util = require("spec.util")
local tl = require("tl")

describe("tl warnings", function()
   it("reports existing warning types when given no arguments", function()
      local pd = io.popen(util.tl_cmd("warnings"), "r")
      local output = pd:read("*a")
      util.assert_popen_close(0, pd:close())
      local i = 0
      for kind, _ in pairs(tl.warning_kinds) do
         assert.match(kind .. " : enabled", output, 1, true)
         i = i + 1
      end
      assert.same(6, i)
   end)
end)

describe("warning flags", function()
   describe("in tlconfig.lua", function()
      describe("disable_warnings", function()
         it("disables the given warnings", function()
            local name = util.write_tmp_dir(finally, {
               ["tlconfig.lua"] = [[ return { disable_warnings = { "unused" } } ]],
               ["script.tl"] = [[ local x = 10 ]],
            })
            local pd, output
            util.do_in(name, function()
               pd = io.popen(util.tl_cmd("check", "script.tl"), "r")
               output = pd:read("a")
            end)
            util.assert_popen_close(0, pd:close())
            assert["not"].match("warning", output)
         end)
      end)
      describe("warning_error", function()
         it("promotes the given warnings to errors", function()
            local name = util.write_tmp_dir(finally, {
               ["tlconfig.lua"] = [[ return { warning_error = { "unused" } } ]],
               ["script.tl"] = [[ local x = 10 ]],
            })
            local pd, output
            util.do_in(name, function()
               pd = io.popen(util.tl_cmd("check", "script.tl") .. "2>&1", "r")
               output = pd:read("a")
            end)
            util.assert_popen_close(1, pd:close())
            assert.match("1 error:", output)
         end)
      end)
   end)
   describe("in cli arguments", function()
      describe("--wdisable", function()
         it("disables the given warnings", function()
            local name = util.write_tmp_file(finally, [[ local x = 10 ]])
            local pd = io.popen(util.tl_cmd("check", name, "--wdisable", "unused") .. "2>&1", "r")
            local output = pd:read("*a")
            util.assert_popen_close(0, pd:close())
            assert["not"].match(output, "warning")
            assert.match("0 errors detected", output)
         end)
      end)
      describe("--werror", function()
         it("promotes the given warning to an error", function()
            local name = util.write_tmp_file(finally, [[ local x = 10 ]])
            local pd = io.popen(util.tl_cmd("check", name, "--werror", "unused") .. "2>&1", "r")
            local output = pd:read("*a")
            util.assert_popen_close(1, pd:close())
            assert.match("1 error:", output)
         end)
      end)
   end)
end)
