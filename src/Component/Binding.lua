--- @classmod Component.Binding
local class = require "middleclass"
local array = require "array"


local Component = require "Component"

local Binding = class("Binding")

-- register all callbacks, then set initial value
function Binding:initialize(tbl)
  self.component = tbl.component
  self.name = tbl.name
  
  -- TODO
  
  self:update()
end

-- evaluate name dependencies
function Binding.static.prototyped(_, tbl)
  local dependencies = {}
  local fn = tbl[1]
  
  -- TODO
  
  tbl.dependencies = dependencies
end

-- Return a placeholder and register to update after all dynamic properties
-- are present
function Binding.static.beforeInstance(proto, c, name)
  local tbl = proto.args[1]
  tbl.component, tbl.name = c, name
  c:connect("completed", function() Binding:_new(tbl) end)
  
  return Component._placeholder
end

-- update to new current value
function Binding:update()
  local value = nil
  
  -- TODO
  
  self.component:set(self.name, value)
end

return Component.declareType(Binding)