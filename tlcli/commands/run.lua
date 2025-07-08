local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local load = _tl_compat and _tl_compat.load or load; local os = _tl_compat and _tl_compat.os or os; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack



local common = require("tlcli.common")
local driver = require("tlcli.driver")
local perf = require("tlcli.perf")
local report = require("tlcli.report")
local teal = require("teal.init")




local function type_check_and_load(tlconfig, filename)
   local compiler = driver.setup_compiler(tlconfig)
   local module, _, err = driver.process_module(compiler, filename)
   if err then
      common.die(err)
   end

   local is_tl = filename:match("%.tl$")
   local _, summary = report.report_all_errors(tlconfig, compiler, not is_tl)
   if summary.any_syntax_err then
      os.exit(1)
   end

   if is_tl and summary.any_type_err then
      os.exit(1)
   end

   local chunk, chunk_err = load(module:gen(), "@" .. filename)
   if chunk_err then
      common.die("Internal Compiler Error: Teal generator produced invalid Lua. " ..
      "Please report a bug at https://github.com/teal-language/tl\n\n" .. tostring(chunk_err))
   end
   return chunk
end

return function(tlconfig, args)
   if args["require"] then
      tlconfig._init_env_modules = {}
      for _, module in ipairs(args["require"]) do
         table.insert(tlconfig._init_env_modules, module)
      end
   end

   local chunk = type_check_and_load(tlconfig, args["script"][1])


   local neg_arg = {}
   local nargs = #args["script"]
   local j = #arg
   local p = nargs
   local n = 1
   while arg[j] do
      if arg[j] == args["script"][p] then
         p = p - 1
      else
         neg_arg[n] = arg[j]
         n = n + 1
      end
      j = j - 1
   end


   for p2, a in ipairs(neg_arg) do
      arg[-p2] = a
   end

   for p2, a in ipairs(args["script"]) do
      arg[p2 - 1] = a
   end

   n = nargs
   while arg[n] do
      arg[n] = nil
      n = n + 1
   end

   teal.loader()

   assert(not perf.is_turbo_on())

   for _, module in ipairs(args["require"]) do
      require(module)
   end

   return chunk(_tl_table_unpack(arg))
end
