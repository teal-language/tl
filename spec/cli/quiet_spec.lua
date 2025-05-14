local util = require("spec.util")

local PROGRAM = [[
local function add(a: number, b: number): number
   return a + b
end

print(add(10, 20))
]]

local COMPILED = [[
local function add(a, b)
   return a + b
end

print(add(10, 20))
]]

describe("-q --quiet flag", function()
   setup(util.chdir_setup)
   teardown(util.chdir_teardown)
   it("silences warnings from tlconfig.lua", function()
      util.run_mock_project(finally, {
         dir_structure = {
            ["tlconfig.lua"] = [[return { foo = "hello" }]],
         },
         cmd = "check",
         args = { "--quiet", "tlconfig.lua" },
         cmd_output = [[]],
      })
   end)
   it("silences stdout when running tl check", function()
      local name = util.write_tmp_file(finally, [[
         print("hello world!")
      ]])

      local pd = io.popen(util.tl_cmd("check", "-q", name), "r")
      local output = pd:read("*a")
      util.assert_popen_close(0, pd:close())
      assert.equal("", output)
   end)
   it("does NOT silence stderr when running tl check", function()
      local name = util.write_tmp_file(finally, [[
         local function add(a: number, b: number): number
            return a + b
         end

         print(add("string", 20))
         print(add(10, true))
      ]])
      local pd = io.popen(util.tl_cmd("check", "-q", name) .. "2>&1", "r")
      local output = pd:read("*a")
      util.assert_popen_close(1, pd:close())
      assert.match("2 errors:", output, 1, true)
   end)
   it("silences stdout when running tl gen", function()
      local name = util.write_tmp_file(finally, PROGRAM)
      local pd = io.popen(util.tl_cmd("gen", "--quiet", name), "r")
      local output = pd:read("*a")
      util.assert_popen_close(0, pd:close())
      local lua_name = name:gsub("tl$", "lua")
      assert.equal("", output)
      util.assert_line_by_line(COMPILED, util.read_file(lua_name))
   end)
   it("does NOT silence stderr when running tl gen", function()
      local name = util.write_tmp_file(finally, [[
         print(add("string", 20))))))
      ]])
      local pd = io.popen(util.tl_cmd("gen", "--quiet", name) .. "2>&1", "r")
      local output = pd:read("*a")
      util.assert_popen_close(1, pd:close())
      assert.match("1 syntax error:", output, 1, true)
   end)
   it("reads from a file and writes to stdout", function()
      local name = util.write_tmp_file(finally, PROGRAM)
      local pd = io.popen(util.tl_cmd("gen", "--quiet", name, "-o", "-"), "r")
      local output = pd:read("*a")
      util.assert_popen_close(0, pd:close())
      util.assert_line_by_line(COMPILED, output)
   end)
   -- do a bit of a workaround for input and output
   it("reads from stdin and writes to a file", function()
      local outfile = util.get_tmp_filename(finally, "lua")
      local pd = io.popen(util.tl_cmd("gen", "--quiet", "-o", outfile, "-"), "w")
      assert(pd:write(PROGRAM))
      util.assert_popen_close(0, pd:close())
      util.assert_line_by_line(COMPILED, util.read_file(outfile))
   end)
   it("reads from stdin and writes to stdout", function()
      local name = util.write_tmp_file(finally, PROGRAM)
      local piped = util.os_cat .. ('%q'):format(name)
      local cmd = util.tl_pipe_cmd(piped, "gen", "--quiet", "-")
      local pd = io.popen(cmd, "r")
      local output = pd:read("*a")
      util.assert_popen_close(0, pd:close())
      util.assert_line_by_line(COMPILED, output)
   end)
end)
