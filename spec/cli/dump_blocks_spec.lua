local util = require("spec.util")

describe("tl dump-blocks", function()
   setup(util.chdir_setup)
   teardown(util.chdir_teardown)

   it("outputs Lua table by default", function()
      local name = util.write_tmp_file(finally, [[
         local x = 1
      ]])
      local pd = io.popen(util.tl_cmd("dump-blocks", name), "r")
      local output = pd:read("*a")
      util.assert_popen_close(0, pd:close())

      local chunk, load_err = load("return " .. output, "dump-blocks-output")
      assert.is_truthy(chunk, load_err)
      local root = chunk()
      assert.equals("statements", root.kind)
      assert.is_table(root[1])

      local decl = root[1]
      assert.equals("local_declaration", decl.kind)
      assert.is_table(decl.VARS)
      assert.is_table(decl.EXPS)
   end)

   it("supports json output", function()
      local name = util.write_tmp_file(finally, "local x = 1\n")
      local pd = io.popen(util.tl_cmd("dump-blocks --format json", name), "r")
      local output = pd:read("*a")
      util.assert_popen_close(0, pd:close())

      local pattern_safe_name = name:gsub("(%W)", "%%%1")
      local normalized = output:gsub(pattern_safe_name, "<TMP>")

      local expected = [[
{
  "kind": "statements",
  "tk": "local",
  "f": "<TMP>",
  "y": 1,
  "x": 1,
  "yend": 2,
  "xend": 5,
  "1":     {
      "kind": "local_declaration",
      "tk": "x",
      "f": "<TMP>",
      "y": 1,
      "x": 7,
      "1":         {
          "kind": "variable_list",
          "tk": "x",
          "f": "<TMP>",
          "y": 1,
          "x": 7,
          "yend": 1,
          "xend": 7,
          "1":             {
              "kind": "identifier",
              "tk": "x",
              "f": "<TMP>",
              "y": 1,
              "x": 7
            },
          "FIRST":             {
              "kind": "identifier",
              "tk": "x",
              "f": "<TMP>",
              "y": 1,
              "x": 7
            }
        },
      "VARS":         {
          "kind": "variable_list",
          "tk": "x",
          "f": "<TMP>",
          "y": 1,
          "x": 7,
          "yend": 1,
          "xend": 7,
          "1":             {
              "kind": "identifier",
              "tk": "x",
              "f": "<TMP>",
              "y": 1,
              "x": 7
            },
          "FIRST":             {
              "kind": "identifier",
              "tk": "x",
              "f": "<TMP>",
              "y": 1,
              "x": 7
            }
        },
      "2":         {
          "kind": "tuple_type",
          "tk": "=",
          "f": "<TMP>",
          "y": 1,
          "x": 9,
          "yend": 1,
          "xend": 9,
          "1":             {
              "kind": "typelist",
              "tk": "=",
              "f": "<TMP>",
              "y": 1,
              "x": 9,
              "1": null,
              "FIRST": null
            },
          "FIRST":             {
              "kind": "typelist",
              "tk": "=",
              "f": "<TMP>",
              "y": 1,
              "x": 9,
              "1": null,
              "FIRST": null
            },
          "2": null,
          "SECOND": null
        },
      "DECL":         {
          "kind": "tuple_type",
          "tk": "=",
          "f": "<TMP>",
          "y": 1,
          "x": 9,
          "yend": 1,
          "xend": 9,
          "1":             {
              "kind": "typelist",
              "tk": "=",
              "f": "<TMP>",
              "y": 1,
              "x": 9,
              "1": null,
              "FIRST": null
            },
          "FIRST":             {
              "kind": "typelist",
              "tk": "=",
              "f": "<TMP>",
              "y": 1,
              "x": 9,
              "1": null,
              "FIRST": null
            },
          "2": null,
          "SECOND": null
        },
      "3":         {
          "kind": "expression_list",
          "tk": "=",
          "f": "<TMP>",
          "y": 1,
          "x": 9,
          "yend": 1,
          "xend": 11,
          "1":             {
              "kind": "integer",
              "tk": "1",
              "f": "<TMP>",
              "y": 1,
              "x": 11
            },
          "FIRST":             {
              "kind": "integer",
              "tk": "1",
              "f": "<TMP>",
              "y": 1,
              "x": 11
            },
          "2": null,
          "SECOND": null
        },
      "EXPS":         {
          "kind": "expression_list",
          "tk": "=",
          "f": "<TMP>",
          "y": 1,
          "x": 9,
          "yend": 1,
          "xend": 11,
          "1":             {
              "kind": "integer",
              "tk": "1",
              "f": "<TMP>",
              "y": 1,
              "x": 11
            },
          "FIRST":             {
              "kind": "integer",
              "tk": "1",
              "f": "<TMP>",
              "y": 1,
              "x": 11
            },
          "2": null,
          "SECOND": null
        }
    },
  "1":     {
      "kind": "local_declaration",
      "tk": "x",
      "f": "<TMP>",
      "y": 1,
      "x": 7,
      "1":         {
          "kind": "variable_list",
          "tk": "x",
          "f": "<TMP>",
          "y": 1,
          "x": 7,
          "yend": 1,
          "xend": 7,
          "1":             {
              "kind": "identifier",
              "tk": "x",
              "f": "<TMP>",
              "y": 1,
              "x": 7
            },
          "FIRST":             {
              "kind": "identifier",
              "tk": "x",
              "f": "<TMP>",
              "y": 1,
              "x": 7
            }
        },
      "VARS":         {
          "kind": "variable_list",
          "tk": "x",
          "f": "<TMP>",
          "y": 1,
          "x": 7,
          "yend": 1,
          "xend": 7,
          "1":             {
              "kind": "identifier",
              "tk": "x",
              "f": "<TMP>",
              "y": 1,
              "x": 7
            },
          "FIRST":             {
              "kind": "identifier",
              "tk": "x",
              "f": "<TMP>",
              "y": 1,
              "x": 7
            }
        },
      "2":         {
          "kind": "tuple_type",
          "tk": "=",
          "f": "<TMP>",
          "y": 1,
          "x": 9,
          "yend": 1,
          "xend": 9,
          "1":             {
              "kind": "typelist",
              "tk": "=",
              "f": "<TMP>",
              "y": 1,
              "x": 9,
              "1": null,
              "FIRST": null
            },
          "FIRST":             {
              "kind": "typelist",
              "tk": "=",
              "f": "<TMP>",
              "y": 1,
              "x": 9,
              "1": null,
              "FIRST": null
            },
          "2": null,
          "SECOND": null
        },
      "DECL":         {
          "kind": "tuple_type",
          "tk": "=",
          "f": "<TMP>",
          "y": 1,
          "x": 9,
          "yend": 1,
          "xend": 9,
          "1":             {
              "kind": "typelist",
              "tk": "=",
              "f": "<TMP>",
              "y": 1,
              "x": 9,
              "1": null,
              "FIRST": null
            },
          "FIRST":             {
              "kind": "typelist",
              "tk": "=",
              "f": "<TMP>",
              "y": 1,
              "x": 9,
              "1": null,
              "FIRST": null
            },
          "2": null,
          "SECOND": null
        },
      "3":         {
          "kind": "expression_list",
          "tk": "=",
          "f": "<TMP>",
          "y": 1,
          "x": 9,
          "yend": 1,
          "xend": 11,
          "1":             {
              "kind": "integer",
              "tk": "1",
              "f": "<TMP>",
              "y": 1,
              "x": 11
            },
          "FIRST":             {
              "kind": "integer",
              "tk": "1",
              "f": "<TMP>",
              "y": 1,
              "x": 11
            },
          "2": null,
          "SECOND": null
        },
      "EXPS":         {
          "kind": "expression_list",
          "tk": "=",
          "f": "<TMP>",
          "y": 1,
          "x": 9,
          "yend": 1,
          "xend": 11,
          "1":             {
              "kind": "integer",
              "tk": "1",
              "f": "<TMP>",
              "y": 1,
              "x": 11
            },
          "FIRST":             {
              "kind": "integer",
              "tk": "1",
              "f": "<TMP>",
              "y": 1,
              "x": 11
            },
          "2": null,
          "SECOND": null
        }
    }
}
]]

      assert.equals(expected, normalized)
   end)
end)
