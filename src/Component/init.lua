--- @classmod Component
local class = require "middleclass"

local array = require "array"
local prototype = require "Component.prototype"
local Matcher = require "Component.Matcher"

local _error_sequence = [[Index %d is not in range.
All numerical indices should be an uninterrupted sequence starting at 1.]]
local _error_defaultparam = [[
The value passed as default parameter %d is of invalid type "%s".]]
local _error_signalassign = [[Incorrect assignment to signal %s.
Assign a function or an array of functions to signals.]]
local _error_signal_unknown = [[
Trying to assign to unknown signal %s.
Use Component.signal("%s") to create this signal dynamically.]]
local _error_signalname = [[ Invalid name for signal %s.
Signal names can only be strings starting with a lowercase character.]]
local _error_property_unknown = [[
Trying to assign to unknown property %s.
Use Component.property("%s", ...) to create this property dynamically.]]
local _error_nonproto = [[
The table assigned to property %s is not a valid prototype.
Use Component.declareType to make your classes compatible to properties.]]
local _error_indextype = [[Assignment to ignored index %s.
You should only assign to array indices or string fields.]]
local _error_not_matcher = [[Ivalid matcher for property %s.
Property matchers need to be a valid Matcher or a string compiling into one.]]
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
local _error_static_check = [[
Static checking found %d errors. See the messages below:

]]

