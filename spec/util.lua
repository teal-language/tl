local win32 = package.config:sub(1,1) == "\\"
local util = {
   os_sep    = win32 and "\\" or "/",
   os_tmp    = win32 and os.getenv("TEMP") or "/tmp",
   os_null   = win32 and "NUL" or "/dev/null",
   os_join   = win32 and " & " or "",
   os_set    = win32 and "set " or ""
}

function util.os_path(path)
   return win32 and path:gsub("/", "\\\\") or path
end

if jit then
   jit.off()
end
collectgarbage("stop")

local tl = require("tl")
local assert = require("luassert")
local lfs = require("lfs")
local initial_dir = assert(lfs.currentdir(), "unable to get current dir")
local tl_executable = initial_dir .. util.os_sep .. "tl"

local t_unpack = unpack or table.unpack

util.tl_executable = tl_executable

local function remove_dir(name)
   if lfs.attributes(name, "mode") == "directory" then
      for d in lfs.dir(name) do
         if d ~= "." and d ~= ".." then
            remove_dir(name .. util.os_sep .. d)
         end
      end
   else
      os.remove(name)
   end
end

--------------------------------------------------------------------------------
-- 'finally' queue - each Busted test can trigger only one 'finally' callback.
-- We build a queue of callbacks to run and nest them into one main 'finally'
-- callback. Instead of using `finally(function() ... end`, do
-- `on_finally(finally, function() ... end)`. We need to pass the original
-- 'finally` around due to the way Busted deals with function environments.
--------------------------------------------------------------------------------

local finally_queue

local function on_finally(finally, cb)
   if not finally_queue then
      finally(function()
         for _, f in ipairs(finally_queue) do
            f()
         end
         finally_queue = nil
      end)
      finally_queue = {}
   end
   table.insert(finally_queue, cb)
end

--------------------------------------------------------------------------------

function util.do_in(dir, func, ...)
   local cdir = assert(lfs.currentdir())
   assert(lfs.chdir(dir), "unable to chdir into " .. dir)
   local res = {pcall(func, ...)}
   assert(lfs.chdir(cdir), "unable to chdir into " .. cdir)
   if not table.remove(res, 1) then
      error(res[1], 2)
   end
   return t_unpack(res)
end

local function unindent(code)
   assert(type(code) == "string")

   return code:gsub("[ \t]+", " "):gsub("\n[ \t]+", "\n"):gsub("^%s+", ""):gsub("%s+$", "")
end

local function indent(str)
   assert(type(str) == "string")
   return (str:gsub("\n", "\n   "))
end

local function trim_end(str)
   assert(type(str) == "string")

   return str:match("(.-)%s*$")
end

function util.mock_io(finally, filemap)
   assert(type(finally) == "function")
   assert(type(filemap) == "table")

   local io_open = io.open
   on_finally(finally, function() io.open = io_open end)
   io.open = function (filename, mode)
      local ps = {}
      for p in filename:gmatch("[^/]+") do
         table.insert(ps, p)
      end

      -- try to find suffixes in filemap, from shortest to longest
      local basename
      for i = #ps, 1, -1 do
         basename = table.concat(ps, "/", i)
         if filemap[basename] then
            break
         end
      end

      if filemap[basename] then
         -- Return a stub file handle
         return {
            read = function (_, format)
               if format == "*a" then
                  return trim_end(filemap[basename]) -- Return fake file content
               else
                  error("Not implemented!") -- Implement other modes if needed
               end
            end,
            close = function () end,
         }
      else
         return io_open(filename, mode)
      end
   end
end

local function batch_assertions(prefix)
   return {
      add = function(self, assert_func, ...)
         table.insert(self, { fn = assert_func, nargs = select("#", ...), args = {...} })
         return self
      end,
      assert = function(self)
         local err_batch = { }
         local passed = true
         for i, assertion in ipairs(self) do
            local ok, err = pcall(assertion.fn, t_unpack(assertion.args, 1, assertion.nargs))
            if not ok then
               passed = false
               table.insert(err_batch, indent("[" .. i .. "] " .. tostring(err)))
            end
         end
         assert(passed, "batch assertion failed: " .. (prefix or "") .. "\n   " .. indent(table.concat(err_batch, "\n\n")))
      end,
   }
