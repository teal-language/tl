local _tl_compat; if (tonumber((_VERSION or ''):match('[%d.]*$')) or 0) < 5.3 then local p, m = pcall(require, 'compat53.module'); if p then _tl_compat = m end end; local ipairs = _tl_compat and _tl_compat.ipairs or ipairs; local string = _tl_compat and _tl_compat.string or string; local table = _tl_compat and _tl_compat.table or table


local errors = require("teal.errors")


local util = require("teal.util")
local binary_search = util.binary_search

local lexer = { Comment = {}, Token = {} }







































do





































   local last_token_kind = {
      ["start"] = nil,
      ["any"] = nil,
      ["identifier"] = "identifier",
      ["got -"] = "op",
      ["got --"] = nil,
      ["got ."] = ".",
      ["got .."] = "op",
      ["got ="] = "op",
      ["got ~"] = "op",
      ["got ["] = "[",
      ["got 0"] = "number",
      ["got <"] = "op",
      ["got >"] = "op",
      ["got /"] = "op",
      ["got :"] = "op",
      ["got --["] = nil,
      ["string single"] = "$ERR$",
      ["string single got \\"] = "$ERR$",
      ["string double"] = "$ERR$",
      ["string double got \\"] = "$ERR$",
      ["string long"] = "$ERR$",
      ["string long got ]"] = "$ERR$",
      ["comment short"] = nil,
      ["comment long"] = "$ERR$",
      ["comment long got ]"] = "$ERR$",
      ["number dec"] = "integer",
      ["number decfloat"] = "number",
      ["number hex"] = "integer",
      ["number hexfloat"] = "number",
      ["number power"] = "number",
      ["number powersign"] = "$ERR$",
      ["pragma"] = nil,
      ["pragma any"] = nil,
      ["pragma word"] = "pragma_identifier",
   }

   local keywords = {
      ["and"] = true,
      ["break"] = true,
      ["do"] = true,
      ["else"] = true,
      ["elseif"] = true,
      ["end"] = true,
      ["false"] = true,
      ["for"] = true,
      ["function"] = true,
      ["goto"] = true,
      ["if"] = true,
      ["in"] = true,
      ["local"] = true,
      ["nil"] = true,
      ["not"] = true,
      ["or"] = true,
      ["repeat"] = true,
      ["return"] = true,
      ["then"] = true,
      ["true"] = true,
      ["until"] = true,
      ["while"] = true,
   }

   local lex_any_char_states = {
      ["\""] = "string double",
      ["'"] = "string single",
      ["-"] = "got -",
      ["."] = "got .",
      ["0"] = "got 0",
      ["<"] = "got <",
      [">"] = "got >",
      ["/"] = "got /",
      [":"] = "got :",
      ["="] = "got =",
      ["~"] = "got ~",
      ["["] = "got [",
   }

   for c = string.byte("a"), string.byte("z") do
      lex_any_char_states[string.char(c)] = "identifier"
   end
   for c = string.byte("A"), string.byte("Z") do
      lex_any_char_states[string.char(c)] = "identifier"
   end
   lex_any_char_states["_"] = "identifier"

   for c = string.byte("1"), string.byte("9") do
      lex_any_char_states[string.char(c)] = "number dec"
   end

   local lex_word = {}
   for c = string.byte("a"), string.byte("z") do
      lex_word[string.char(c)] = true
   end
   for c = string.byte("A"), string.byte("Z") do
      lex_word[string.char(c)] = true
   end
   for c = string.byte("0"), string.byte("9") do
      lex_word[string.char(c)] = true
   end
   lex_word["_"] = true

   local lex_decimals = {}
   for c = string.byte("0"), string.byte("9") do
      lex_decimals[string.char(c)] = true
   end

   local lex_hexadecimals = {}
   for c = string.byte("0"), string.byte("9") do
      lex_hexadecimals[string.char(c)] = true
   end
   for c = string.byte("a"), string.byte("f") do
      lex_hexadecimals[string.char(c)] = true
   end
   for c = string.byte("A"), string.byte("F") do
      lex_hexadecimals[string.char(c)] = true
   end

   local lex_any_char_kinds = {}
   local single_char_kinds = { "[", "]", "(", ")", "{", "}", ",", ";", "?" }
   for _, c in ipairs(single_char_kinds) do
      lex_any_char_kinds[c] = c
   end
   for _, c in ipairs({ "#", "+", "*", "|", "&", "%", "^" }) do
      lex_any_char_kinds[c] = "op"
   end

   local lex_space = {}
   for _, c in ipairs({ " ", "\t", "\v", "\n", "\r" }) do
      lex_space[c] = true
   end

   local escapable_characters = {
      a = true,
      b = true,
      f = true,
      n = true,
      r = true,
      t = true,
      v = true,
      z = true,
      ["\\"] = true,
      ["\'"] = true,
      ["\""] = true,
      ["\r"] = true,
      ["\n"] = true,
   }

   local function lex_string_escape(input, i, c)
      if escapable_characters[c] then
         return 0, true
      elseif c == "x" then
         return 2, (
         lex_hexadecimals[input:sub(i + 1, i + 1)] and
         lex_hexadecimals[input:sub(i + 2, i + 2)])

      elseif c == "u" then
         if input:sub(i + 1, i + 1) == "{" then
            local p = i + 2
            if not lex_hexadecimals[input:sub(p, p)] then
               return 2, false
            end
            while true do
               p = p + 1
               c = input:sub(p, p)
               if not lex_hexadecimals[c] then
                  return p - i, c == "}"
               end
            end
         end
      elseif lex_decimals[c] then
         local len = lex_decimals[input:sub(i + 1, i + 1)] and
         (lex_decimals[input:sub(i + 2, i + 2)] and 2 or 1) or
         0
         return len, tonumber(input:sub(i, i + len)) < 256
      else
         return 0, false
      end
   end

   lexer.lex = function(input, filename)
      local tokens = {}

      local state = "any"
      local fwd = true
      local y = 1
      local x = 0
      local i = 0
      local lc_open_lvl = 0
      local lc_close_lvl = 0
      local ls_open_lvl = 0
      local ls_close_lvl = 0
      local errs = {}
      local nt = 0

      local tx
      local ty
      local ti
      local in_token = false

      local comments

      local function begin_token()
         tx = x
         ty = y
         ti = i
         in_token = true
      end

      local function end_token(kind, tk)
         nt = nt + 1
         tokens[nt] = {
            x = tx,
            y = ty,
            tk = tk,
            kind = kind,
            comments = comments,
         }
         comments = nil
         in_token = false
      end

      local function end_token_identifier()
         local tk = input:sub(ti, i - 1)
         nt = nt + 1
         tokens[nt] = {
            x = tx,
            y = ty,
            tk = tk,
            kind = keywords[tk] and "keyword" or "identifier",
            comments = comments,
         }
         comments = nil
         in_token = false
      end

      local function end_token_prev(kind)
         local tk = input:sub(ti, i - 1)
         nt = nt + 1
         tokens[nt] = {
            x = tx,
            y = ty,
            tk = tk,
            kind = kind,
            comments = comments,
         }
         comments = nil
         in_token = false
      end

      local function end_token_here(kind)
         local tk = input:sub(ti, i)
         nt = nt + 1
         tokens[nt] = {
            x = tx,
            y = ty,
            tk = tk,
            kind = kind,
            comments = comments,

         }
         comments = nil
         in_token = false
      end

      local function drop_token()
         in_token = false
      end

      local function add_syntax_error(msg)
         local t = tokens[nt]
         table.insert(errs, {
            filename = filename,
            y = t.y,
            x = t.x,
            msg = msg or "invalid token '" .. t.tk .. "'",
         })
      end

      local function add_comment(text)
         if not comments then
            comments = {}
         end
         comments[#comments + 1] = {
            x = tx,
            y = ty,
            text = text,
         }
      end

      local bom = "\239\187\191"
      local bom_len = bom:len()
      if input:sub(1, bom_len) == bom then
         input = input:sub(bom_len + 1)
      end

      local len = #input
      if input:sub(1, 2) == "#!" then
         begin_token()
         i = input:find("\n")
         if not i then
            i = len + 1
         end
         end_token_prev("hashbang")
         y = 2
         x = 0
      end
      state = "any"

      while i <= len do
         if fwd then
            i = i + 1
            if i > len then
               break
            end
         end

         local c = input:sub(i, i)

         if fwd then
            if c == "\n" then
               y = y + 1
               x = 0
            else
               x = x + 1
            end
         else
            fwd = true
         end

         if state == "any" then
            local st = lex_any_char_states[c]
            if st then
               state = st
               begin_token()
            else
               local k = lex_any_char_kinds[c]
               if k then
                  begin_token()
                  end_token(k, c)
               elseif not lex_space[c] then
                  begin_token()
                  end_token_here("$ERR$")
                  add_syntax_error()
               end
            end
         elseif state == "identifier" then
            if not lex_word[c] then
               end_token_identifier()
               fwd = false
               state = "any"
            end
         elseif state == "string double" then
            if c == "\\" then
               state = "string double got \\"
            elseif c == "\"" then
               end_token_here("string")
               state = "any"
            end
         elseif state == "comment short" then
            if c == "\n" then
               add_comment(input:sub(ti, i - 1))
               state = "any"
            end
         elseif state == "got =" then
            local t
            if c == "=" then
               t = "=="
            else
               t = "="
               fwd = false
            end
            end_token("op", t)
            state = "any"
         elseif state == "got ." then
            if c == "." then
               state = "got .."
            elseif lex_decimals[c] then
               state = "number decfloat"
            else
               end_token(".", ".")
               fwd = false
               state = "any"
            end
         elseif state == "got :" then
            local t
            if c == ":" then
               t = "::"
            else
               t = ":"
               fwd = false
            end
            end_token(t, t)
            state = "any"
         elseif state == "got [" then
            if c == "[" then
               state = "string long"
            elseif c == "=" then
               ls_open_lvl = ls_open_lvl + 1
            else
               end_token("[", "[")
               fwd = false
               state = "any"
               ls_open_lvl = 0
            end
         elseif state == "number dec" then
            if lex_decimals[c] then

            elseif c == "." then
               state = "number decfloat"
            elseif c == "e" or c == "E" then
               state = "number powersign"
            else
               end_token_prev("integer")
               fwd = false
               state = "any"
            end
         elseif state == "got -" then
            if c == "-" then
               state = "got --"
            else
               end_token("op", "-")
               fwd = false
               state = "any"
            end
         elseif state == "got .." then
            if c == "." then
               end_token("...", "...")
            else
               end_token("op", "..")
               fwd = false
            end
            state = "any"
         elseif state == "number hex" then
            if lex_hexadecimals[c] then

            elseif c == "." then
               state = "number hexfloat"
            elseif c == "p" or c == "P" then
               state = "number powersign"
            else
               end_token_prev("integer")
               fwd = false
               state = "any"
            end
         elseif state == "got --" then
            if c == "[" then
               state = "got --["
            elseif c == "#" then
               state = "pragma"
            else
               fwd = false
               state = "comment short"
               drop_token()
            end
         elseif state == "pragma" then
            if not lex_word[c] then
               end_token_prev("pragma")
               if tokens[nt].tk == "--#pragma" then
                  state = "pragma any"
               else
                  state = "comment short"
                  table.remove(tokens)
                  nt = nt - 1
                  drop_token()
               end
               fwd = false
            end
         elseif state == "pragma any" then
            if c == "\n" then
               state = "any"
            elseif lex_word[c] then
               state = "pragma word"
               begin_token()
            elseif not lex_space[c] then
               begin_token()
               end_token_here("$ERR$")
               add_syntax_error()
            end
         elseif state == "pragma word" then
            if not lex_word[c] then
               end_token_prev("pragma_identifier")
               fwd = false
               state = (c == "\n") and "any" or "pragma any"
            end
         elseif state == "got 0" then
            if c == "x" or c == "X" then
               state = "number hex"
            elseif c == "e" or c == "E" then
               state = "number powersign"
            elseif lex_decimals[c] then
               state = "number dec"
            elseif c == "." then
               state = "number decfloat"
            else
               end_token_prev("integer")
               fwd = false
               state = "any"
            end
         elseif state == "got --[" then
            if c == "[" then
               state = "comment long"
            elseif c == "=" then
               lc_open_lvl = lc_open_lvl + 1
            else
               fwd = false
               state = "comment short"
               drop_token()
               lc_open_lvl = 0
            end
         elseif state == "comment long" then
            if c == "]" then
               state = "comment long got ]"
            end
         elseif state == "comment long got ]" then
            if c == "]" and lc_close_lvl == lc_open_lvl then
               add_comment(input:sub(ti, i))
               drop_token()
               state = "any"
               lc_open_lvl = 0
               lc_close_lvl = 0
            elseif c == "=" then
               lc_close_lvl = lc_close_lvl + 1
            else
               state = "comment long"
               lc_close_lvl = 0
            end
         elseif state == "string double got \\" then
            local skip, valid = lex_string_escape(input, i, c)
            i = i + skip
            if not valid then
               end_token_here("$ERR$")
               add_syntax_error("malformed string")
            end
            x = x + skip
            state = "string double"
         elseif state == "string single" then
            if c == "\\" then
               state = "string single got \\"
            elseif c == "'" then
               end_token_here("string")
               state = "any"
            end
         elseif state == "string single got \\" then
            local skip, valid = lex_string_escape(input, i, c)
            i = i + skip
            if not valid then
               end_token_here("$ERR$")
               add_syntax_error("malformed string")
            end
            x = x + skip
            state = "string single"
         elseif state == "got ~" then
            local t
            if c == "=" then
               t = "~="
            else
               t = "~"
               fwd = false
            end
            end_token("op", t)
            state = "any"
         elseif state == "got <" then
            local t
            if c == "=" then
               t = "<="
            elseif c == "<" then
               t = "<<"
            else
               t = "<"
               fwd = false
            end
            end_token("op", t)
            state = "any"
         elseif state == "got >" then
            local t
            if c == "=" then
               t = ">="
            elseif c == ">" then
               t = ">>"
            else
               t = ">"
               fwd = false
            end
            end_token("op", t)
            state = "any"
         elseif state == "got /" then
            local t
            if c == "/" then
               t = "//"
            else
               t = "/"
               fwd = false
            end
            end_token("op", t)
            state = "any"
         elseif state == "string long" then
            if c == "]" then
               state = "string long got ]"
            end
         elseif state == "string long got ]" then
            if c == "]" then
               if ls_close_lvl == ls_open_lvl then
                  end_token_here("string")
                  state = "any"
                  ls_open_lvl = 0
                  ls_close_lvl = 0
               end
            elseif c == "=" then
               ls_close_lvl = ls_close_lvl + 1
            else
               state = "string long"
               ls_close_lvl = 0
            end
         elseif state == "number hexfloat" then
            if c == "p" or c == "P" then
               state = "number powersign"
            elseif not lex_hexadecimals[c] then
               end_token_prev("number")
               fwd = false
               state = "any"
            end
         elseif state == "number decfloat" then
            if c == "e" or c == "E" then
               state = "number powersign"
            elseif not lex_decimals[c] then
               end_token_prev("number")
               fwd = false
               state = "any"
            end
         elseif state == "number powersign" then
            if c == "-" or c == "+" then
               state = "number power"
            elseif lex_decimals[c] then
               state = "number power"
            elseif lex_space[c] then
               end_token_prev("$ERR$")
               fwd = false
               add_syntax_error("malformed number")
               state = "any"
            else
               end_token_here("$ERR$")
               add_syntax_error("malformed number")
               state = "any"
            end
         elseif state == "number power" then
            if not lex_decimals[c] then
               end_token_prev("number")
               fwd = false
               state = "any"
            end
         end
      end

      if in_token then
         if last_token_kind[state] then
            end_token_prev(last_token_kind[state])
            if last_token_kind[state] == "$ERR$" then
               local state_type = state:sub(1, 6)
               if state_type == "string" then
                  add_syntax_error("malformed string")
               elseif state_type == "number" then
                  add_syntax_error("malformed number")
               elseif state_type == "commen" then
                  add_syntax_error("unfinished long comment")
               else
                  add_syntax_error()
               end
            elseif keywords[tokens[nt].tk] then
               tokens[nt].kind = "keyword"
            end
         else
            drop_token()
         end
      end

      table.insert(tokens, { x = x + 1, y = y, tk = "$EOF$", kind = "$EOF$", comments = comments })

      return tokens, errs
   end
end

lexer.get_token_at = function(tks, y, x)
   local _, found = binary_search(
   tks, nil,
   function(tk)
      return tk.y < y or
      (tk.y == y and tk.x <= x)
   end)


   if found and
      found.y == y and
      found.x <= x and x < found.x + #found.tk then

      return found.tk
   end
end

return lexer
