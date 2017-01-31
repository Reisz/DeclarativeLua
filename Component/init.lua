local class = require "middleclass"

local array = require "array"
local prototype = require "Component.prototype"

local _error_sequence = [[Index %d is not in range.
All numerical indices should be an uninterrupted sequence starting at 1.]]
local _error_defaultparam = [[
The value passed as default parameter %d is of invalid type "%s".]]
local _error_signalassign = [[Incorrect assignment to signal %s.
Assign a function or an array of functions to signals.]]
local _error_nonproto = [[
The table assigned to property %s is not a valid prototype.
Use Component.declareType to make your classes compatible to properties.]]
local _error_indextype = [[Assignment to ignored index %s.
You should only assign to array indices or string fields.]]
local _error_nosignal = [[The signal %s could not be found in this Component.]]
local _error_noprop = [[The property %s could not be found in this Component.]]
local _error_rdonly = [[Trying to change read-only property %s.]]
local _error_wrong_type = [[
Trying to assign value of incorrect type "%s" to property %s.
Matcher expected type "%s".]]
local _error_invalid_instance = [[
Attempting to instance prototype without a corresponding Component.]]
local _error_type_requirements = [[
Component values need the member functions get() and set(value) to be present.]]

-- clear value needs to be a function to pass prototype check
local  _clear_value, _property_marker, _signal_marker = function() end, {}, {}
local function _apply_clear_value(v)
  if v == _clear_value then return nil else return v end
end
local function _is_property(v)
  return type(v) == "table" and v[_property_marker]
end
local function _is_signal(v)
  return type(v) == "table" and v[_signal_marker]
end
local function _default_matcher() return true end
local function _new_property(value, data)
  return {
    value, read_only = data and data.read_only,
    matcher = data and data.matcher or _default_matcher
  }
end
local _signal_mt = { __mode = "k" }
local function _new_signal() return setmetatable({}, _signal_mt) end
local function _add_property(self, name, property, value)
  local p = _new_property(property[1], property)

  -- add to component
  self.properties[name] = p
  self.signals[name .. "Changed"] = _new_signal()

  -- get instance if prototype was assigned
  if type(p[1]) == "table" then p[1] = p[1](self, name) end

  -- set to assigned value
  if type(value) ~= "nil" then
    self:set(name, _apply_clear_value(value))
  else
    assert(p.matcher(p[1])) -- TODO message
  end
end
local function _notify_change(self, name, value)
  self:emit(name .. "Changed", value, name)
end
local function _signal_assignment_name(name)
  return "on" .. string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
end
local function _is_signal_assignment(name)
  return string.find(name, "^on%u")
end
local function _prepend_array(tbl, prep)
  local shift = #prep
  for i = #tbl, 1, -1 do tbl[i + shift] = tbl[i] end
  for i = 1, shift do tbl[i] = prep[i] end
end


local Component = class("Component")

-- provide the ability to have static properties and signals
Component.static.static_properties = {}
Component.static.static_signals    = { "completed" }
function Component.static:subclassed(other)
  other.static.static_properties =
    setmetatable({}, { __index = self.static.static_properties })
  other.static.static_signals    = {}
    -- setmetatable({}, { __index = self.static.static_signals })
    -- NOTE probably not needed
end

function Component.static:staticProperty(name, value, data)
  -- TODO improve assertions
  assert(type(name) == "string")
  assert(type(self.static.static_properties[name]) == "nil")
  self.static.static_properties[name] = _new_property(value, data)
end

function Component.static:staticSignal(name)
  -- TODO improve assertions
  assert(type(name) == "string")
  table.insert(self.static.static_signals, name)
end

-- provide the ability to add properties and signals and set nil on creation
Component.static.clearValue = _clear_value
function Component.static.property(value, data)
  local p = _new_property(value, data)
  p[_property_marker] = true
  return p
end
function Component.static.signal(name)
  return { name = name, [_signal_marker] = true }
end

prototype.prepare(Component)
function Component.static:prototyped(tbl)
  local len = #tbl
  local signals = {}
  
  for i,v in pairs(tbl) do
    local ti, tv = type(i), type(v)
    if ti == "number" then
      assert(i <= len, string.format(_error_sequence, i))
      -- all array elements are signals or default values
      if _is_signal(v) then
        signals[v.name] = true
      else
        assert(self:isValidDefault(v),
          string.format(_error_defaultparam, i, tostring(v)))
      end
    elseif ti == "string" then
      if _is_signal_assignment(i) then
        -- check value (function or array of functions)
        if tv == "table" then
          local sig_len = #v
          for sig_i, sig_v in pairs(v) do
            assert(type(sig_i) == "number" and sig_i <= sig_len
              and type(sig_v) == "function",
              string.format(_error_signalassign, i))
          end
        else
          assert(tv == "function", string.format(_error_signalassign, i))
        end
        
        -- check for signal being present
        if not signals[_signal_assignment_name(ti)] then
          local klass = self
          repeat
            if array.find(klass.static_signals, ti) then
              break
            end
            klass = klass.super
          until not klass
          assert(klass) -- TODO message
        end
      elseif tv ~= "table" or prototype.isPrototype(v) then
        assert(self.static_properties[i]) -- TODO message
      else
        assert(_is_property(v), string.format(_error_nonproto, i))
      end
    else
      error(string.format(_error_indextype, tostring(i)))
    end
  end
