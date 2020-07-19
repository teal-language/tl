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
   return (name:gsub("%.tl$", ".lua"))
end

describe("tl gen", function()
   setup(util.chdir_setup)
   teardown(util.chdir_teardown)
   describe("on .tl files", function()
      it("reports 0 errors and code 0 on success", function()
         local name = "add.tl"
         util.write_tmp_file(finally, name, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add(10, 20))
         ]])
         local pd = io.popen("./tl gen " .. name, "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
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
         local name = "add.tl"
         util.write_tmp_file(finally, name, [[
            local function add(a: number, b: number): number
               return a + b
            end

            print(add("string", 20))
            print(add(10, true))
         ]])
         local pd = io.popen("./tl gen " .. name .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
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
         local name = "add.tl"
         util.write_tmp_file(finally, name, [[
            print(add("string", 20))))))
         ]])
         local pd = io.popen("./tl gen " .. name .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(nil, "exit", 1, pd:close())
         assert.match("1 syntax error:", output, 1, true)
      end)

      it("ignores unknowns code 0 if no errors", function()
         local name = "add.tl"
         util.write_tmp_file(finally, name, [[
            local function unk(x, y): number, number
               return a + b
            end
         ]])
         local pd = io.popen("./tl gen " .. name .. " 2>&1 1>/dev/null", "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
         assert.same("", output)
         local lua_name = tl_to_lua(name)
         util.assert_line_by_line([[
            local function unk(x, y)
               return a + b
            end
         ]], util.read_file(lua_name))
      end)

      it("does not mess up the indentation (#109)", function()
         local name = "add.tl"
         util.write_tmp_file(finally, name, input_file)
         local pd = io.popen("./tl gen " .. name, "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
         local lua_name = tl_to_lua(name)
         assert.match("Wrote: " .. lua_name, output, 1, true)
         assert.equal(output_file, util.read_file(lua_name))
      end)
   end)

   describe("with --skip-compat53", function()
      it("does not add compat53 insertions", function()
         local name = "test.tl"
         util.write_tmp_file(finally, name, [[
            local t = {1, 2, 3, 4}
            print(table.unpack(t))
         ]])
         local pd = io.popen("./tl --skip-compat53 gen " .. name, "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
         local lua_name = tl_to_lua(name)
         assert.match("Wrote: " .. lua_name, output, 1, true)
         util.assert_line_by_line([[
            local t = { 1, 2, 3, 4 }
            print(table.unpack(t))
         ]], util.read_file(lua_name))
      end)
   end)

   describe("without --skip-compat53", function()
      it("adds compat53 insertions by default", function()
         local name = "test.tl"
         util.write_tmp_file(finally, name, [[
            local t = {1, 2, 3, 4}
            print(table.unpack(t))
         ]])
         local pd = io.popen("./tl gen " .. name, "r")
         local output = pd:read("*a")
         util.assert_popen_close(true, "exit", 0, pd:close())
         local lua_name = tl_to_lua(name)
         assert.match("Wrote: " .. lua_name, output, 1, true)
         util.assert_line_by_line([[
            local _tl_compat53 = ((tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3) and require('compat53.module'); local table = _tl_compat53 and _tl_compat53.table or table; local _tl_table_unpack = unpack or table.unpack; local t = { 1, 2, 3, 4 }
            print(_tl_table_unpack(t))
         ]], util.read_file(lua_name))
      end)
   end)

end)
