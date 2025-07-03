local record attributes
   enum Attribute
      "const"
      "close"
      "total"
   end

   is_attribute: {string:boolean}
end

local all_attributes <total>: {attributes.Attribute: boolean} = {
   ["const"] = true,
   ["close"] = true,
   ["total"] = true,
}

attributes.is_attribute = all_attributes as {string:boolean}

return attributes
