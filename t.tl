local macro match!(value: Expression, cases: Expression): Expression
   local blk = require("teal.block")
   local BI = blk.BLOCK_INDEXES

   local function or_chain(exprs: {any})
      if #exprs == 0 then return nil end
      local acc = exprs[1]
      for i = 2, #exprs do
         local e = exprs[i]
         acc = `$acc or $e`
      end
      return acc
   end

   local function set_node_location(node: any, ref: any)
      if type(node) ~= "table" or type(ref) ~= "table" then return end
      if node.kind then
         node.y = ref.y or node.y
         node.x = ref.x or node.x
         node.yend = ref.yend or ref.y or node.yend
         node.xend = ref.xend or ref.x or node.xend
         node.f = ref.f or node.f
      end
   end

   local function set_location_from(node: any, ...)
      for i = 1, select('#', ...) do
         local ref = select(i, ...)
         if type(ref) == "table" then
            set_node_location(node, ref)
            if type(node) == "table" and node.y then
               return
            end
         end
      end
   end

   local function bump_line(node: any)
      if type(node) ~= "table" then return end
      if type(node.y) == "number" then
         node.y = node.y + 1
         if type(node.yend) == "number" then
            node.yend = node.yend + 1
         else
            node.yend = node.y
         end
      end
   end

   local function clone_type_for(expr: any, ty: any): any
      local ty_copy = clone(ty)
      local function relocate(n: any)
         if type(n) ~= "table" then return end
         if n.kind then
            set_node_location(n, expr)
         end
         for _, child in pairs(n) do
            if type(child) == "table" then
               relocate(child)
            end
         end
      end
      relocate(ty_copy)
      return ty_copy
   end

   local function make_is(expr: any, ty: any)
      local is_expr = block('op_is')
      is_expr.tk = "is"
      set_node_location(is_expr, expr)
      is_expr[BI.OP.E1] = clone(expr)

      local cast = block('cast')
      set_node_location(cast, expr)
      cast[BI.CAST.TYPE] = clone_type_for(expr, ty)

      is_expr[BI.OP.E2] = cast
      return is_expr
   end

   local function make_return(expr: any)
      local ret_stmt = block('return')
      set_location_from(ret_stmt, expr, value, cases)

      local expr_list = block('expression_list')
      set_location_from(expr_list, expr, value, cases)
      table.insert(expr_list, expr)

      ret_stmt[BI.RETURN.EXPS] = expr_list
      return ret_stmt
   end

   local function build_union_type(types: {any})
      if #types == 0 then return nil end

      local cloned_members: {any} = {}
      for _, ty in ipairs(types) do
         table.insert(cloned_members, clone_type_for(value, ty))
      end

      if #cloned_members == 0 then return nil end

      if #cloned_members == 1 then
         return cloned_members[1]
      end

      local union = block('union_type')
      set_node_location(union, cloned_members[1])
      for i, ty in ipairs(cloned_members) do
         union[i] = ty
      end
      return union
   end

   local function build_return_annotation(types: {any})
      local return_type = build_union_type(types)
      if not return_type then return nil end

      local typelist = block('typelist')
      typelist.tk = ":"
      set_node_location(typelist, return_type)
      typelist[BI.TYPELIST.FIRST] = return_type
      typelist[1] = return_type

      local tuple = block('tuple_type')
      tuple.tk = ":"
      set_node_location(tuple, return_type)
      tuple[BI.TUPLE_TYPE.FIRST] = typelist
      tuple[1] = typelist

      return tuple
   end

   local function make_any_return_annotation()
      local any_type = block('nominal_type')
      any_type.tk = "any"
      set_location_from(any_type, value, cases)

      local typelist = block('typelist')
      typelist.tk = ":"
      set_location_from(typelist, any_type, value)
      typelist[BI.TYPELIST.FIRST] = any_type
      typelist[1] = any_type

      local tuple = block('tuple_type')
      tuple.tk = ":"
      set_location_from(tuple, any_type, value)
      tuple[BI.TUPLE_TYPE.FIRST] = typelist
      tuple[1] = typelist

      return tuple
   end

   cases = expect(cases, "literal_table")

   local return_types: {any} = {}
   local value_param_types: {any} = {}
   local missing_return_annotations = false
   local needs_value_arg = false

   local value_arg_name = "__match_value"
   local value_var_template = block('variable')
   value_var_template.tk = value_arg_name
   set_location_from(value_var_template, value, cases)

   local body_statements: {any} = {}
   local fallback_statements: {any} = {}

   for _, item in ipairs(cases) do
      if not item then goto continue end
      local fn = item[BI.LITERAL_TABLE_ITEM.VALUE]
      fn = expect(fn, "function")

      local args = fn[BI.FUNCTION.ARGS]
      args = expect(args, "argument_list")

      local body_call

      if #args == 0 then
         body_call = `($fn)()`
         table.insert(fallback_statements, make_return(body_call))
      else
         needs_value_arg = true
         if #args ~= 1 then
            error("match! cases must be functions with 0 or 1 argument")
         end
         local arg = args[1]
         arg = expect(arg, "argument")
        local ann = arg[BI.ARGUMENT.ANNOTATION]
        if not ann then
            error("match! case function must have a typed argument")
        end

         table.insert(value_param_types, ann)

        local types_to_match: {any} = {}
        if ann.kind == "union_type" then
            for i = 1, #ann do
               local t = ann[i]
               if t then
                  table.insert(types_to_match, clone(t))
               end
            end
         else
            table.insert(types_to_match, clone(ann))
         end

        local cond_terms: {any} = {}
        for _, t in ipairs(types_to_match) do
            table.insert(cond_terms, make_is(value_var_template, t))
        end
         local value_expr = clone(value_var_template)
         body_call = `($fn)($value_expr)`

         local if_body = block('statements')
         set_location_from(if_body, fn, value, cases)
         table.insert(if_body, make_return(body_call))

         local ib = block('if_block')
         ib[BI.IF_BLOCK.COND] = or_chain(cond_terms)
         ib[BI.IF_BLOCK.BODY] = if_body

         local if_stmt = block('if')
         if_stmt[BI.IF.BLOCKS] = {}
         table.insert(if_stmt[BI.IF.BLOCKS], ib)
         set_location_from(if_stmt, fn, value, cases)
         bump_line(if_stmt)
         table.insert(body_statements, if_stmt)
      end

      local fn_rets = fn[BI.FUNCTION.RETS]
      if fn_rets then
         local typelist = fn_rets[BI.TUPLE_TYPE.FIRST]
         if typelist then
            if #typelist > 1 then
               error("match! case functions must return exactly one value")
            end
            local first = typelist[BI.TYPELIST.FIRST]
            if first then
               table.insert(return_types, first)
            else
               missing_return_annotations = true
            end
         else
            missing_return_annotations = true
         end
      else
         missing_return_annotations = true
      end

      ::continue::
   end

   local fn_body = block('statements')
   set_location_from(fn_body, value, cases)
   bump_line(fn_body)
   for _, stmt in ipairs(body_statements) do
      table.insert(fn_body, stmt)
   end
   for _, stmt in ipairs(fallback_statements) do
      table.insert(fn_body, stmt)
   end

   if #fallback_statements == 0 then
      table.insert(fn_body, `error("match! non-exhaustive cases")`)
   end

   local fn_expr = block('function')
   fn_expr.tk = "function"
   set_location_from(fn_expr, value, cases)

   local fn_args = block('argument_list')
   fn_args.tk = "("
   set_location_from(fn_args, fn_expr, value, cases)
   if needs_value_arg then
      local value_arg = block('argument')
      value_arg.tk = value_arg_name
      set_location_from(value_arg, value, cases)

      if #fallback_statements == 0 then
         local value_param_annotation = build_union_type(value_param_types)
         if value_param_annotation then
            value_arg[BI.ARGUMENT.ANNOTATION] = value_param_annotation
         end
      end

      table.insert(fn_args, value_arg)
   end
   fn_expr[BI.FUNCTION.ARGS] = fn_args
   fn_expr[BI.FUNCTION.BODY] = fn_body

   local return_annotation = build_return_annotation(return_types)
   if not missing_return_annotations and return_annotation then
      fn_expr[BI.FUNCTION.RETS] = return_annotation
   elseif missing_return_annotations then
      fn_expr[BI.FUNCTION.RETS] = make_any_return_annotation()
   end

   local fn_paren = block('paren')
   set_location_from(fn_paren, fn_expr, value, cases)
   fn_paren[BI.PAREN.EXP] = fn_expr

   local call_args = block('expression_list')
   call_args.tk = "("
   set_location_from(call_args, value, cases)
   if needs_value_arg then
      table.insert(call_args, clone(value))
   end

   local call = block('op_funcall')
   call.tk = "("
   set_location_from(call, value, cases)
   call[BI.OP.E1] = fn_paren
   call[BI.OP.E2] = call_args

   return call
end

local function get_value(): integer | string | table | userdata | nil
   return 43
end

local v: integer | string | table | userdata | nil = get_value()

local n = match!(v, {
   function(x: integer): integer print(x + 10); return x + 10 end;
   function(x: string) print(x:upper()) end;
   function(_: table | userdata) print("other") end;
   function() print("none") end
})
