--------------------------------------------------------------------------------
-- tl run
--------------------------------------------------------------------------------

local common = require("tlcli.common")
local driver = require("tlcli.driver")
local perf = require("tlcli.perf")
local report = require("tlcli.report")
local teal = require("teal.init")
local type TlConfig = require("tlcli.tlconfig")
local type Args = require("tlcli.args")
local type Compiler = teal.Compiler

local function type_check_and_load(tlconfig: TlConfig, filename: string): function(any...):(any...)
   local compiler: Compiler = driver.setup_compiler(tlconfig)
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

return function(tlconfig: TlConfig, args: Args): any
   if args["require"] then
      tlconfig._init_env_modules = {}
      for _, module in ipairs(args["require"]) do
         table.insert(tlconfig._init_env_modules, module)
      end
   end

   local chunk = type_check_and_load(tlconfig, args["script"][1])

   -- collect all non-arguments including negative arg values
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

   -- shift back all non-arguments to negative positions
   for p2, a in ipairs(neg_arg) do
      arg[-p2] = a
   end
   -- put script in arg[0] and arguments in positive positions
   for p2, a in ipairs(args["script"]) do
      arg[p2 - 1] = a
   end
   -- cleanup the rest
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

   return chunk(table.unpack(arg))
end
