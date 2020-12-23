local util = {}

local tl = require("tl")
local assert = require("luassert")
local lfs = require("lfs")
local current_dir = lfs.currentdir()
local tl_executable = current_dir .. "/tl"
local tl_lib = current_dir .. "/tl.lua"

function util.do_in(dir, func, ...)
   local cdir = assert(lfs.currentdir())
   assert(lfs.chdir(dir))
   local res = {pcall(func, ...)}
   assert(lfs.chdir(cdir))
   return (unpack or table.unpack)(res)
end

function util.mock_io(finally, files)
   assert(type(finally) == "function")
   assert(type(files) == "table")

   local io_open = io.open
   finally(function() io.open = io_open end)
   io.open = function (filename, mode)
      local basename = string.match(filename, "([^/]+)$")
      if files[basename] then
         -- Return a stub file handle
         return {
            read = function (_, format)
               if format == "*a" then
                  return files[basename]     -- Return fake bar.tl content
               else
                  error("Not implemented!")  -- Implement other modes if needed
               end
            end,
            close = function () end,
         }
      else
         return io_open(filename, mode)
      end
   end
end

local function unindent(code)
   assert(type(code) == "string")

   return code:gsub("[ \t]+", " "):gsub("\n[ \t]+", "\n"):gsub("^%s+", ""):gsub("%s+$", "")
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
   for i in ipairs(l1) do
      assert.same(l1[i], l2[i], "mismatch at line " .. i .. ":")
   end
end

function util.chdir_setup()
   assert(lfs.link("tl", "/tmp/tl"))
   assert(lfs.link("tl.lua", "/tmp/tl.lua"))
   assert(lfs.chdir("/tmp"))
end

function util.chdir_teardown()
   -- explicitly use /tmp here
   -- just in case it may remove the actual tl file
   os.remove("/tmp/tl.lua")
   os.remove("/tmp/tl")
   assert(lfs.chdir(current_dir))
end

function util.write_tmp_file(finally, name, content)
   assert(type(finally) == "function")
   assert(type(name) == "string")
   assert(type(content) == "string")

   local full_name = "/tmp/" .. name
   local fd = io.open(full_name, "w")
   fd:write(content)
   fd:close()
   finally(function()
      os.remove(full_name)
   end)
   return full_name
end

local tmp_files = 1

function util.write_tmp_dir(finally, dir_structure)
   assert(type(finally) == "function")
   assert(type(dir_structure) == "table")

   local full_name = "/tmp/teal_spec" .. tostring(tmp_files) .. "/"
   tmp_files = tmp_files + 1
   assert(lfs.mkdir(full_name))
   local function traverse_dir(dir_structure, prefix)
      prefix = prefix or full_name
      for name, content in pairs(dir_structure) do
         if type(content) == "table" then
            assert(lfs.mkdir(prefix .. name))
            traverse_dir(content, prefix .. name .. "/")
         else
            local fd = io.open(prefix .. name, "w")
            fd:write(content)
            fd:close()
         end
      end
   end
   traverse_dir(dir_structure)
   finally(function()
      os.execute("rm -r " .. full_name)
      -- local function rm_dir(dir_structure, prefix)
      --    prefix = prefix or full_name
      --    for name, content in pairs(dir_structure) do
      --       if type(content) == "table" then
      --          rm_dir(prefix .. name .. "/")
      --       end
      --       os.remove(prefix .. name)
      --    end
      -- end
      -- rm_dir(dir_structure)
   end)
   return full_name
end

function util.get_dir_structure(dir_name)
   -- basically run `tree` and put it into a table
   local dir_structure = {}
   for fname in lfs.dir(dir_name) do
      if fname ~= ".." and fname ~= "." then
         if lfs.attributes(dir_name .. "/" .. fname, "mode") == "directory" then
            dir_structure[fname] = util.get_dir_structure(dir_name .. "/" .. fname)
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
function util.run_mock_project(finally, t)
   assert(type(finally) == "function")
   assert(type(t) == "table")
   assert(type(t.cmd) == "string", "tl <cmd> not given")
   assert(({
      gen = true,
      check = true,
      run = true,
      build = true,
   })[t.cmd], "Invalid command tl " .. t.cmd)
   local actual_dir_name = util.write_tmp_dir(finally, t.dir_structure)
   lfs.link(tl_executable, actual_dir_name .. "/tl")
   lfs.link(tl_lib, actual_dir_name .. "/tl.lua")
   local expected_dir_structure
   if t.generated_files then
      expected_dir_structure = {
         ["tl"] = true,
         ["tl.lua"] = true,
      }
      insert_into(expected_dir_structure, t.dir_structure)
      insert_into(expected_dir_structure, t.generated_files)
   end

   local pd, output, actual_dir_structure
   assert(util.do_in(actual_dir_name, function()
      pd = io.popen("./tl " .. t.cmd .. " " .. (t.args or "") .. " 2>&1")
      output = pd:read("*a")
      if expected_dir_structure then
         actual_dir_structure = util.get_dir_structure(".")
      end
   end))
   if t.popen then
      util.assert_popen_close(
         t.popen.status,
         t.popen.exit,
         t.popen.code,
         pd:close()
      )
   end
   if t.cmd_output then
      assert.are.equal(output, t.cmd_output)
   end
   if expected_dir_structure then
      assert.are.same(expected_dir_structure, actual_dir_structure, "Actual directory structure is not as expected")
   end
