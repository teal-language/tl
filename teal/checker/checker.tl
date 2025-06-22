local errors = require("teal.errors")
local type Error = errors.Error
local type WarningKind = errors.WarningKind

local attributes = require("teal.attributes")
local type Attribute = attributes.Attribute

local types = require("teal.types")
local type Type = types.Type
local type Where = types.Where

local record checker
   enum VarUse
      "use"
      "lvalue"
      "use_type"
      "check_only"
   end

   interface Checker
      find_var_type: function(self, name: string, use?: VarUse): Type, Attribute, Type
      is_a: function(self, Type, Type): boolean, {Error}
      same_type: function(self, Type, Type): boolean, {Error}
      to_structural: function(self, t: Type): Type
      add_error: function(self, w: Where, msg: string, t?: Type, ...:Type)
      add_warning: function(self, tag: WarningKind, w: Where, fmt: string, ...: any)
   end
end

return checker