end

function Component.static.beforeInstance(proto, tbl)
  if tbl then
    proto.proto:prototyped(tbl)
    local oldTbl = proto.args[2]

    -- shift back array part in new tbl to join old entries before
    _prepend_array(tbl, oldTbl)

    -- join hash part
    for i,oval in pairs(oldTbl) do
      if type(i) == "string" then
        local nval = tbl[i]
        if _is_signal_assignment(i) then
          -- join multiple functions or function arrays into one array
          local newSignal = type(nval) == "table" and nval or { nval }
          tbl[i] = newSignal

          if type(oval) == "table" then
            _prepend_array(newSignal, oval)
          else
            table.insert(newSignal, 1, oval)
          end
        elseif _is_property(oval) then
          -- copy dynamic property and change value
          tbl[i] = Component.static.property(nval, oval)
        elseif type(nval) == "nil" then
          -- otherwise just overwrite regular assignment
          tbl[i] = oval
        end
      end
    end

    -- return a new prototype with adapted `tbl`
    return prototype.copy(proto, { proto.args[1], tbl})
  end
end

function Component.static.isValidDefault(--[[self, proto_of_default]])
  return false
end
function Component.addDefault(--[[self, value]]) end

function Component:initialize(tbl)
  rawset(self, "properties", {})
  rawset(self, "signals", {})

  -- initialize and assign static properties and signals
  local klass = self.class
  repeat
    for i, v in pairs(klass.static_properties) do
      _add_property(self, i, v, tbl[i]); tbl[i] = nil
    end
    for _, v in ipairs(klass.static_signals) do
      self.signals[v] = _new_signal()
    end
    klass = klass.super
  until not klass

  -- setup dynamic properties and signals and default values
  for i,v in pairs(tbl) do
    if _is_property(v) then
      _add_property(self, i, v)
    elseif _is_signal(v) then
      self.signals[v.name] = _new_signal()
    elseif type(i) == "number" then
      self:addDefault(v)
    end
  end

  -- initialize signal assignments
  for i, v in pairs(self.signals) do
    local name = _signal_assignment_name(i)
    local callback = tbl[name]
    local t = type(callback)
    if t == "table" then array.join(v, callback)
    elseif t ~= "nil" then table.insert(v, callback) end
  end

  -- tbl should be empty now if check was correct
  self:emit("completed")
end

-- (signal : string, callback : function)
-- (signal : string, receiver : object, callback : string)
function Component:connect(signal, receiver, callback)
  local s = self.signals[signal]
  assert(s, string.format(_error_nosignal, signal))

  if not callback then
    table.insert(s, receiver)
  else
    s[receiver] = callback
  end
end

-- (signal : string, callback : function)
-- (signal : string, receiver : object)
function Component:disconnect(signal, receiver)
  local s = self.signals[signal]
  assert(s, string.format(_error_nosignal, signal))

  if type(receiver) ~= "table" then
    array.filter(s, function(v) if v ~= receiver then return v end end)
  else
    s[receiver] = nil
  end
end

function Component:emit(signal, ...)
  for i,v in pairs(self.signals[signal]) do
    if type(i) == "table" then i[v](i, ...) else v(...) end
  end
end


function Component:get(name)
  local p = self.properties[name]
  local v = p and p[1]
  return type(v) == "table" and v:get() or v
end
Component.__index = Component.get

function Component:set(name, value)
  local p = self.properties[name]
  assert(p, string.format(_error_noprop, name))
  assert(not p.read_only, string.format(_error_rdonly, name))

  -- if value type is complex, try assigning directly
  local v = p[1]
  if type(v) == "table" then
    if v:set(value) then return end
  end

  -- if value type is basic or would change: check matcher
  assert(p.matcher(value), string.format(_error_wrong_type,
    tostring(value), name, tostring(p.matcher)))

  p[1] = value
  _notify_change(self, name, value)
end

function Component:__newindex(name, value)
  local a, b = string.match(name, "^on(%u)(.*)$")
  if a then
    self:connect(string.lower(a) .. b, value)
  else
    self:set(name, value)
  end
end

local type_mixin = {
  changed = function(self)
    _notify_change(self._parent, self._name, self:get())
  end,
  instanced = function(self, parent, name)
    assert(type(self._parent) == "nil" and type(self._name) == "nil",
      _error_invalid_instance)
    rawset(self, "_parent", parent)
    rawset(self, "_name", name)
  end
}
function Component.static.declareType(t)
  assert(type(t.get) == "function" and type(t.set) == "function",
    _error_type_requirements)
  
  prototype.prepare(t)
  t:include(type_mixin)

  return t
end

return Component
