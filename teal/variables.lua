local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local pairs = _tl_compat and _tl_compat.pairs or pairs











local variables = { Variable = {}, Scope = {} }





































function variables.has_var_been_used(var)
   return var.has_been_read_from or var.has_been_written_to
end

local function close_nested_records(t)
   if t.closed then
      return
   end
   local tdef = t.def
   if tdef.fields then
      t.closed = true
      for _, ft in pairs(tdef.fields) do
         if ft.typename == "typedecl" then
            close_nested_records(ft)
         end
      end
   end
end

function variables.close_types(scope)
   for _, var in pairs(scope.vars) do
      local t = var.t
      if t.typename == "typedecl" then
         close_nested_records(t)
      end
   end
end

return variables
