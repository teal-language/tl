local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local assert = _tl_compat and _tl_compat.assert or assert; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local pairs = _tl_compat and _tl_compat.pairs or pairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local type = type; local tldebug = require("teal.debug")
local TL_DEBUG = tldebug.TL_DEBUG

local types = require("teal.types")







local a_type = types.a_type

local parser = require("teal.parser")









local variables = require("teal.variables")


local has_var_been_used = variables.has_var_been_used

local type_errors = { Errors = {} }













local Errors = type_errors.Errors

function Errors.new(filename)
   local self = {
      errors = {},
      warnings = {},
      unknown_dots = {},
      filename = filename,
   }
   return setmetatable(self, { __index = Errors })
end

local function insert_error(self, y, x, f, err)
   err.y = assert(y)
   err.x = assert(x)
   err.filename = assert(f)

   if TL_DEBUG then
      tldebug.write("ERROR:" .. err.y .. ":" .. err.x .. ": " .. err.msg .. "\n")
   end

   table.insert(self.errors, err)
end

function Errors:add(w, msg, t, ...)
   local e
   if t then
      e = types.error(msg, t, ...)
   else
      e = { msg = msg }
   end
   if e then
      insert_error(self, w.y, w.x, w.f, e)
   end
end

type_errors.context_name = {
   ["local_declaration"] = "in local declaration",
   ["global_declaration"] = "in global declaration",
   ["assignment"] = "in assignment",
   ["literal_table_item"] = "in table item",
}

function Errors:node_context(ctx, name)
   assert(ctx)
   local ec = ctx.expected_context
   local cn = type_errors.context_name[ec and ec.kind or ctx.kind]
   return (cn and cn .. ": " or "") .. (ec and ec.name and ec.name .. ": " or "") .. (name and name .. ": " or "")
end

function Errors:string_context(ctx, name)
   assert(ctx)
   local cn = ctx
   return (cn .. ": " or "") .. (name and name .. ": " or "")
end

function Errors:get_context(ctx, name)
   assert(ctx)
   local ec = (ctx.kind ~= nil) and ctx.expected_context
   local cn = (type(ctx) == "string") and ctx or
   (ctx.kind ~= nil) and type_errors.context_name[ec and ec.kind or ctx.kind]
   return (cn and cn .. ": " or "") .. (ec and ec.name and ec.name .. ": " or "") .. (name and name .. ": " or "")
end

function Errors:add_in_context(w, ctx, msg, ...)
   if ctx then
      local prefix = self:get_context(ctx)
      msg = prefix .. msg
   end
   return self:add(w, msg, ...)
end


function Errors:collect(errs)
   for _, e in ipairs(errs) do
      insert_error(self, e.y, e.x, e.filename, e)
   end
end

function Errors:add_warning(tag, w, fmt, ...)
   assert(w.y)
   table.insert(self.warnings, {
      y = w.y,
      x = w.x,
      msg = fmt:format(...),
      filename = assert(w.f),
      tag = tag,
   })
end

function Errors:invalid_at(w, msg, ...)
   self:add(w, msg, ...)
   return a_type(w, "invalid", {})
end

function Errors:add_unknown(w, name)
   self:add_warning("unknown", w, "unknown variable: %s", name)
end

function Errors:redeclaration_warning(at, var_name, var_kind, old_var)
   if var_name:sub(1, 1) == "_" then return end

   local short_error = var_kind .. " shadows previous declaration of '%s'"
   if old_var and old_var.declared_at then
      self:add_warning("redeclaration", at, short_error .. " (originally declared at %d:%d)", var_name, old_var.declared_at.y, old_var.declared_at.x)
   else
      self:add_warning("redeclaration", at, short_error, var_name)
   end
end

local function var_should_be_ignored_for_warnings(name, var)
   local prefix = name:sub(1, 1)
   return (not var.declared_at) or
   var.is_specialized == "narrow" or
   prefix == "_" or
   prefix == "@"
end

local function user_facing_variable_description(var)
   local t = var.t
   return var.is_func_arg and "argument" or
   t.typename == "function" and "function" or
   t.typename == "typedecl" and "type" or
   "variable"
end

function Errors:unused_warning(name, var)
   if var_should_be_ignored_for_warnings(name, var) then
      return
   end
   self:add_warning(
   "unused",
   var.declared_at,
   "unused %s %s: %s",
   user_facing_variable_description(var),
   name,
   types.show_type(var.t))

end

