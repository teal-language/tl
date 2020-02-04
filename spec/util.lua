local util = {}

local tl = require("tl")
local assert = require("luassert")

local it

function util.init(it_)
   it = it_
end

function util.mock_io(finally, files)
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
   return code:gsub("[ \t]+", " "):gsub("\n[ \t]+", "\n"):gsub("^%s+", ""):gsub("%s+$", "")
end

function util.assert_line_by_line(s1, s2)
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

function util.write_tmp_file(finally, name, content)
   local full_name = "/tmp/" .. name
   local fd = io.open(full_name, "w")
   fd:write(content)
   fd:close()
   finally(function()
      os.remove(full_name)
   end)
   return full_name
end

function util.read_file(name)
   local fd = io.open(name, "r")
   local output = fd:read("*a")
   fd:close()
   return output
end

function util.assert_popen_close(want1, want2, want3, ret1, ret2, ret3)
   if _VERSION == "Lua 5.3" then
      assert.same(want1, ret1)
      assert.same(want2, ret2)
      assert.same(want3, ret3)
   end
end

function util.check(title, code)
   it(title, function()
      local tokens = tl.lex(code)
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same({}, errors)
   end)
end

function util.check_type_error(title, code, type_errors)
   it(title, function()
      local tokens = tl.lex(code)
      local _, ast = tl.parse_program(tokens)
      local errors = tl.type_check(ast)
      assert.same(#errors, #type_errors)
      for i, err in ipairs(type_errors) do
         if err.y then
            assert.same(err.y, errors[i].y)
         end
         if err.x then
            assert.same(err.x, errors[i].x)
         end
         if err.msg then
            assert.match(err.msg, errors[i].msg, 1, true)
         end
      end
   end)
end

function util.check_syntax_error(title, code, syntax_errors)
   it(title, function()
      local tokens = tl.lex(code)
      local errors = {}
      tl.parse_program(tokens, errors)
      assert.same(#errors, #syntax_errors)
      for i, err in ipairs(syntax_errors) do
         if err.y then
            assert.same(err.y, errors[i].y)
         end
         if err.x then
            assert.same(err.x, errors[i].x)
         end
         if err.msg then
            assert.match(err.msg, errors[i].msg, 1, true)
         end
      end
   end)
end

return util
