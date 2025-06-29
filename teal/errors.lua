local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local table = _tl_compat and _tl_compat.table or table; local errors = { Error = {}, ErrorContext = {} }






































function errors.new(msg)
   return { msg = msg }
end

function errors.at(w, msg)
   return {
      msg = msg,
      x = assert(w.x),
      y = assert(w.y),
      filename = assert(w.f),
   }
end

function errors.any(all_errs)
   if #all_errs == 0 then
      return true
   else
      return false, all_errs
   end
end

function errors.clear_redundant_errors(errs)
   local redundant = {}
   local lastx, lasty = 0, 0
   for i, err in ipairs(errs) do
      err.i = i
   end
   table.sort(errs, function(a, b)
      local af = assert(a.filename)
      local bf = assert(b.filename)
      return af < bf or
      (af == bf and (a.y < b.y or
      (a.y == b.y and (a.x < b.x or
      (a.x == b.x and (a.i < b.i))))))
   end)
   for i, err in ipairs(errs) do
      err.i = nil
      if err.x == lastx and err.y == lasty then
         table.insert(redundant, i)
      end
      lastx, lasty = err.x, err.y
   end
   for i = #redundant, 1, -1 do
      table.remove(errs, redundant[i])
   end
end

local wk = {
   ["unknown"] = true,
   ["unused"] = true,
   ["redeclaration"] = true,
   ["branch"] = true,
   ["hint"] = true,
   ["debug"] = true,
   ["unread"] = true,
}
errors.warning_kinds = wk

return errors