function Errors:add_prefixing(w, src, prefix, dst)
   if not src then
      return
   end

   for _, err in ipairs(src) do
      err.msg = prefix .. err.msg
      if w and (
         (err.filename ~= w.f) or
         (not err.y) or
         (w.y > err.y or (w.y == err.y and w.x > err.x))) then

         err.y = w.y
         err.x = w.x
         err.filename = w.f
      end

      if dst then
         table.insert(dst, err)
      else
         insert_error(self, err.y, err.x, err.filename, err)
      end
   end
end

local function ensure_not_abstract_type(def, node)
   if def.typename == "record" then
      return true
   elseif def.typename == "generic" then
      return ensure_not_abstract_type(def.t)
   elseif node and parser.node_is_require_call(node) then
      return nil, "module type is abstract: " .. tostring(def)
   elseif def.typename == "interface" then
      return nil, "interfaces are abstract; consider using a concrete record"
   end
   return nil, "cannot use a type definition as a concrete value"
end

function type_errors.ensure_not_abstract(t, node)
   if t.typename == "function" and t.macroexp then
      return nil, "macroexps are abstract; consider using a concrete function"
   elseif t.typename == "generic" then
      return type_errors.ensure_not_abstract(t.t, node)
   elseif t.typename == "typedecl" then
      return ensure_not_abstract_type(t.def, node)
   end
   return true
end














local function check_var_usage(scope, is_global)
   local vars = scope.vars
   if not next(vars) then
      return
   end
   local usage_warnings
   for name, var in pairs(vars) do
      local t = var.t
      if not var_should_be_ignored_for_warnings(name, var) then
         if var.has_been_written_to and not var.has_been_read_from then
            usage_warnings = usage_warnings or {}
            table.insert(usage_warnings, {
               y = var.declared_at.y,
               x = var.declared_at.x,
               name = name,
               var = var,
               kind = "written but not read",
            })
         end

      end

      if var.declared_at and not has_var_been_used(var) then
         if var.used_as_type then
            var.declared_at.elide_type = true
         else
            if t.typename == "typedecl" and not is_global then
               var.declared_at.elide_type = true
            end
            usage_warnings = usage_warnings or {}
            table.insert(usage_warnings, { y = var.declared_at.y, x = var.declared_at.x, name = name, var = var, kind = "unused" })
         end
      elseif has_var_been_used(var) and t.typename == "typedecl" and var.aliasing then
         var.aliasing.has_been_written_to = var.has_been_written_to
         var.aliasing.has_been_read_from = var.has_been_read_from
         if type_errors.ensure_not_abstract(t) then
            var.aliasing.declared_at.elide_type = false
         end
      end
   end
   if usage_warnings then
      table.sort(usage_warnings, function(a, b)
         return a.y < b.y or (a.y == b.y and a.x < b.x)
      end)
   end
   return usage_warnings
end

function Errors:check_var_usage(scope, is_global)
   local usage_warnings = check_var_usage(scope, is_global)
   if usage_warnings then
      for _, u in ipairs(usage_warnings) do
         if u.kind == "unused" then
            self:unused_warning(u.name, u.var)
         elseif u.kind == "written but not read" then
            self:add_warning(
            "unread",
            u.var.declared_at,
            "%s %s (of type %s) is never read",
            user_facing_variable_description(u.var),
            u.name,
            types.show_type(u.var.t))

         end
      end
   end

   if scope.labels then
      for name, node in pairs(scope.labels) do
         if not node.used_label then
            self:add_warning("unused", node, "unused label ::%s::", name)
         end
      end
   end
end

function Errors:add_unknown_dot(w, name)
   if not self.unknown_dots[name] then
      self.unknown_dots[name] = true
      self:add_unknown(w, name)
   end
end

function Errors:fail_unresolved_labels(scope)
   if scope.pending_labels then
      for name, nodes in pairs(scope.pending_labels) do
         for _, node in ipairs(nodes) do
            self:add(node, "no visible label '" .. name .. "' for goto")
         end
      end
   end
end

function Errors:fail_unresolved_nominals(scope, global_scope)
   if global_scope and scope.pending_nominals then
      for name, typs in pairs(scope.pending_nominals) do
         if not global_scope.pending_global_types[name] then
            for _, typ in ipairs(typs) do
               assert(typ.x)
               assert(typ.y)
               self:add(typ, "unknown type %s", typ)
            end
         end
      end
   end
end

function Errors:check_redeclared_key(w, ctx, seen_keys, key)
   if key ~= nil then
      local s = seen_keys[key]
      if s then
         self:add_in_context(w, ctx, "redeclared key " .. tostring(key) .. " (previously declared at " .. self.filename .. ":" .. s.y .. ":" .. s.x .. ")")
      else
         seen_keys[key] = w
      end
   end
end

return type_errors
