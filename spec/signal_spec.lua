local Component = require "Component"

describe("Component signals", function()
  it("should automatically add signals for properties", function()
    local c = Component{ x = Component.property(1) }
    local s = spy.new(function() end)
    c:connect("xChanged", s)
    c.x = 2
    assert.spy(s).was.scalled()
  end)
  
  it("should let listeners be garbage collected", function()
    local c = Component{x = Component.property(1) }
    
    local s = spy.new(function() end)
    local tbl = { s = s }
    
    c:connect("xChanged", tbl, "s")
    c.x = 2
    
    tbl = nil
    collectgarbage()
    c.x = 3
    
    assert.spy(s).was.called(1)
  end)
end)