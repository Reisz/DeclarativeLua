local Component = require "Component"
local List = require "Component.List"

describe("Component List type", function()
  it("should assign to existing properties properly", function()
    local c = Component{ x = Component.property() }()
    c.x = List("a", "b")
    assert.are_equal("a", c.x[1])
    assert.are_equal("b", c.x[2])
  end)

  it("should assign to new dynamic properties properly", function()
    local c = Component{ x = Component.property(List("a", "b")) }()
    assert.are_equal("a", c.x[1])
    assert.are_equal("b", c.x[2])
  end)

  it("should assign to new static properties properly", function()
    local s = Component:subclass("s")
    s:staticProperty("x", List("a", "b"))
    local c = s{}()
    assert.are_equal("a", c.x[1])
    assert.are_equal("b", c.x[2])
  end)

  it("should provide a corresponding matcher", function()
    local c = Component{ x = Component.property(List("a", "b"), { matcher = "List{}" }) }
    assert.has_no_error(function() c = c() end)
    assert.has_no_error(function() c.x = List("a", "b") end)
    assert.has_error(function() c.x = 1 end)
  end)
end)