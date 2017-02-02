local Matcher = {}

-- setup lua globals
local safeMethods = {}
for v in string.gmatch([[
  string table utf8 math
  getmetatable ipairs next pairs
  rawequal rawget rawlen
  tonumber tostring type
]], "%S+") do
  safeMethods["_" .. v] = _G[v]
end

local rules = setmetatable({}, { __index = safeMethods })

local _create_function
if _VERSION == "Lua 5.1" then
  _create_function = function(m)
    return setfenv(assert(loadstring("return " .. m)), rules)()
  end
else -- Lua 5.2 or higher
  _create_function = function(m)
    return assert(load("return " .. m, "matcher", "bt", rules))()
  end
end

-- Matchers for prototypable values need to recognize and match prototypes
function Matcher.addRule(name, fn, ruleType)
  ruleType = ruleType or "list"
  assert(not rules[name],
    string.format("A rule with the name %s already exists.", name))

  if ruleType == "basic" then
    rules[name] = fn
    return
  end

  local mt = { __call = fn }

  if ruleType == "list" then
    rules[name] = function(tbl)
      return setmetatable(tbl, mt)
    end
  elseif ruleType == "set" then
    rules[name] = function(tbl)
      local result = {}
      for i = 1, #tbl do result[tbl[i]] = true end
      return setmetatable(result, mt)
    end
  end
end

rules._  = function() return true  end
rules.__ = function() return false end
Matcher.addRule("all", function(self, v)
  for i = 1, #self do if not self[i](v) then return false end end
  return true
end)
Matcher.addRule("any", function(self, v)
  for i = 1, #self do if self[i](v) then return true end end
  return false
end)
Matcher.addRule("may", function(self, v)
  return type(v) == "nil" or self[1](v)
end)

for _,t in ipairs {
  "number", "string", "boolean", "table", "function", "thread", "userdata"
} do Matcher.addRule(t, function(v) return type(v) == t end, "basic") end

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
