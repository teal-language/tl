local lfs = require("lfs")
local util = require("spec.util")

-- local path_separator = "/"
-- local function tl_name_to_relative_lua(file_name)
--    local tail = file_name:match("[^%" .. path_separator .. "]+$")
--    local name, ext = tail:match("(.+)%.([a-zA-Z]+)$")
--    if not name then name = tail end
--    return name .. ".lua"
-- end
local curr_dir = lfs.currentdir()
local tlcmd = "LUA_PATH+=" .. curr_dir .. "/?.tl"

describe("-o --output", function()
   setup(function()
      os.execute("LUA_PATH+=" .. curr_dir .. "/?.lua")
      util.chdir_setup()
   end)
   teardown(util.chdir_teardown)
   it("should gen in the current directory when not provided", function()
      util.write_tmp_dir(finally, "gen_curr_dir_test", {
         bar = {
            ["foo.tl"] = [[print 'hey']]
         }
      })
      assert(lfs.chdir("/tmp/gen_curr_dir_test"))
      local pd = io.popen(curr_dir .. "/tl gen bar/foo.tl", "r")
      local output = pd:read("*a")
      lfs.chdir(curr_dir)
      util.assert_popen_close(true, "exit", 0, pd:close())
      assert.match("Wrote: foo.lua", output, 1, true)
   end)
   it("should work with nested directories", function()
      local dir_name = "gen_curr_dir_nested_test"
      util.write_tmp_dir(finally, dir_name, {
         a={b={c={["foo.tl"] = [[print 'hey']]}}}
      })
      assert(lfs.chdir("/tmp/gen_curr_dir_nested_test"))
      local pd = io.popen(curr_dir .. "/tl gen a/b/c/foo.tl", "r")
      local output = pd:read("*a")
      lfs.chdir(curr_dir)
      util.assert_popen_close(true, "exit", 0, pd:close())
      assert.match("Wrote: foo.lua", output, 1, true)
   end)
   it("should write to the given filename", function()
      local name = "foo.tl"
      local outfile = "bar.lua"
      util.write_tmp_dir(finally, "output_name_test", {
         [name] = [[print 'hey']],
      })
      assert(lfs.chdir("/tmp/output_name_test"))
      local pd = io.popen(curr_dir .. "/tl gen " .. name .. " -o " .. outfile, "r")
      local output = pd:read("*a")
      util.assert_popen_close(true, "exit", 0, pd:close())
      assert.match("Wrote: " .. outfile, output, 1, true)
   end)
   it("should write to the given filename in a directory", function()
      local name = "foo.tl"
      local outfile = "a/b/c/d.lua"
      local dir_name = "nested_dir_output_test"
      util.write_tmp_dir(finally, dir_name, {
         [name] = [[print 'foo']],
         a={b={c={}}},
      })
      assert(lfs.chdir("/tmp/" .. dir_name))
      local pd = io.popen(curr_dir .. "/tl gen " .. name .. " -o " .. outfile, "r")
      local output = pd:read("*a")
      lfs.chdir(curr_dir)
      util.assert_popen_close(true, "exit", 0, pd:close())
      assert.match("Wrote: " .. outfile, output, 1, true)
   end)
   it("should gracefully error when the output directory doesn't exist", function()
      local name = "foo.tl"
      local outfile = "a/b/c/d.lua"
      local dir_name = "nested_dir_output_fail_test"
      util.write_tmp_dir(finally, dir_name, {
         [name] = [[print 'foo']],
      })
      assert(lfs.chdir("/tmp/" .. dir_name))
      local pd = io.popen(curr_dir .. "/tl gen " .. name .. " -o " .. outfile .. " 2>&1", "r")
      local output = pd:read("*a")
      lfs.chdir(curr_dir)
      util.assert_popen_close(nil, "exit", 1, pd:close())
      assert.match("cannot write " .. outfile .. ": " .. outfile .. ": No such file or directory", output, 1, true)
   end)
end)