end

function util.assert_line_by_line(s1, s2)
   assert(type(s1) == "string")
   assert(type(s2) == "string")

   s1 = unindent(s1)
   s2 = unindent(s2)
   local l1 = {}
   for l in s1:gmatch("[^\n]*") do
      table.insert(l1, l)
   end
   local l2 = {}
   for l in s2:gmatch("[^\n]*") do
      table.insert(l2, l)
   end
   local batch = batch_assertions()
   for i in ipairs(l1) do
      batch:add(assert.same, l1[i], l2[i], "mismatch at line " .. i .. ":")
   end
   batch:assert()
end

local cmd_prefix = { string.format(util.os_set .. "LUA_PATH=%q" .. util.os_join, package.path) }
for i = 1, 4 do
   table.insert(cmd_prefix, string.format(util.os_set .. "LUA_PATH_5_%d=%q" .. util.os_join, i, package.path))
end

local first_arg = 0
while arg[first_arg - 1] do
   first_arg = first_arg - 1
end
util.lua_interpreter = arg[first_arg]

table.insert(cmd_prefix, util.lua_interpreter) -- Lua interpreter used by Busted
table.insert(cmd_prefix, tl_executable)
cmd_prefix = table.concat(cmd_prefix, " ")
function util.tl_cmd(name, ...)
   assert(name, "no command provided")

   local pre_command_args = {}
   local first = ...
   local has_pre_commands = false
   if type(first) == "table" then
      pre_command_args = first
      has_pre_commands = true
   end
   local cmd = {
      cmd_prefix,
      table.concat(pre_command_args, " "),
      name
   }
   for i = (has_pre_commands and 2) or 1 , select("#", ...) do
      local a = select(i, ...)
      if a then
         table.insert(cmd, string.format("%q", a))
      end
   end
   return table.concat(cmd, " ") .. " "
end

function util.lua_cmd(...)
   assert(select("#", ...) > 0, "no command provided")

   local add_package_path = [[package.path = package.path .. ";]] .. initial_dir .. [[/?.lua"]]

   local cmd = { util.lua_interpreter, "-e", add_package_path, ... }
   for i = 2, #cmd do
      cmd[i] = string.format("%q", cmd[i])
   end

   return table.concat(cmd, " ") .. " "
end

function util.chdir_setup()
   assert(lfs.chdir(util.os_tmp))
end

function util.chdir_teardown()
   assert(lfs.chdir(initial_dir))
end

math.randomseed(os.time())
local function tmp_file_name()
   return util.os_tmp .. util.os_sep .. "teal_tmp" .. math.random(99999999)
end
function util.write_tmp_file(finally, content, ext)
   assert(type(finally) == "function")
   assert(type(content) == "string")

   local full_name = tmp_file_name() .. "." .. (ext or "tl")

   local fd = assert(io.open(full_name, "w"))
   fd:write(content)
   fd:close()

   on_finally(finally, function()
      os.remove(full_name)
      if not ext then
         os.remove((full_name:gsub("%.tl$", ".lua")))
      end
   end)

   if win32 then
      -- Normalize to unix filenames to pass assert_line_by_line
      full_name = full_name:gsub("\\+", "/")
   end

   return full_name
end

function util.write_tmp_dir(finally, dir_structure)
   assert(type(finally) == "function")
   assert(type(dir_structure) == "table")

   local full_name = tmp_file_name() .. util.os_sep
   assert(lfs.mkdir(full_name))
   local function traverse_dir(dir_structure, prefix)
      prefix = prefix or full_name
      for name, content in pairs(dir_structure) do
         if type(content) == "table" then
            assert(lfs.mkdir(prefix .. name))
            traverse_dir(content, prefix .. name .. util.os_sep)
         else
            if type(content) == "string" then
               content = trim_end(content)
            end

            local fd = io.open(prefix .. name, "w")
            fd:write(content)
            fd:close()
         end
      end
   end
   traverse_dir(dir_structure)
   on_finally(finally, function()
      remove_dir(full_name)
      --os.execute("rm -r " .. full_name)
   end)
   return full_name
