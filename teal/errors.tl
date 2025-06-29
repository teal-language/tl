local record errors
   interface Where
      f: string
      y: integer
      x: integer
   end

   enum WarningKind
      "unknown"
      "unused"
      "redeclaration"
      "branch"
      "hint"
      "debug"
      "unread"
   end
   warning_kinds: {WarningKind:boolean}

   record Error
      y: integer
      x: integer
      msg: string
      filename: string

      tag: WarningKind

      -- used temporarily for stable-sorting
      i: integer
   end

   record ErrorContext
      kind: string
      name: string
   end
end

local type Error = errors.Error
local type Where = errors.Where

function errors.new(msg: string): Error
   return { msg = msg }
end

function errors.at(w: Where, msg: string): Error
   return {
      msg = msg,
      x = assert(w.x),
      y = assert(w.y),
      filename = assert(w.f),
   }
end

function errors.any(all_errs: {Error}): boolean, {Error}
   if #all_errs == 0 then
      return true
   else
      return false, all_errs
   end
end

function errors.clear_redundant_errors(errs: {Error})
   local redundant: {integer} = {}
   local lastx, lasty = 0, 0
   for i, err in ipairs(errs) do
      err.i = i
   end
   table.sort(errs, function(a: Error, b: Error): boolean
      local af = assert(a.filename)
      local bf = assert(b.filename)
      return af < bf
             or (af == bf   and (a.y < b.y
             or (a.y == b.y and (a.x < b.x
             or (a.x == b.x and (a.i < b.i))))))
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

local wk <total>: {errors.WarningKind:boolean} = {
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
