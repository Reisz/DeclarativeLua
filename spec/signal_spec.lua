local Component = require "Component"

describe("Component signals", function()
  it("should provide basic connect functionality", function()
    local c = Component { Component.signal("test") }()
    local s = spy.new(function() end)
    c:connect("test", function() s() end)
    c:emit("test")
    assert.spy(s).was_called(1)
  end)

  it("should be able to connect to callable tables", function()
    local c = Component { Component.signal("test") }()
    local s = spy.new(function() end)
    c:connect("test", s)
    c:emit("test")
    assert.spy(s).was_called(1)
  end)

  it("should be able to connect to member functions", function()
    local c = Component { Component.signal("test") }()
    local s = spy.new(function() end)
    local o = { f = function(...) s(...) end }
    c:connect("test", o, "f")
    c:emit("test", "123")
    assert.spy(s).was_called(1)
    assert.spy(s).was_called_with(o, "123")
  end)

  it("should be able to connect to member callables", function()
    local c = Component { Component.signal("test") }()
    local s = spy.new(function() end)
    local o = { f = s }
    c:connect("test", o, "f")
    c:emit("test", "123")
    assert.spy(s).was_called(1)
    assert.spy(s).was_called_with(o, "123")
  end)

  it("should be able to pass parameters in emit", function()
    local c = Component { Component.signal("test") }()
    local s = spy.new(function() end)
    c:connect("test", s)
    c:emit("test", "123")
    assert.spy(s).was_called(1)
    assert.spy(s).was_called_with("123")
  end)

  it("should automatically add signals for properties", function()
    local c = Component{ x = Component.property(1) }()
    local s = spy.new(function() end)
    c:connect("xChanged", s)
    c.x = 2
    assert.spy(s).was_called(1)
  end)

  it("should have a default onCompleted", function()
    local s = spy.new(function() end)
    Component{ onCompleted = function() s() end }()
    assert.spy(s).was_called(1)
  end)

  it("should let listeners be garbage collected", function()
    local c = Component{x = Component.property(1) }()

    local s = spy.new(function() end)
    local tbl = { s = function() s() end }
    c:connect("xChanged", tbl, "s")

    c.x = 2
    -- luacheck: push ignore tbl
    tbl = nil
    -- luacheck: pop
    collectgarbage()
    c.x = 3

    assert.spy(s).was_called(1)
  end)

  it("should be able to immediately add listeners to dynamic properties", function()
    local s = spy.new(function() end)
    local c = Component{ onTest = s, Component.signal("test") }()
    c:emit("test")
    assert.spy(s).was_called(1)
  end)

  it("should be able to assign listeners using on... syntax", function()
    local c = Component { Component.signal("test") }()
    local s = spy.new(function() end)
    c.onTest = s
    c:emit("test")
    assert.spy(s).was_called(1)
  end)

  it("should be able to combine listeners when reprototyping", function()
    local s1, s2, s3 = spy.new(function() end), spy.new(function() end), spy.new(function() end)

    Component{ onCompleted = s1 }{ onCompleted = s2 }()
    assert.spy(s1).was_called(1)
    assert.spy(s2).was_called(1)
    assert.spy(s3).was_called(0)

    Component{ onCompleted = { s1, s2 } }{ onCompleted = s3 }()
    assert.spy(s1).was_called(2)
    assert.spy(s2).was_called(2)
    assert.spy(s3).was_called(1)

    Component{ onCompleted = s1 }{ onCompleted = { s2, s3 } }()
    assert.spy(s1).was_called(3)
    assert.spy(s2).was_called(3)
    assert.spy(s3).was_called(2)

    Component{}{ onCompleted = s3 }()
    assert.spy(s1).was_called(3)
    assert.spy(s2).was_called(3)
    assert.spy(s3).was_called(3)

    Component{}{ onCompleted = { s1, s2, s3 } }()
    assert.spy(s1).was_called(4)
    assert.spy(s2).was_called(4)
    assert.spy(s3).was_called(4)

    Component{ onCompleted = { s1, s2, s3 } }{}()
    assert.spy(s1).was_called(5)
    assert.spy(s2).was_called(5)
    assert.spy(s3).was_called(5)

    Component{ onCompleted = s3 }{}()
    assert.spy(s1).was_called(5)
    assert.spy(s2).was_called(5)
    assert.spy(s3).was_called(6)
  end)

  it("should be able to add new static signals", function()
    local Subclass = Component:subclass("Subclass")
    Subclass:staticSignal("test")
    local s = spy.new(function() end)
    local c = Subclass { onTest = s }()
    c:emit("test")
    assert.spy(s).was_called(1)
  end)

  it("should be able to assign to static signals from superclasses", function()
    local Subclass = Component:subclass("Subclass")
    local s = spy.new(function() end)
    Subclass { onCompleted = s }()
    assert.spy(s).was_called(1)
  end)

  it("should be able to disconnect functions", function()
    local c = Component{ Component.signal("test") }
    local s = spy.new(function() end)
    local f = function() s() end
    c:connect("test", f)
    c:emit("test")
    c:disconnect("test", f)
    c:emit("test")
    assert.spy(s).was_called(1)
  end)

  it("should be able to disconnect callables", function()
    local c = Component{ Component.signal("test") }
    local s = spy.new(function() end)
    c:connect("test", s)
    c:emit("test")
    c:disconnect("test", s)
    c:emit("test")
    assert.spy(s).was_called(1)
  end)

  it("should be able to disconnect member functions", function()
    local c = Component{ Component.signal("test") }
    local s = spy.new(function() end)
    local o = { f = function() s() end }
    c:connect("test", o, "f")
    c:emit("test")
    c:disconnect("test", o)
    c:emit("test")
    assert.spy(s).was_called(1)
  end)

  it("should be able to disconnect member callables", function()
    local c = Component{ Component.signal("test") }
    local s = spy.new(function() end)
    local o = { f = s }
    c:connect("test", o, "f")
    c:emit("test")
    c:disconnect("test", o)
    c:emit("test")
    assert.spy(s).was_called(1)
  end)

  it("should be able to disconnect members of callables", function()
    local c = Component{ Component.signal("test") }
    local s1, s2 = spy.new(function() end), spy.new(function() end)
    local o = setmetatable({ f = s1 }, { __call = function() s2() end })
    c:connect("test", o, "f")
    c:emit("test")
    c:disconnect("test", o)
    c:emit("test")
    assert.spy(s1).was_called(1)
    assert.spy(s2).was_called(0)
  end)

  it("should fail when assigning signals incorrectly", function()
    assert.has_error(function() Component { onTest = function() end } end)
    assert.has_error(function() Component { onCompleted = 1 } end)
    assert.has_error(function() Component { onCompleted = { [2] = function() end } } end)
    assert.has_error(function() Component { onCompleted = { a = function() end } } end)
    assert.has_error(function() Component { onCompleted = { 1 } } end)
    assert.has_error(function() Component { onCompleted = {} } end)
  end)

  it("should fail when creating signals incorrectly", function()
    assert.has_error(function() Component { Component.signal(1) } end)
    assert.has_error(function() Component { Component.signal("A") } end)
    assert.has_error(function() Component:subclass(""):staticSignal(1) end)
    assert.has_error(function() Component:subclass(""):staticSignal("A") end)
  end)

  it("should fail when calling connect incorrectly", function()
    assert.has_error(function() Component{}():connect("test", function() end) end)
    -- connect is not type-checked for performance reasons
  end)

  -- TODO error on disconnect
  -- TODO disconnect member funcitons
end)