-- clear and placeholder values needs to be a function to pass prototype check
local  _clear_value, _placeholder_value, _property_marker, _signal_marker =
  function() end, function() end, {}, {}
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
  local matcher = data and data.matcher
  if type(matcher) == "string" then matcher = Matcher(matcher) end
  return {
    value, read_only = data and data.read_only,
    matcher = matcher or _default_matcher
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
    if value == _placeholder_value then return end
    self:set(name, _apply_clear_value(value))
  else
    assert(p.matcher(p[1]), string.format(_error_wrong_type,
      tostring(p[1]), name, tostring(p.matcher)))
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
local function _is_signal_name(name)
  return type(name) == "string" and string.find(name, "^%l")
end
local function _is_callable(fn)
  return type(fn) == "function" or
    type((getmetatable(fn) or _property_marker).__call)  == "function"
end


local Component = class("Component")

-- provide the ability to have static properties and signals
Component.static.static_properties = {}
Component.static.static_signals    = {}
function Component.static:subclassed(other)
  other.static.static_properties =
    setmetatable({}, { __index = self.static.static_properties })
  other.static.static_signals    = {}
end

function Component.static:staticProperty(name, value, data)
  -- TODO improve assertions
  assert(type(name) == "string")
  assert(type(self.static.static_properties[name]) == "nil")
  self.static.static_properties[name] = _new_property(value, data)
end

function Component.static:staticSignal(name)
  assert(_is_signal_name(name),
    string.format(_error_signalname, tostring(name)))
  table.insert(self.static.static_signals, name)
end

Component:staticProperty("isCompleted", false, { read_only = true })
Component:staticSignal("completed")

-- provide the ability to add properties and signals and set nil on creation
Component.static.clear = _clear_value
Component.static._placeholder = _placeholder_value
function Component.static.property(value, data)
  local p = _new_property(value, data)
  p[_property_marker] = true
  return p
end
function Component.static.signal(name)
  return { name = name, [_signal_marker] = true }
end

prototype.prepare(Component)

-- debug only, set to nil in releases
function Component.static:prototyped(tbl)
  local len = #tbl
  local signals = {}

  local messages, next_message = {}, 1
  local function _report(...)
    messages[next_message] = string.format(...)
    next_message = next_message + 1
  end

  -- iterate over all elemets of the table checking the following properties:
  -- - all indices should either strings or fall into the array part of a table
  -- - string indices:
  --   - assignments to existing static or dynmic properties
  --     - using basic values (everything but tables) or prototypes
  --   - assignments to create new dynamic properties (using Component.property)
  --   - assignments to connect to signals (`on%u.*`)
  --     - a callable value (function or table with `__call`)
  --     - an array of callable values
  -- - array part:
  --   - assignments to the default property (basic value or prototype)
  --   - creating new dynamic signals (using Component.signal)

  for i,v in pairs(tbl) do
    local ti, tv = type(i), type(v)
    if ti == "number" then
      if i > len then
        _report(_error_sequence, i)
      elseif _is_signal(v) then
        if _is_signal_name(v.name) then
          signals[v.name] = true
        else
          _report(_error_signalname, tostring(v.name))
        end
      else
        if not self:isValidDefault(v) then
          _report(_error_defaultparam, i, tostring(v))
        end
      end
    elseif ti == "string" then
      if _is_signal_assignment(i) then
        -- check assigned value to be callable or array of callables
        if not _is_callable(v) then
          if tv ~= "table" then
            _report(_error_signalassign, i)
          else
            local sig_len = #v
            if sig_len <= 0 then _report(_error_signalassign, i) end
            for sig_i, sig_v in pairs(v) do
              if type(sig_i) ~= "number" or sig_i > sig_len or not _is_callable(sig_v) then
                _report(_error_signalassign, i)
              end
            end
          end
        end

        -- check for signal being present
        local signame = string.lower(string.sub(i, 3, 3)) .. string.sub(i, 4)
        if not signals[signame] then
          local klass = self; repeat
            if array.find(klass.static_signals, signame) then break end
            klass = klass.super
          until not klass
          if not klass then _report(_error_signal_unknown, i, signame) end
        end
      elseif tv ~= "table" or prototype.isPrototype(v) then
        -- regular assignment to property: check presence
        if not self.static_properties[i] then
          _report(_error_property_unknown, i, i)
        end
      else
        -- last possible case: creating a new dynamic property
        if _is_property(v) then
          local m = v.matcher
          if m ~= _default_matcher and type(m) ~= "string" and
            not Matcher.isMatcher(m) then
            _report(_error_not_matcher, i)
          end
        else
          _report(_error_nonproto, i)
        end
      end
    else
      _report(_error_indextype, tostring(i))
    end
  end

  if next_message > 1 then
    error(string.format(_error_static_check, next_message - 1) .. table.concat(messages, "\n"))
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
          if nval then
            tbl[i] = _is_callable(nval) and { nval } or nval
            if _is_callable(oval) then table.insert(tbl[i], 1, oval)
            else _prepend_array(tbl[i], oval) end
          else
            tbl[i] = oval
          end
        elseif _is_property(oval) then
          -- copy dynamic property: change value, keep data
          tbl[i] = Component.static.property(nval, oval)
        elseif type(nval) == "nil" then
          -- copy over omitted assignments
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
    local callback = tbl[_signal_assignment_name(i)]
    if _is_callable(callback) then table.insert(v, callback)
    elseif callback then array.join(v, callback) end
  end

  -- tbl should be empty now if check was correct
  self:_set("isCompleted", true)
  self:emit("completed")
  self.signals.completed = nil
end

-- (signal : string, callback : function)
-- (signal : string, receiver : object, callback : string)
-- having a callable object and one or more of its members connected
-- at the same time will result in undefined behaviour
function Component:connect(signal, receiver, callback)
  local s = self.signals[signal]
  assert(s, string.format(_error_nosignal, signal))

  if not callback then
    table.insert(s, receiver)
  else
    local r = s[receiver]
    if not r then r = {}; s[receiver] = r end
    table.insert(r, callback)
  end
end

-- disconnect everyting    (signal : name)
-- disconnect one function (signal : name, callback : function)
-- disconnect all members  (signal : name, receiver : object)
-- disconnect one member   (signal : name, receiver : object, callback : string)
-- pass signal = "*" to disconnect from all signals
-- having a callable object and one or more of its members connected
-- at the same time will result in undefined behaviour
local function _disconnect(signal, receiver, callback)
  if not receiver then
    -- disconnect everything
    for i in pairs(signal) do signal[i] = nil end
  else
    if not callback then
      -- disconnect all members
      signal[receiver] = nil
      -- disconnect one function
      if _is_callable(receiver) then
        array.filter(signal, function(v) if v ~= receiver then return v end end)
      end
    elseif signal[receiver] then
      -- disconnect one member
      array.filter(signal[receiver], function(v) if v ~= callback then return v end end)
    end
  end
end
function Component:disconnect(signal, receiver, callback)
  if signal == "*" then
    for _,v in pairs(self.signals) do _disconnect(v, receiver, callback) end
  else
    local s = self.signals[signal]
    assert(s, string.format(_error_nosignal, signal))
    _disconnect(s, receiver, callback)
  end
end

function Component:emit(signal, ...)
  for i,v in pairs(self.signals[signal]) do
    if type(i) == "table" then
      for _,cb in ipairs(v) do
        i[cb](i, ...)
      end
    else
        v(...)
    end
  end
end


function Component:get(name)
  local p = self.properties[name]
  local v = p and p[1]
  return type(v) == "table" and v:get() or v
end
Component.__index = Component.get

local function _set(self, property, name, value)
  property[1] = value
  _notify_change(self, name, value)
end

function Component:_set(name, value)
  if prototype.isPrototype(value) then value = value(self, name) end
  _set(self, self.properties[name], name, value)
end

function Component:set(name, value)
  local p = self.properties[name]
  assert(p, string.format(_error_noprop, name))
  assert(not p.read_only, string.format(_error_rdonly, name))

  -- if value type is complex, try assigning directly
  local v = p[1]
  if type(v) == "table" and v:set(value) then return end

  if prototype.isPrototype(value) then value = value(self, name) end
  v = type(value) == "table" and value:get() or value

  -- if value type is basic or would change: check matcher
  assert(p.matcher(v), string.format(_error_wrong_type,
    tostring(value), name, tostring(p.matcher)))

  _set(self, p, name, value)
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
