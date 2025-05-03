local util = require("spec.util")

describe("macroexp with generics", function()
   it("can resolve type arguments", util.gen([[
      local interface Component
         name: string
      end

      local record Sprocket is Component
         where self.name == "sprocket"
         size: integer
      end
         function Sprocket:new(s: integer): self
         return { name = "widget", size = s }
      end

      local record Widget is Component
         where self.name == "widget"
         color: integer
      end
      function Widget:new(c: integer): self
         return { name = "widget", color = c }
      end

      local record Archetype
         columns: {Component:{Component}}
         getColumn: function<T is Component>(self, component: T): {T} = macroexp<T is Component>(self: Archetype, component: T): {T}
            return self.columns[component] as {T}
         end
      end

      local a: Archetype = { columns = {
         [Widget] = { Widget:new(10), Widget:new(20) },
         [Sprocket] = { Sprocket:new(1), Sprocket:new(2) },
      } }

      local widgets = a:getColumn(Widget)
      local sprockets = a:getColumn(Sprocket)
      print(widgets[1].color)
      print(sprockets[1].size)
   ]], [[




      local Sprocket = {}



      function Sprocket:new(s)
         return { name = "widget", size = s }
      end

      local Widget = {}



      function Widget:new(c)
         return { name = "widget", color = c }
      end








      local a = { columns = {
         [Widget] = { Widget:new(10), Widget:new(20) },
         [Sprocket] = { Sprocket:new(1), Sprocket:new(2) },
      }, }

      local widgets = a.columns[Widget]
      local sprockets = a.columns[Sprocket]
      print(widgets[1].color)
      print(sprockets[1].size)
   ]]))
end)
