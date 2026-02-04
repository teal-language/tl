local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table; local _tl_table_unpack = unpack or table.unpack; local type = type; local utf8 = _tl_compat and _tl_compat.utf8 or utf8





local targets = require("teal.gen.targets")


local types = require("teal.types")












local traversal = require("teal.traversal")



local lua_generator = { Options = {} }












local tight_op = {
   [1] = {
      ["-"] = true,
      ["~"] = true,
      ["#"] = true,
   },
   [2] = {
      ["."] = true,
      [":"] = true,
   },
}

local spaced_op = {
   [1] = {
      ["not"] = true,
   },
   [2] = {
      ["or"] = true,
      ["and"] = true,
      ["<"] = true,
      [">"] = true,
      ["<="] = true,
      [">="] = true,
      ["~="] = true,
      ["=="] = true,
      ["|"] = true,
      ["~"] = true,
      ["&"] = true,
      ["<<"] = true,
      [">>"] = true,
      [".."] = true,
      ["+"] = true,
      ["-"] = true,
      ["*"] = true,
      ["/"] = true,
      ["//"] = true,
      ["%"] = true,
      ["^"] = true,
   },
}


lua_generator.default_opts = {
   preserve_indent = true,
   preserve_newlines = true,
   preserve_hashbang = false,
}

lua_generator.fast_opts = {
   preserve_indent = false,
   preserve_newlines = true,
   preserve_hashbang = false,
}

