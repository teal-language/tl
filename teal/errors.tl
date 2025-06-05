local record errors
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
