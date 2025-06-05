local errors = { Error = {} }
























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
