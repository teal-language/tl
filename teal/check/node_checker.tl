local type environment = require("teal.environment")
local type Env = environment.Env

local type facts = require("teal.facts")
local type FactDatabase = facts.FactDatabase

local type parser = require("teal.parser")
local type Node = parser.Node

local type types = require("teal.types")
local type Type = types.Type
local type FunctionType = types.FunctionType
local type InvalidOrTupleType = types.InvalidOrTupleType
local type RecordLikeType = types.RecordLikeType
local type TupleType = types.TupleType

local type type_checker = require("teal.check.type_checker")
local type TypeChecker = type_checker.TypeChecker

local record node_checker
   interface NodeChecker is TypeChecker
      dependencies: {string:string}
      env: Env
      fdb: FactDatabase

      type_check_funcall: function(self, node: Node, a: Type, b: TupleType, argdelta?: integer): InvalidOrTupleType
      type_check_function_call: function(self, node: Node, func: Type, args: TupleType, argdelta: integer, or_args ?: TupleType, or_rets ?: TupleType, e1?: Node, e2?: {Node}): InvalidOrTupleType, FunctionType
      type_check_index: function(self, anode: Node, bnode: Node, a: Type, b: Type): Type
      match_all_record_field_names: function(self, node: Node, a: RecordLikeType, field_names: {string}, errmsg: string): Type
   end
end

return node_checker