end

function util.get_dir_structure(dir_name)
   -- basically run `tree` and put it into a table
   local dir_structure = {}
   for fname in lfs.dir(dir_name) do
      if fname ~= ".." and fname ~= "." then
         if lfs.attributes(dir_name .. util.os_sep .. fname, "mode") == "directory" then
            dir_structure[fname] = util.get_dir_structure(dir_name .. util.os_sep .. fname)
         else
            dir_structure[fname] = true
         end
      end
   end
   return dir_structure
end

local function insert_into(tab, files)
   for k, v in pairs(files) do
      if type(k) == "number" then
         tab[v] = true
      elseif type(v) == "string" then
         tab[k] = true
      elseif type(v) == "table" then
         if not tab[k] then
            tab[k] = {}
         end
         insert_into(tab[k], v)
      end
   end
end

function util.run_mock_project(finally, t, use_folder)
   assert(type(finally) == "function")
   assert(type(t) == "table")
   assert(type(t.cmd) == "string", "tl <cmd> not given")

   local actual_dir_name = use_folder or util.write_tmp_dir(finally, t.dir_structure)
   local expected_dir_structure
   if t.generated_files then
      expected_dir_structure = {}
      insert_into(expected_dir_structure, t.dir_structure)
      insert_into(expected_dir_structure, t.generated_files)
   end

   local pd, actual_output, actual_dir_structure
   util.do_in(actual_dir_name, function()
      local cmd = util.tl_cmd(t.cmd, t.pre_args or {}, t_unpack(t.args or {})) .. "2>&1"
      pd = assert(io.popen(cmd, "r"))
      actual_output = pd:read("*a")
      if expected_dir_structure then
         actual_dir_structure = util.get_dir_structure(".")
      end
   end)

   local batch = batch_assertions()
   if t.exit_code then
      batch:add(util.assert_popen_close, t.exit_code, pd:close())
   else
      pd:close()
   end
   if t.cmd_output then
      batch:add(assert.are.equal, t.cmd_output, actual_output:gsub("\\", "/"))
   end
   if expected_dir_structure then
      batch:add(assert.are.same, expected_dir_structure, actual_dir_structure, "Actual directory structure is not as expected")
   end
   batch:assert()
end

function util.read_file(name)
   assert(type(name) == "string")

   local fd = assert(io.open(name, "r"))
   local output = fd:read("*a")
   fd:close()
   return output
end

function util.assert_popen_close(want, ret1, ret2, ret3)
   assert(type(want) == "number")

   if type(ret3) == "number" then
      batch_assertions("popen close")
         :add(assert.same, want == 0 and true or nil, ret1)
         :add(assert.same, "exit", ret2)
         :add(assert.same, want, ret3)
         :assert()
   end
end

local function batch_compare(batch, category, expected, got)
   batch:add(assert.same, #expected, #got, "Expected same number of " .. category .. ":")
   for i = 1, #expected do
      local e = expected[i] or {}
      local g = got[i] or {}
      if e.y then
         batch:add(assert.same, e.y, g.y,  "[" .. i .. "] Expected same y location:")
      end
      if e.x then
         batch:add(assert.same, e.x, g.x,  "[" .. i .. "] Expected same x location:")
      end
      if e.msg then
         batch:add(assert.match, e.msg, g.msg or "", 1, true,  "[" .. i .. "] Expected messages to match:")
      end
      if e.filename then
         batch:add(assert.match, e.filename, g.filename or "", 1, true,  "[" .. i .. "] Expected filenames to match:")
      end
   end
   if #got > #expected then
      for i = #expected + 1, #got do
         batch:add(assert.same, {}, got[i],  "[" .. i .. "] Did not expect:")
      end
   end
end

local function combine_result(result, key)
   local out = {}
   for _, filename in ipairs(result.env.loaded_order) do
      for _, item in ipairs(result.env.loaded[filename][key]) do
         table.insert(out, item)
      end
   end
   return out
end

local function filter_by(tag, warnings)
   local out = {}
   for _, w in ipairs(warnings) do
      if w.tag == tag then
         table.insert(out, w)
      end
   end
   return out
end

local function check(lax, code, unknowns, gen_target)
   return function()
      local tokens = tl.lex(code)
      local syntax_errors = {}
      local _, ast = tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors, "Code was not expected to have syntax errors")
      local batch = batch_assertions()
      local gen_compat
      if gen_target == "5.4" then
         gen_compat = "off"
      end
      local result = tl.type_check(ast, { filename = "foo.lua", lax = lax, gen_target = gen_target, gen_compat = gen_compat })
      batch:add(assert.same, {}, result.type_errors)

      if unknowns then
         local unks = filter_by("unknown", combine_result(result, "warnings"))
         batch_compare(batch, "unknowns", unknowns, unks)
      end
      batch:assert()
      return true, ast
   end
