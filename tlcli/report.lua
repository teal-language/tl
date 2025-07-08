local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table
local teal = require("teal.init")
local common = require("tlcli.common")



local report = { ErrorSummary = {} }







local function report_errors(category, errors)
   if not errors then
      return false
   end
   if #errors > 0 then
      local n = #errors
      common.printerr("========================================")
      common.printerr(n .. " " .. category .. (n ~= 1 and "s" or "") .. ":")
      for _, err in ipairs(errors) do
         common.printerr(err.filename .. ":" .. err.y .. ":" .. err.x .. ": " .. (err.msg or ""))
      end
      common.printerr("----------------------------------------")
      common.printerr(n .. " " .. category .. (n ~= 1 and "s" or ""))
      return true
   end
   return false
end

local function filter_warnings(tlconfig, errs)
   if not errs.warnings then
      return
   end
   for i = #errs.warnings, 1, -1 do
      local w = errs.warnings[i]
      if tlconfig._disabled_warnings_set[w.tag] then
         table.remove(errs.warnings, i)
      elseif tlconfig._warning_errors_set[w.tag] then
         local err = table.remove(errs.warnings, i)
         table.insert(errs.type_errors, err)
      end
   end
end

function report.report_all_errors(tlconfig, compiler, syntax_only)
   local summary = {}
   for name in compiler:loaded_files() do
      local _, errs = compiler:recall(name)

      local syntax_err = report_errors("syntax error", errs.syntax_errors)
      if syntax_err then
         summary.any_syntax_err = true
      elseif not syntax_only then
         filter_warnings(tlconfig, errs)
         summary.any_warning = report_errors("warning", errs.warnings) or summary.any_warning
         summary.any_type_err = report_errors("error", errs.type_errors) or summary.any_type_err
      end
   end
   local ok = not (summary.any_syntax_err or summary.any_type_err)
   return ok, summary
end

return report
