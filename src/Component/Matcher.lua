local Matcher = {}

-- setup lua globals
local safeMethods = {}
for v in string.gmatch([[
  string table utf8 math
  getmetatable ipairs next pairs
  rawequal rawget rawlen
  tonumber tostring type
]], "%S+") do
  safeMethods[v] = _G[v]
end

local rules = setmetatable({}, { __index = safeMethods })

local _create_function
if _VERSION == "Lua 5.1" then
  _create_function = function(m)
    local fn, msg = loadstring("return " .. m)
    if not fn then error(msg) end
    return setfenv(fn, rules)()
  end
else -- Lua 5.2 or higher
  _create_function = function(m)
    local fn, msg = load("return " .. m, "matcher", "bt", rules)
    if not fn then error(msg) end
    return fn()
  end
end

-- Matchers for prototypable values need to recognize and match prototypes
function Matcher.addRule(name, fn, ruleType)
  ruleType = ruleType or "call"
  assert(not rules[name]) -- TODO message

  if ruleType == "basic" then
    rules[name] = fn
  elseif ruleType == "call" then
    rules[name] = fn -- TODO
  elseif ruleType == "list" then
    rules[name] = fn -- TODO
  elseif ruleType == "set" then
    rules[name] = fn -- TODO
  end
end

-- TODO add standard rules

local matcherToken = {}
function Matcher.new(m)
  local f = _create_function(m)
  return setmetatable({}, {
    __call = function(_, ...) return f(...) end,
    __tostring = function() return m end,
    [matcherToken] = true
  })
end

function Matcher.isMatcher(m)
  return type(m) == "table" and (getmetatable(m) or matcherToken)[matcherToken]
end

return setmetatable(Matcher, { __call = function(_, ...) return Matcher.new(...) end })