end

local function check_type_error(lax, code, type_errors, gen_target)
   return function()
      local tokens = tl.lex(code)
      local syntax_errors = {}
      local _, ast = tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors, "Code was not expected to have syntax errors")
      local batch = batch_assertions()
      local gen_compat
      if gen_target == "5.4" then
         gen_compat = "off"
      end
      local result = tl.type_check(ast, { filename = "foo.tl", lax = lax, gen_target = gen_target, gen_compat = gen_compat })
      local result_type_errors = combine_result(result, "type_errors")

      batch_compare(batch, "type errors", type_errors, result_type_errors)
      batch:assert()
   end
end

function util.check(code, gen_target)
   assert(type(code) == "string")
   assert(gen_target == nil or type(gen_target) == "string")

   return check(false, code, nil, gen_target)
end

function util.lax_check(code, unknowns)
   assert(type(code) == "string")
   assert(type(unknowns) == "table")

   return check(true, code, unknowns)
end

function util.strict_and_lax_check(code, unknowns)
   assert(type(code) == "string")
   assert(type(unknowns) == "table")

   return check(true, code)
      and check(false, code, unknowns)
end

function util.check_type_error(code, type_errors, gen_target)
   assert(type(code) == "string")
   assert(type(type_errors) == "table")

   return check_type_error(false, code, type_errors, gen_target)
end

function util.strict_check_type_error(code, type_errors, unknowns)
   assert(type(code) == "string")
   assert(type(type_errors) == "table")
   assert(type(unknowns) == "table")

   -- fails in strict
   local ok = check_type_error(false, code, type_errors)
   if not ok then
      return
   end
   -- passes in lax
   return check(true, code, unknowns)
end

function util.lax_check_type_error(code, type_errors)
   assert(type(code) == "string")
   assert(type(type_errors) == "table")

   return check_type_error(true, code, type_errors)
end

function util.check_syntax_error(code, syntax_errors)
   assert(type(code) == "string")
   assert(type(syntax_errors) == "table")

   code = trim_end(code)

   return function()
      local tokens = tl.lex(code)
      local errors = {}
      local _, ast = tl.parse_program(tokens, errors)
      local batch = batch_assertions()
      batch_compare(batch, "syntax errors", syntax_errors, errors)
      batch:assert()
      tl.type_check(ast, { filename = "foo.tl", lax = false })
   end
end

function util.check_warnings(code, warnings)
   assert(type(code) == "string")
   assert(type(warnings) == "table")

   return function()
      local result = tl.process_string(code)
      local batch = batch_assertions()
      batch_compare(batch, "warnings", warnings, result.warnings or {})
      batch:assert()
   end
end

local function gen(lax, code, expected, gen_target)
   return function()
      local tokens = tl.lex(code)
      local syntax_errors = {}
      local _, ast = tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors, "Code was not expected to have syntax errors")
      local result = tl.type_check(ast, { filename = "foo.tl", lax = lax, gen_target = gen_target })
      assert.same({}, result.type_errors)
      local output_code = tl.pretty_print_ast(ast)

      local expected_tokens = tl.lex(expected)
      local _, expected_ast = tl.parse_program(expected_tokens, {})
      local expected_code = tl.pretty_print_ast(expected_ast)

      assert.same(expected_code, output_code)
   end
end

function util.gen(code, expected, gen_target)
   assert(type(code) == "string")
   assert(type(expected) == "string")

   return gen(false, code, expected, gen_target)
end

return util