end

function util.read_file(name)
   assert(type(name) == "string")

   local fd = assert(io.open(name, "r"))
   local output = fd:read("*a")
   fd:close()
   return output
end

function util.assert_popen_close(want1, want2, want3, ret1, ret2, ret3)
   assert(want1 == nil or type(want1) == "boolean")
   assert(type(want2) == "string")
   assert(type(want3) == "number")

   if _VERSION == "Lua 5.3" then
      assert.same(want1, ret1)
      assert.same(want2, ret2)
      assert.same(want3, ret3)
   end
end

local function check(lax, code, unknowns)
   return function()
      local tokens = tl.lex(code)
      local syntax_errors = {}
      local _, ast = tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors, "Code was not expected to have syntax errors")
      local errors, unks = tl.type_check(ast, { filename = "foo.lua", lax = lax })
      assert.same({}, errors)
      if unknowns then
         assert.same(#unknowns, #unks, "Expected same number of unknowns:")
         for i, u in ipairs(unknowns) do
            if u.y then
               assert.same(u.y, unks[i].y)
            end
            if u.x then
               assert.same(u.x, unks[i].x)
            end
            if u.msg then
               assert.same(u.msg, unks[i].msg)
            end
            if u.filename then
               assert.same(u.filename, unks[i].filename)
            end
         end
      end
      return true, ast
   end
end

local function check_type_error(lax, code, type_errors)
   return function()
      local tokens = tl.lex(code)
      local syntax_errors = {}
      local _, ast = tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors, "Code was not expected to have syntax errors")
      local errors = tl.type_check(ast, { filename = "foo.tl", lax = lax })
      assert.same(#type_errors, #errors, "Expected same number of errors:")
      for i, err in ipairs(type_errors) do
         if err.y then
            assert.same(err.y, errors[i].y,  "[" .. i .. "] Expected same y location:")
         end
         if err.x then
            assert.same(err.x, errors[i].x,  "[" .. i .. "] Expected same x location:")
         end
         if err.msg then
            assert.match(err.msg, errors[i].msg, 1, true,  "[" .. i .. "] Expected messages to match:")
         end
         if err.filename then
            assert.match(err.filename, errors[i].filename, 1, true,  "[" .. i .. "] Expected filenames to match:")
         end
      end
   end
end

function util.check(code)
   assert(type(code) == "string")

   return check(false, code)
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

function util.check_type_error(code, type_errors)
   assert(type(code) == "string")
   assert(type(type_errors) == "table")

   return check_type_error(false, code, type_errors)
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

   return function()
      local tokens = tl.lex(code)
      local errors = {}
      tl.parse_program(tokens, errors)
      assert.same(#syntax_errors, #errors, "Expected same amount of syntax errors:")
      for i, err in ipairs(syntax_errors) do
         if err.y then
            assert.same(err.y, errors[i].y, "[" .. i .. "] Expected same y location:")
         end
         if err.x then
            assert.same(err.x, errors[i].x,  "[" .. i .. "] Expected same x location:")
         end
         if err.msg then
            assert.match(err.msg, errors[i].msg, 1, true,  "[" .. i .. "] Expected messages to match:")
         end
         if err.filename then
            assert.match(err.filename, errors[i].filename, 1, true,  "[" .. i .. "] Expected filenames to match:")
         end
      end
   end
end

function util.check_warnings(code, warnings)
   assert(type(code) == "string")
   assert(type(warnings) == "table")

   return function()
      local result = tl.process_string(code)
      assert.same(#warnings, #result.warnings, "Expected same amount of warnings:")
      for i, warning in ipairs(warnings) do

         if warning.y then
            assert.same(warning.y, result.warnings[i].y, "[" .. i .. "] Expected same y location:")
         end
         if warning.x then
            assert.same(warning.x, result.warnings[i].x,  "[" .. i .. "] Expected same x location:")
         end
         if warning.msg then
            assert.match(warning.msg, result.warnings[i].msg, 1, true,  "[" .. i .. "] Expected messages to match:")
         end
         if warning.filename then
            assert.match(warning.filename, result.warnings[i].filename, 1, true,  "[" .. i .. "] Expected filenames to match:")
         end
      end
   end
end

local function gen(lax, code, expected)
   return function()
      local tokens = tl.lex(code)
      local syntax_errors = {}
      local _, ast = tl.parse_program(tokens, syntax_errors)
      assert.same({}, syntax_errors, "Code was not expected to have syntax errors")
      local errors, unks = tl.type_check(ast, { filename = "foo.tl", lax = lax })
      assert.same({}, errors)
      local output_code = tl.pretty_print_ast(ast)

      local expected_tokens = tl.lex(expected)
      local _, expected_ast = tl.parse_program(expected_tokens, {})
      local expected_code = tl.pretty_print_ast(expected_ast)

      assert.same(expected_code, output_code)
   end
end

function util.gen(code, expected)
   assert(type(code) == "string")
   assert(type(expected) == "string")

   return gen(false, code, expected)
end

return util
