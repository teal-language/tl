--------------------------------------------------------------------------------
-- tl types
--------------------------------------------------------------------------------

local type TlConfig = require("tlcli.tlconfig")
local type Args = require("tlcli.args")
local common = require("tlcli.common")
local driver = require("tlcli.driver")
local perf = require("tlcli.perf")
local report = require("tlcli.report")
local type teal = require("teal.init")

local json_special_codes = "[%z\1-\31\34\92]"
-- %z is deprecated in Lua 5.2+; switch over if it stops working
if not ("\0"):match("%z") then
   json_special_codes = "[\0-\31\34\92]"
end

local function json_escape(s: string): string
   return "\\u" .. string.format("%04x", s:byte())
end

local function json_out_table(fd: FILE, x: {any:any})
   if x[0] == false then -- special array marker for json dump
      assert(x is {any})
      local l = #x
      if l == 0 then
         fd:write("[]")
         return
      end
      fd:write("[")
      local sep = l < 10 and "," or ",\n"
      for i, v in ipairs(x) do
         if i == l then
            sep = "]"
         end
         if v is number then
            fd:write(v, sep)
         elseif v is string then
            fd:write('"', v:gsub(json_special_codes, json_escape), '"', sep)
         elseif v is table then
            json_out_table(fd, v)
            fd:write(sep)
         else
            fd:write(tostring(v), sep)
         end
      end
   else
      local ks = common.keys(x)
      local l = #ks
      if l == 0 then
         fd:write("{}")
         return
      end
      fd:write("{\"")
      local sep = ",\n\""
      for i, k in ipairs(ks) do
         if i == l then
            sep = "}"
         end
         local v = x[k]
         local sk = (k is string and k:gsub(json_special_codes, json_escape) or k) as (string | number)
         if v is number then
            fd:write(sk, '":', v, sep)
         elseif v is string then
            fd:write(sk, '":"', v:gsub(json_special_codes, json_escape), '"', sep)
         elseif v is table then
            fd:write(sk, '":')
            json_out_table(fd, v)
            fd:write(sep)
         else
            fd:write(sk, '":', tostring(v), sep)
         end
      end
   end
end

return function(tlconfig: TlConfig, args: Args)
   perf.turbo(true)
   tlconfig["quiet"] = true
   tlconfig["gen_compat"] = "off"

   local filename = args["file"][1]
   local compiler = driver.setup_compiler(tlconfig)
   compiler:enable_type_reporting(true)

   local pcalls_ok = true
   for i, input_file in ipairs(args["file"]) do
      -- we run the type-checker even on files that produce
      -- syntax errors; this means we run it on incomplete and
      -- potentially inconsistent trees which may crash the
      -- type-checker; hence, we wrap it with a pcall here.
      local pok, _, _, err = pcall(driver.process_module, compiler, input_file)
      if pok then
         if err then
            common.die(err)
         end
      else
         pcalls_ok = false
      end

      perf.check_collect(i)
   end

   local ok = report.report_all_errors(tlconfig, compiler)
   if not pcalls_ok then
      ok = false
   end

   local tr = compiler:get_type_report()
   if not tr then
      os.exit(1)
   end

   if not ok then
      common.printerr("")
   end

   local pos = args["position"]
   if pos then
      local lin, col = pos:match("^(%d+):?(%d*)")
      local y = math.tointeger(lin) or 1
      local x = math.tointeger(col) or 1
      json_out_table(io.stdout, tr:symbols_in_scope(filename, y, x))
   else
      tr.symbols = tr.symbols_by_file[filename] or { [0] = false as teal.TypeReport.Symbol }
      json_out_table(io.stdout, tr as {any:any})
   end

   os.exit(ok and 0 or 1)
end
