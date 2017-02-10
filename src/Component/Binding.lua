--- @classmod Component.Binding
local class = require "middleclass"

local Component = require "Component"

-- use setfenv of Lua or simulate using upvaluejoin
local setfenv = setfenv
if not setfenv then
  setfenv = function(fn, env)
    local i = 1
    repeat
      local name = debug.getupvalue(fn, i)

      if name == "_ENV" then
        debug.upvaluejoin(fn, i, (function() return env end), 1)
        break
      end

      i = i + 1
    until not name

    return fn
  end
end

local Binding = class("Binding")

-- register all callbacks, then set initial value
function Binding:initialize(tbl)
  self.component = tbl.component
  self.func = setfenv(tbl[1], tbl.component)

  -- TODO

  self:update()

  if tbl.name then tbl.component[tbl.name] = self end
end

-- evaluate name dependencies
function Binding.static.prototyped(_, tbl)
  local dependencies = {}
  local fn = tbl[1]

  setfenv(fn, {})

  -- TODO

  tbl.dependencies = dependencies
end


function Binding.static.beforeInstance(proto, c, name)
  local tbl = proto.args[1]
  tbl.component = c

  -- no need to wait for dyamic properties now, let prototype continue
  if c.isCompleted then return nil end

  tbl.name = name
  -- return a placeholder and register to update after all dynamic properties
  -- are present
  c:connect("completed", function() Binding:_new(tbl) end)

  return Component._placeholder
end

-- always let Component override this
function Binding.set() return false end
function Binding:get() return self.value end

function Binding:update()
  -- update to new current value
  local value = self.func()

  -- do nothing when result is guaranteed to be the same value
  if type(value) ~= "table" and self.value == value then return end
  self.value = value
  self:changed()
end

return Component.declareType(Binding)