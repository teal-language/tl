--------------------------------------------------------------------------------
-- Lua code generation
--------------------------------------------------------------------------------
local attributes = require("teal.attributes")
local type Attribute = attributes.Attribute

local types = require("teal.types")
local type Type = types.Type
local type TypeName = types.TypeName
local type TypeDeclType = types.TypeDeclType
local type GenericType = types.GenericType
local type NominalType = types.NominalType
local type RecordType = types.RecordType
local type RecordLikeType = types.RecordLikeType

local parser = require("teal.parser")
local type Node = parser.Node
local type NodeKind = parser.NodeKind

local traversal = require("teal.traversal")
local type Visitor = traversal.Visitor
local type VisitorCallbacks = traversal.VisitorCallbacks

local record lua_generator
   record Options
      preserve_indent: boolean
      preserve_newlines: boolean
      preserve_hashbang: boolean
   end

   enum Target
      "5.1"
      "5.3"
      "5.4"
   end

   default_opts: Options
   fast_opts: Options
end

local type Options = lua_generator.Options
local type Target = lua_generator.Target

local tight_op: {integer:{string:boolean}} = {
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

local spaced_op: {integer:{string:boolean}} = {
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

function lua_generator.generate(ast: types.Node, gen_target: Target, opts?: Options): string, string
   local err: string
   local indent = 0

   opts = opts or lua_generator.default_opts

   local record Output
      {string}
      y: integer
      h: integer
   end

   local save_indent: {integer} = {}

   local function increment_indent(_: nil, node: Node)
      local child = node.body or node[1]
      if not child then
         return
      end
      if child.y ~= node.y then
         if indent == 0 and #save_indent > 0 then
            indent = save_indent[#save_indent] + 1
         else
            indent = indent + 1
         end
      else
         table.insert(save_indent, indent)
         indent = 0
      end
   end

   local function decrement_indent(node: Node, child: Node)
      if child.y ~= node.y then
         indent = indent - 1
      else
         indent = table.remove(save_indent)
      end
   end

   if not opts.preserve_indent then
      increment_indent = nil
      decrement_indent = function() end
   end

   local function add_string(out: Output, s: string)
      table.insert(out, s)
      if string.find(s, "\n", 1, true) then
         for _nl in s:gmatch("\n") do
            out.h = out.h + 1
         end
      end
   end

   local function add_child(out: Output, child: Output, space?: string, current_indent?: integer): integer
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
      table.insert(out, child as string)
      out.h = out.h + child.h
   end

   local function concat_output(out: Output): string
      for i, s in ipairs(out) do
         if type(s) == "table" then
            out[i] = concat_output(s as Output)
         end
      end
      return table.concat(out)
   end

   local function print_record_def(typ: RecordLikeType): string
      local out: {string} = { "{" }
      local i = 0
      for fname, ftype in traversal.fields_of(typ) do
         if ftype is TypeDeclType then
            local def = ftype.def
            if def is GenericType then
               def = def.t
            end
            if def is RecordType then
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

   local visit_node: Visitor<nil, NodeKind, Node, Output> = {}

   local lua_54_attribute <total>: {Attribute:string} = {
      ["const"] = " <const>",
      ["close"] = " <close>",
      ["total"] = " <const>",
   }

   local function emit_exactly(_: nil, node: Node, _children: {Output}): Output
      local out: Output = { y = node.y, h = 0 }
      add_string(out, node.tk)
      return out
   end

   local emit_exactly_visitor_cbs <const>: VisitorCallbacks<nil, Node, Output> = { after = emit_exactly }

   local emit_nothing_visitor_cbs <const>: VisitorCallbacks<nil, Node, Output> = {
      after = function(_: nil, node: Node, _children: {Output}): Output
         local out: Output = { y = node.y, h = 0 }
         return out
      end
   }

   local function starts_with_longstring(n: Node): boolean
      while n.e1 do n = n.e1 end
      return n.is_longstring
   end

   visit_node.cbs = {
      ["statements"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output
            if opts.preserve_hashbang and node.hashbang then
               out = { y = 1, h = 0 }
               table.insert(out, node.hashbang)
            else
               out = { y = node.y, h = 0 }
            end
            local space: string
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
         end
      },
      ["local_declaration"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "local ")
            for i, var in ipairs(node.vars) do
               if i > 1 then
                  add_string(out, ", ")
               end
               add_string(out, var.tk)
               if var.attribute then
                  if gen_target ~= "5.4" and var.attribute == "close" then
                     err = "attempt to emit a <close> attribute for a non 5.4 target"
                  end

                  if gen_target == "5.4" then
                     add_string(out, lua_54_attribute[var.attribute])
                  end
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
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
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
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if children[2] then
               add_child(out, children[1])
               table.insert(out, " =")
               add_child(out, children[2], " ")
            end
            return out
         end,
      },
      ["global_declaration"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            if children[3] then
               add_child(out, children[1])
               table.insert(out, " =")
               add_child(out, children[3], " ")
            end
            return out
         end,
      },
      ["assignment"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            add_child(out, children[1])
            table.insert(out, " =")
            add_child(out, children[3], " ")
            return out
         end,
      },
      ["if"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            for i, child in ipairs(children) do
               add_child(out, child, i > 1 and " ", child.y ~= node.y and indent)
            end
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["if_block"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
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
            add_child(out, children[2], " ")
            decrement_indent(node, node.body)
            return out
         end,
      },
      ["while"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "while")
            add_child(out, children[1], " ")
            table.insert(out, " do")
            add_child(out, children[2], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["repeat"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "repeat")
            add_child(out, children[1], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "until " }, " ", indent)
            add_child(out, children[2])
            return out
         end,
      },
      ["do"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "do")
            add_child(out, children[1], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["forin"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "for")
            add_child(out, children[1], " ")
            table.insert(out, " in")
            add_child(out, children[2], " ")
            table.insert(out, " do")
            add_child(out, children[3], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["fornum"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
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
            add_child(out, children[5], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["return"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "return")
            if #children[1] > 0 then
               add_child(out, children[1], " ")
            end
            return out
         end,
      },
      ["break"] = {
         after = function(_: nil, node: Node, _children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "break")
            return out
         end,
      },
      ["variable_list"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            local space: string
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
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
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
            decrement_indent(node, node[1])
            add_child(out, { y = node.yend, h = 0, [1] = "}" }, " ", indent)
            return out
         end,
      },
      ["literal_table_item"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
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
         after = function(_: nil, node: Node, _children: {Output}): Output
            return { y = node.y, h = 0 }
         end,
      },
      ["local_function"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "local function")
            add_child(out, children[1], " ")
            table.insert(out, "(")
            add_child(out, children[2])
            table.insert(out, ")")
            add_child(out, children[4], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["global_function"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "function")
            add_child(out, children[1], " ")
            table.insert(out, "(")
            add_child(out, children[2])
            table.insert(out, ")")
            add_child(out, children[4], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["record_function"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "function")
            add_child(out, children[1], " ")
            table.insert(out, node.is_method and ":" or ".")
            add_child(out, children[2])
            table.insert(out, "(")
            if node.is_method then
               -- remove self
               table.remove(children[3], 1)
               if children[3][1] == "," then
                  table.remove(children[3], 1)
                  if children[3][1] == " " then
                     table.remove(children[3], 1)
                  end
               end
            end
            add_child(out, children[3])
            table.insert(out, ")")
            add_child(out, children[5], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["function"] = {
         before = increment_indent,
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "function(")
            add_child(out, children[1])
            table.insert(out, ")")
            add_child(out, children[3], " ")
            decrement_indent(node, node.body)
            add_child(out, { y = node.yend, h = 0, [1] = "end" }, " ", indent)
            return out
         end,
      },
      ["paren"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "(")
            add_child(out, children[1], "", indent)
            table.insert(out, ")")
            return out
         end,
      },
      ["op"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
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
         after = function(_: nil, node: Node, _children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            local nt = node.newtype
            if nt is TypeDeclType then
               local def = nt.def
               if def is RecordLikeType then
                  table.insert(out, print_record_def(def))
               elseif def is NominalType then
                  table.insert(out, table.concat(def.names, "."))
               else
                  table.insert(out, "{}")
               end
            end
            return out
         end,
      },
      ["goto"] = {
         after = function(_: nil, node: Node, _children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "goto ")
            table.insert(out, node.label)
            return out
         end,
      },
      ["label"] = {
         after = function(_: nil, node: Node, _children: {Output}): Output
            local out: Output = { y = node.y, h = 0 }
            table.insert(out, "::")
            table.insert(out, node.label)
            table.insert(out, "::")
            return out
         end,
      },
      ["string"] = {
         after = function(_: nil, node: Node, children: {Output}): Output
            -- translate escape sequences not supported by Lua 5.1
            -- in particular:
            --  - \z : removes trailing whitespace
            --  - \xXX : hex byte
            --  - \u{} : unicode

            if node.tk:sub(1, 1) == "[" or gen_target ~= "5.1" or not node.tk:find("\\", 1, true) then
               return emit_exactly(nil, node, children)
            end

            local str = node.tk
            local replaced: {string} = {}

            local i = 1
            local currstrstart = 1
            while true do
               local slashpos = str:find("\\", i)
               if not slashpos then break end
               local nextc = str:sub(slashpos + 1, slashpos + 1)
               if nextc == "z" then
                  table.insert(replaced, str:sub(currstrstart, slashpos - 1))
                  local wsend = str:find("%S", slashpos + 2) -- next non-whitespace
                  currstrstart = wsend
                  i = currstrstart
               elseif nextc == "x" then
                  table.insert(replaced, str:sub(currstrstart, slashpos - 1))
                  local digits <const> = str:sub(slashpos + 2, slashpos + 3)
                  local byte <const> = tonumber(digits, 16)
                  table.insert(replaced, string.format("\\%03d", byte))
                  currstrstart = slashpos + 4
                  i = currstrstart
               elseif nextc == "u" then
                  table.insert(replaced, str:sub(currstrstart, slashpos - 1))
                  local _, e, hex_digits = str:find("{(.-)}", slashpos + 2)
                  local codepoint <const> = tonumber(hex_digits, 16)
                  local sequence <const> = utf8.char(codepoint)
                  table.insert(replaced, (sequence:gsub(".", function(c: string): string
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

   local visit_type: Visitor<nil, TypeName, Type, Output> = {}
   visit_type.cbs = {}
   local default_type_visitor = {
      after = function(_: nil, typ: Type, _children: {Output}): Output
         local out: Output = { y = typ.y or -1, h = 0 }
         local r = typ is NominalType and typ.resolved or typ
         local lua_type = types.lua_primitives[r.typename] or "table"
         if r is RecordLikeType and r.is_userdata then
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
   if err then
      return nil, err
   end

   local code: Output
   if opts.preserve_newlines then
      code = { y = 1, h = 0 }
      add_child(code, out)
   else
      code = out
   end
   return (concat_output(code):gsub(" *\n", "\n"))
end

function lua_generator.target_from_lua_version(str: string): Target
   if str == "Lua 5.1"
      or str == "Lua 5.2" then
      return "5.1"
   elseif str == "Lua 5.3" then
      return "5.3"
   elseif str == "Lua 5.4" then
      return "5.4"
   end
end

return lua_generator