function lua_generator.generate(ast, gen_target, opts)
   local indent = 0

   opts = opts or lua_generator.default_opts







   local function increment_indent(_, node)
      local child = node.body or node[1]
      if not child then
         return
      end
      if not indent then
         indent = 1
      else
         indent = indent + 1
      end
   end

   local function decrement_indent()
      if not indent then
         indent = 0
      else
         indent = indent - 1
      end
   end

   if not opts.preserve_indent then
      increment_indent = nil
      decrement_indent = function() end
   end

   local function add_string(out, s)
      table.insert(out, s)
      if string.find(s, "\n", 1, true) then
         for _nl in s:gmatch("\n") do
            out.h = out.h + 1
         end
      end
   end

   local function add_child(out, child, space, current_indent)
      if #child == 0 then
         return
      end

      if child.y ~= -1 and child.y < out.y then
         out.y = child.y
      end

      if child.y > out.y + out.h and opts.preserve_newlines then
         local delta = child.y - (out.y + out.h)
         out.h = out.h + delta
         table.insert(out, ("\n"):rep(delta))
      else
         if space then
            if space ~= "" then
               table.insert(out, space)
            end
            current_indent = nil
         end
      end
      if current_indent and opts.preserve_indent then
         table.insert(out, ("   "):rep(current_indent))
      end
      table.insert(out, child)
      out.h = out.h + child.h
   end

   local function concat_output(out)
      for i, s in ipairs(out) do
         if type(s) == "table" then
            out[i] = concat_output(s)
         end
      end
      return table.concat(out)
   end

   local function print_record_def(typ)
      local out = { "{" }
      local i = 0
      for fname, ftype in traversal.fields_of(typ) do
         if ftype.typename == "typedecl" then
            local def = ftype.def
            if def.typename == "generic" then
               def = def.t
            end
            if def.typename == "record" then
               if i > 0 then
                  table.insert(out, ",")
               end
               i = i + 1
               table.insert(out, " ")
               table.insert(out, fname)
               table.insert(out, " = ")
               table.insert(out, print_record_def(def))
            end
         end
      end
      if i > 0 then
         table.insert(out, " ")
      end
      table.insert(out, "}")
      return table.concat(out)
   end

   local visit_node = {}

   local lua_54_attribute = {
      ["const"] = " <const>",
      ["close"] = " <close>",
      ["total"] = " <const>",
   }

   local function emit_exactly(_, node, _children)
      local out = { y = node.y, h = 0 }
      add_string(out, node.tk)
      return out
   end

   local emit_exactly_visitor_cbs = { after = emit_exactly }

   local emit_nothing_visitor_cbs = {
      after = function(_, node, _children)
         local out = { y = node.y, h = 0 }
         return out
      end,
   }

   local function starts_with_longstring(n)
      while n.e1 do n = n.e1 end
      return n.is_longstring
   end

   local function drop_initial_indentation(out)
      if not out then
         return
      end
      local first = out[1]
      if type(first) == "string" then
         if first:match("^ +$") then
            table.remove(out, 1)
            drop_initial_indentation(out)
         end
      else
         drop_initial_indentation(first)
      end
   end

   local function add_block(out, block_out, top_node)
      if not block_out then
         return
      end
      if block_out.y == top_node.y then
         drop_initial_indentation(block_out)
      end

      add_child(out, block_out, " ")
      decrement_indent()
   end








   local function_indexes = {

      ["anonymous"] = { 1, 3 },
      ["record"] = { 3, 5 },
      ["local"] = { 2, 4 },
      ["global"] = { 2, 4 },
   }

   local function after_function(kind)
      local arguments_index, body_index = _tl_table_unpack(function_indexes[kind])
      return function(_, node, children)
         local out = { y = node.y, h = 0 }

         if kind == "local" then
            table.insert(out, "local ")
         end

         table.insert(out, "function")

         if kind == "record" then
            add_child(out, children[1], " ")
            table.insert(out, node.is_method and ":" or ".")
            add_child(out, children[2])
         elseif kind ~= "anonymous" then
            add_child(out, children[1], " ")
         end
         table.insert(out, "(")


         local args = children[arguments_index]
         if kind == "record" and node.is_method then
            table.remove(args, 1)
            if args[1] == "," then
               table.remove(args, 1)
               if args[1] == " " then
                  table.remove(args, 1)
               end
            end
         end
         add_child(out, args)

         table.insert(out, ")")

         local last_arg = node.args[#node.args]
         if last_arg and last_arg.tk == "..." and last_arg.name then


            table.insert(out, "local " .. last_arg.name.tk .. "=table.pack(...);")
         end

         add_child(out, children[body_index], " ")
         decrement_indent()
         add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
         return out
      end
   end

   visit_node.cbs = {
      ["statements"] = {
         after = function(_, node, children)
            local out
            if opts.preserve_hashbang and node.hashbang then
               out = { y = 1, h = 0 }
               table.insert(out, node.hashbang)
            else
               out = { y = node.y, h = 0 }
            end
            local space
            for i, child in ipairs(children) do
               add_child(out, child, space, indent)
               if node[i].semicolon then
                  table.insert(out, ";")
                  space = " "
               else
                  space = "; "
               end
            end
            return out
         end,
      },
      ["local_declaration"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "local ")
            for i, var in ipairs(node.vars) do
               if i > 1 then
                  add_string(out, ", ")
               end
               add_string(out, var.tk)
               if var.attribute and gen_target == "5.4" then
                  add_string(out, lua_54_attribute[var.attribute])
               end
            end
            if children[3] then
               table.insert(out, " =")
               add_child(out, children[3], " ")
            end
            return out
         end,
      },
      ["local_type"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if not node.var.elide_type then
               table.insert(out, "local")
               add_child(out, children[1], " ")
               table.insert(out, " =")
               add_child(out, children[2], " ")
            end
            return out
         end,
      },
      ["global_type"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if children[2] then
               add_child(out, children[1])
               table.insert(out, " =")
               add_child(out, children[2], " ")
            end
            return out
         end,
      },
      ["global_declaration"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if children[3] then
               add_child(out, children[1])
               table.insert(out, " =")
               add_child(out, children[3], " ")
            end
            return out
         end,
      },
      ["assignment"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            add_child(out, children[1])
            table.insert(out, " =")
            add_child(out, children[3], " ")
            return out
         end,
      },
      ["if"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            for i, child in ipairs(children) do
               add_child(out, child, i > 1 and " ", child.y ~= node.y and indent)
            end
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["if_block"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if node.if_block_n == 1 then
               table.insert(out, "if")
            elseif not node.exp then
               table.insert(out, "else")
            else
               table.insert(out, "elseif")
            end
            if node.exp then
               add_child(out, children[1], " ")
               table.insert(out, " then")
            end

            add_block(out, children[2], node)
            return out
         end,
      },
      ["while"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "while")
            add_child(out, children[1], " ")
            table.insert(out, " do")
            add_block(out, children[2], node)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["repeat"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "repeat")
            add_block(out, children[1], node)
            add_child(out, { y = node.yend, h = 0, [1] = "until " }, " ", indent)
            add_child(out, children[2])
            return out
         end,
      },
      ["do"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "do")
            add_block(out, children[1], node)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["forin"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "for")
            add_child(out, children[1], " ")
            table.insert(out, " in")
            add_child(out, children[2], " ")
            table.insert(out, " do")
            add_block(out, children[3], node)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["fornum"] = {
         before = increment_indent,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "for")
            add_child(out, children[1], " ")
            table.insert(out, " =")
            add_child(out, children[2], " ")
            table.insert(out, ",")
            add_child(out, children[3], " ")
            if children[4] then
               table.insert(out, ",")
               add_child(out, children[4], " ")
            end
            table.insert(out, " do")
            add_block(out, children[5], node)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["return"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "return")
            if #children[1] > 0 then
               add_child(out, children[1], " ")
            end
            return out
         end,
      },
      ["break"] = {
         after = function(_, node, _children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "break")
            return out
         end,
      },
      ["variable_list"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            local space
            for i, child in ipairs(children) do
               if i > 1 then
                  table.insert(out, ",")
                  space = " "
               end
               add_child(out, child, space, child.y ~= node.y and indent)
            end
            return out
         end,
      },
      ["literal_table"] = {
         before = increment_indent and function(_, node)
            if node[1] and node[1].y ~= node.y then
               increment_indent(_, node)
            end
         end,
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if #children == 0 then
               table.insert(out, "{}")
               return out
            end
            table.insert(out, "{")
            local n = #children
            for i, child in ipairs(children) do
               add_child(out, child, " ", child.y ~= node.y and indent)
               if i < n or node.yend ~= node.y then
                  table.insert(out, ",")
               end
            end
            if increment_indent and node[1] and node[1].y ~= node.y then
               decrement_indent()
            end
            add_child(out, { y = node.yend, h = 0, [1] = "}" }, " ", indent)
            return out
         end,
      },
      ["literal_table_item"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if node.key_parsed ~= "implicit" then
               if node.key_parsed == "short" then
                  children[1][1] = children[1][1]:sub(2, -2)
                  add_child(out, children[1])
                  table.insert(out, " = ")
               else
                  table.insert(out, "[")
                  if node.key_parsed == "long" and node.key.is_longstring then
                     table.insert(children[1], 1, " ")
                     table.insert(children[1], " ")
                  end
                  add_child(out, children[1])
                  table.insert(out, "] = ")
               end
            end
            add_child(out, children[2])
            return out
         end,
      },
      ["local_macroexp"] = {
         before = increment_indent,
         after = function(_, node, _children)
            return { y = node.y, h = 0 }
         end,
      },
      ["local_function"] = {
         before = increment_indent,
         after = after_function("local"),
      },
      ["global_function"] = {
         before = increment_indent,
         after = after_function("global"),
      },
      ["record_function"] = {
         before = increment_indent,
         after = after_function("record"),
      },
      ["function"] = {
         before = increment_indent,
         after = after_function("anonymous"),
      },
      ["paren"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "(")
            add_child(out, children[1], "", indent)
            table.insert(out, ")")
            return out
         end,
      },
      ["op"] = {
         after = function(_, node, children)
            local out = { y = node.y, h = 0 }
            if node.op.op == "@funcall" then
               add_child(out, children[1], "", indent)
               table.insert(out, "(")
               add_child(out, children[3], "", indent)
               table.insert(out, ")")
            elseif node.op.op == "@index" then
               add_child(out, children[1], "", indent)
               table.insert(out, "[")
               if starts_with_longstring(node.e2) then
                  table.insert(children[3], 1, " ")
                  table.insert(children[3], " ")
               end
               add_child(out, children[3], "", indent)
               table.insert(out, "]")
            elseif node.op.op == "as" then
               add_child(out, children[1], "", indent)
            elseif node.op.op == "is" then
               if node.e2.casttype.typename == "integer" then
                  table.insert(out, "math.type(")
                  add_child(out, children[1], "", indent)
                  table.insert(out, ") == \"integer\"")
               elseif node.e2.casttype.typename == "nil" then
                  add_child(out, children[1], "", indent)
                  table.insert(out, " == nil")
               else
                  table.insert(out, "type(")
                  add_child(out, children[1], "", indent)
                  table.insert(out, ") == \"")
                  add_child(out, children[3], "", indent)
                  table.insert(out, "\"")
               end
            elseif spaced_op[node.op.arity][node.op.op] or tight_op[node.op.arity][node.op.op] then
               local space = spaced_op[node.op.arity][node.op.op] and " " or ""
               if children[2] and node.op.prec > tonumber(children[2]) then
                  table.insert(children[1], 1, "(")
                  table.insert(children[1], ")")
               end
               if node.op.arity == 1 then
                  table.insert(out, node.op.op)
                  add_child(out, children[1], space, indent)
               elseif node.op.arity == 2 then
                  add_child(out, children[1], "", indent)
                  if space == " " then
                     table.insert(out, " ")
                  end
                  table.insert(out, node.op.op)
                  if children[4] and node.op.prec > tonumber(children[4]) then
                     table.insert(children[3], 1, "(")
                     table.insert(children[3], ")")
                  end
                  add_child(out, children[3], space, indent)
               end
            else
               error("unknown node op " .. node.op.op)
            end
            return out
         end,
      },
      ["newtype"] = {
         after = function(_, node, _children)
            local out = { y = node.y, h = 0 }
            local nt = node.newtype
            if nt.typename == "typedecl" then
               local def = nt.def
               if def.fields then
                  table.insert(out, print_record_def(def))
               elseif def.typename == "nominal" then
                  table.insert(out, table.concat(def.names, "."))
               else
                  table.insert(out, "{}")
               end
            end
            return out
         end,
      },
      ["goto"] = {
         after = function(_, node, _children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "goto ")
            table.insert(out, node.label)
            return out
         end,
      },
      ["label"] = {
         after = function(_, node, _children)
            local out = { y = node.y, h = 0 }
            table.insert(out, "::")
            table.insert(out, node.label)
            table.insert(out, "::")
            return out
         end,
      },
      ["string"] = {
         after = function(_, node, children)






            if node.tk:sub(1, 1) == "[" or gen_target ~= "5.1" or not node.tk:find("\\", 1, true) then
               return emit_exactly(nil, node, children)
            end

            local str = node.tk
            local replaced = {}

            local i = 1
            local currstrstart = 1
            while true do
               local slashpos = str:find("\\", i)
               if not slashpos then break end
               local nextc = str:sub(slashpos + 1, slashpos + 1)
               if nextc == "z" then
                  table.insert(replaced, str:sub(currstrstart, slashpos - 1))
                  local wsend = str:find("%S", slashpos + 2)
                  currstrstart = wsend
                  i = currstrstart
               elseif nextc == "x" then
                  table.insert(replaced, str:sub(currstrstart, slashpos - 1))
                  local digits = str:sub(slashpos + 2, slashpos + 3)
                  local byte = tonumber(digits, 16)
                  table.insert(replaced, string.format("\\%03d", byte))
                  currstrstart = slashpos + 4
                  i = currstrstart
               elseif nextc == "u" then
                  table.insert(replaced, str:sub(currstrstart, slashpos - 1))
                  local _, e, hex_digits = str:find("{(.-)}", slashpos + 2)
                  local codepoint = tonumber(hex_digits, 16)
                  local sequence = utf8.char(codepoint)
                  table.insert(replaced, (sequence:gsub(".", function(c)
                     return ("\\%03d"):format(string.byte(c))
                  end)))
                  currstrstart = e + 1
                  i = currstrstart
               else
                  i = slashpos + 2
               end
            end
            if currstrstart <= #str then
               table.insert(replaced, str:sub(currstrstart))
            end

            local h = 0
            local finalstr = table.concat(replaced)
            for _ in finalstr:gmatch("\n") do
               h = h + 1
            end
            return {
               y = node.y,
               h = h,
               finalstr,
            }
         end,
      },

      ["variable"] = emit_exactly_visitor_cbs,
      ["identifier"] = emit_exactly_visitor_cbs,
      ["number"] = emit_exactly_visitor_cbs,
      ["integer"] = emit_exactly_visitor_cbs,
      ["nil"] = emit_exactly_visitor_cbs,
      ["boolean"] = emit_exactly_visitor_cbs,
      ["..."] = emit_exactly_visitor_cbs,
      ["argument"] = emit_exactly_visitor_cbs,
      ["type_identifier"] = emit_exactly_visitor_cbs,

      ["cast"] = emit_nothing_visitor_cbs,
      ["pragma"] = emit_nothing_visitor_cbs,
   }

   local visit_type = {}
   visit_type.cbs = {}
   local default_type_visitor = {
      after = function(_, typ, _children)
         local out = { y = typ.y or -1, h = 0 }
         local r = typ.typename == "nominal" and typ.resolved or typ
         local lua_type = types.lua_primitives[r.typename] or "table"
         if r.fields and r.is_userdata then
            lua_type = "userdata"
         end
         table.insert(out, lua_type)
         return out
      end,
   }

   visit_type.cbs["string"] = default_type_visitor
   visit_type.cbs["typedecl"] = default_type_visitor
   visit_type.cbs["typevar"] = default_type_visitor
   visit_type.cbs["typearg"] = default_type_visitor
   visit_type.cbs["function"] = default_type_visitor
   visit_type.cbs["thread"] = default_type_visitor
   visit_type.cbs["array"] = default_type_visitor
   visit_type.cbs["map"] = default_type_visitor
   visit_type.cbs["tupletable"] = default_type_visitor
   visit_type.cbs["record"] = default_type_visitor
   visit_type.cbs["enum"] = default_type_visitor
   visit_type.cbs["boolean"] = default_type_visitor
   visit_type.cbs["nil"] = default_type_visitor
   visit_type.cbs["number"] = default_type_visitor
   visit_type.cbs["integer"] = default_type_visitor
   visit_type.cbs["union"] = default_type_visitor
   visit_type.cbs["nominal"] = default_type_visitor
   visit_type.cbs["emptytable"] = default_type_visitor
   visit_type.cbs["literal_table_item"] = default_type_visitor
   visit_type.cbs["unresolved_emptytable_value"] = default_type_visitor
   visit_type.cbs["tuple"] = default_type_visitor
   visit_type.cbs["poly"] = default_type_visitor
   visit_type.cbs["any"] = default_type_visitor
   visit_type.cbs["unknown"] = default_type_visitor
   visit_type.cbs["invalid"] = default_type_visitor
   visit_type.cbs["none"] = default_type_visitor

   visit_node.cbs["expression_list"] = visit_node.cbs["variable_list"]
   visit_node.cbs["argument_list"] = visit_node.cbs["variable_list"]

   local out = traversal.traverse_nodes(nil, ast, visit_node, visit_type)

   local code
   if opts.preserve_newlines then
      code = { y = 1, h = 0 }
      add_child(code, out)
   else
      code = out
   end
   return (concat_output(code):gsub(" *\n", "\n"))
end

return lua_generator
