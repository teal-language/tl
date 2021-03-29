local lfs = require("lfs")
local util = require("spec.util")

local input_file = [[
global type1 = 2

local type type_2 = record
end

local function bla()
end

local function ovo()
   if type1 == 2 then
      print("hello")
   else
   end
end

local func1 = function()
end

local func2 = function()
    local a = 100
    local b = a
end

-- multi
-- multi
-- multi
-- multi
-- line
-- comment
local c = 100
]]

local output_file = [[
type1 = 2

local type_2 = {}


local function bla()
end

local function ovo()
   if type1 == 2 then
      print("hello")
   else
   end
end

local func1 = function()
end

local func2 = function()
   local a = 100
   local b = a
end







local c = 100
]]

local function tl_to_lua(name)
   return (name:gsub("%.tl$", ".lua"):gsub("^" .. util.os_tmp .. util.os_sep, ""))
end

describe("tl gen", function()
   setup(util.chdir_setup)
   teardown(util.chdir_teardown)
   describe("on .tl files", function()
      it("works on empty files", function()
         local name = util.write_tmp_file(finally, [[]])
         local pd = io.popen(util.tl_cmd("gen", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         local lua_name = tl_to_lua(name)
         assert.match("Wrote: " .. lua_name, output, 1, true)
         util.assert_line_by_line([[]], util.read_file(lua_name))
      end)

      it("reports 0 errors and code 0 on success", function()
         local name = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add(10, 20))
         ]])
         local pd = io.popen(util.tl_cmd("gen", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         local lua_name = tl_to_lua(name)
         assert.match("Wrote: " .. lua_name, output, 1, true)
         util.assert_line_by_line([[
            local function add(a, b)
               return a + b
            end

            print(add(10, 20))
         ]], util.read_file(lua_name))
      end)

      it("ignores type errors", function()
         local name = util.write_tmp_file(finally, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add("string", 20))
            print(add(10, true))
         ]])
         local pd = io.popen(util.tl_cmd("gen", name) .. " 2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         assert.same("", output)
         local lua_name = tl_to_lua(name)
         util.assert_line_by_line([[
            local function add(a, b)
               return a + b
            end

            print(add("string", 20))
            print(add(10, true))
         ]], util.read_file(lua_name))
      end)

      it("reports number of errors in stderr and code 1 on syntax errors", function()
         local name = util.write_tmp_file(finally, [[
            print(add("string", 20))))))
         ]])
         local pd = io.popen(util.tl_cmd("gen", name) .. " 2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(1, pd:close())
         assert.match("1 syntax error:", output, 1, true)
      end)

      it("ignores unknowns code 0 if no errors", function()
         local name = util.write_tmp_file(finally, [[
            local function unk(x, y): number, number
               return a + b
            end
         ]])
         local pd = io.popen(util.tl_cmd("gen", name) .. " 2>&1 1>" .. util.os_null, "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         assert.same("", output)
         local lua_name = tl_to_lua(name)
         util.assert_line_by_line([[
            local function unk(x, y)
               return a + b
            end
         ]], util.read_file(lua_name))
      end)

      it("does not mess up the indentation (#109)", function()
         local name = util.write_tmp_file(finally, input_file)
         local pd = io.popen(util.tl_cmd("gen", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         local lua_name = tl_to_lua(name)
         assert.match("Wrote: " .. lua_name, output, 1, true)
         assert.equal(output_file, util.read_file(lua_name))
      end)
   end)

   describe("with --gen-target=5.1", function()
      it("targets generated code to Lua 5.1+", function()
         local name = util.write_tmp_file(finally, [[

            local x = 2 // 3
            local y = 2 << 3
         ]])
         local pd = io.popen(util.tl_cmd("gen", "--gen-target=5.1", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         local lua_name = tl_to_lua(name)
         assert.match("Wrote: " .. lua_name, output, 1, true)
         util.assert_line_by_line([[
            local bit32 = bit32; if not bit32 then local p, m = pcall(require, 'bit32'); if p then bit32 = m end end
            local x = math.floor(2 / 3)
            local y = bit32.lshift(2, 3)
         ]], util.read_file(lua_name))
      end)
   end)

   describe("with --gen-target=5.3", function()
      it("targets generated code to Lua 5.3+", function()
         local name = util.write_tmp_file(finally, [[
            local x = 2 // 3
            local y = 2 << 3
         ]])
         local pd = io.popen(util.tl_cmd("gen", "--gen-target=5.3", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         local lua_name = tl_to_lua(name)
         assert.match("Wrote: " .. lua_name, output, 1, true)
         util.assert_line_by_line([[
            local x = 2 // 3
            local y = 2 << 3
         ]], util.read_file(lua_name))
      end)
   end)

   describe("with --skip-compat53", function()
      it("does not add compat53 insertions", function()
         local name = util.write_tmp_file(finally, [[
            local t = {1, 2, 3, 4}
            print(table.unpack(t))
         ]])
         local pd = io.popen(util.tl_cmd("gen", "--skip-compat53", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         local lua_name = tl_to_lua(name)
         assert.match("Wrote: " .. lua_name, output, 1, true)
         util.assert_line_by_line([[
            local t = { 1, 2, 3, 4 }
            print(table.unpack(t))
         ]], util.read_file(lua_name))
      end)
   end)

   describe("with --gen-compat=off", function()
      it("does not add compat53 insertions", function()
         local name = util.write_tmp_file(finally, [[
            local t = {1, 2, 3, 4}
            print(table.unpack(t))
         ]])
         local pd = io.popen(util.tl_cmd("gen", "--gen-compat=off", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         local lua_name = tl_to_lua(name)
         assert.match("Wrote: " .. lua_name, output, 1, true)
         util.assert_line_by_line([[
            local t = { 1, 2, 3, 4 }
            print(table.unpack(t))
         ]], util.read_file(lua_name))
      end)
   end)

   describe("with --gen-compat=optional", function()
      it("adds compat53 insertions with a pcall in the require", function()
         local name = util.write_tmp_file(finally, [[

            local t = {1, 2, 3, 4}
            print(table.unpack(t))
         ]])
         local pd = io.popen(util.tl_cmd("gen", "--gen-compat=optional", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         local lua_name = tl_to_lua(name)
         assert.match("Wrote: " .. lua_name, output, 1, true)
         util.assert_line_by_line([[
            local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack
            local t = { 1, 2, 3, 4 }
            print(_tl_table_unpack(t))
         ]], util.read_file(lua_name))
      end)
   end)

   describe("with --gen-compat=required", function()
      it("adds compat53 insertions", function()
         local name = util.write_tmp_file(finally, [[

            local t = {1, 2, 3, 4}
            print(table.unpack(t))
         ]])
         local pd = io.popen(util.tl_cmd("gen", "--gen-compat=required", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         local lua_name = tl_to_lua(name)
         assert.match("Wrote: " .. lua_name, output, 1, true)
         util.assert_line_by_line([[
            local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = true, require('compat53.module'); if p then _tl_compat = m end end; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack
            local t = { 1, 2, 3, 4 }
            print(_tl_table_unpack(t))
         ]], util.read_file(lua_name))
      end)
   end)

   describe("without --skip-compat53", function()
      it("adds compat53 insertions by default", function()
         local name = util.write_tmp_file(finally, [[
            local t = {1, 2, 3, 4}
            print(table.unpack(t))
         ]])
         local pd = io.popen(util.tl_cmd("gen", name), "r")
         local output = pd:read("*a")
         util.assert_popen_close(0, pd:close())
         local lua_name = tl_to_lua(name)
         assert.match("Wrote: " .. lua_name, output, 1, true)
         util.assert_line_by_line([[
            local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; local t = { 1, 2, 3, 4 }
            print(_tl_table_unpack(t))
         ]], util.read_file(lua_name))
      end)
   end)
end)
