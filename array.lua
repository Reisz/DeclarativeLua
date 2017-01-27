--- Functions for the array part of tables.
-- @usage
-- function flatten(tbl)
--   return array.reduce(tbl, function(a,v)
--     if type(v) == "table" then
--       return array.join(a, flatten(v))
--     else
--       return array.append(a, v)
--     end
--   end, {})
-- end

local array = {}

--- Filter an array using a function.
-- Traverse the array while removing or changing elements depending on the value
-- that was returned by the passed filter callback. This method will read each
-- index exactly once.
--
-- @{array.filter} will make shure to shift all remaining elements into possibly
-- freed spaces, so no additional holes will be created.
--
-- To execute a function on each element without changing the structure of the
-- array, neither @{array.map} nor @{array.forEach} include code to fix holes
-- during traversal, wich will increase execution speed for those cases.
-- @tparam table tbl The array to be filtered.
-- @tparam function callback Function to execute for each element in the array.
--
-- Will take three parameters:
--
-- **value**
--> The current element being processed in the array.
--
-- **index**
--> The index of the current element being processed in the array.
--
-- **tbl**
--> The array `filter` was called upon.
--
-- Return the original value to keep the entry, a new value to change the
-- entry, or `nil` to remove the entry from the array.
-- @return `tbl`
function array.filter(tbl, callback)
  local offset = 0

  for index = 1, #tbl do
    local oldVal = tbl[index]
    local value = callback(oldVal, index, tbl)
    if type(value) == "nil" then
      tbl[index] = nil
      offset = offset + 1
    elseif offset > 0 then
      tbl[index] = nil
      tbl[index - offset] = value
    elseif oldVal ~= value then
      tbl[index] = value
    end
  end

  return tbl
end

--- Execute a function on each element of an array.
-- This funtion will execute a function on each element of an array, without
-- modifiying its content. This is the fastest of the traversal functions and
-- will read each index exactly once.
--
-- To modify the contents of an array without removing elements, see
-- @{array.map}. To be able remove and modify elements of an array, use
-- @{array.filter}.
-- @tparam table tbl The array to be traversed.
-- @tparam function callback Function to execute for each element in the array.
--
-- Will take three parameters:
--
-- **value**
--> The current element being processed in the array.
--
-- **index**
--> The index of the current element being processed in the array.
--
-- **tbl**
--> The array `forEach` was called upon.
--
-- Return values are ignored.
-- @return `tbl`
function array.forEach(tbl, callback)
  for index = 1, #tbl do
    callback(tbl[index], index, tbl)
  end

  return tbl
end

--- Apply a function to each element of an array.
-- Traverse an array while changing the value of the element depending on the
-- value that was returned by the passed map callback. This method will read
-- each index exactly once.
--
-- Be careful when returning `nil` in the callback function, as this behaviour
-- will introduce holes in your array. To be able to pass `nil` in order to
-- signal removal, use @{array.filter} instead.
--
-- To simply execute a function without changing the content of the array,
-- @{array.forEach} will be sligtly faster.
-- @tparam table tbl The array to be mapped.
-- @tparam function callback Function to execute for each element in the array.
--
-- Will take three parameters:
--
-- **value**
--> The current element being processed in the array.
--
-- **index**
--> The index of the current element being processed in the array.
--
-- **tbl**
--> The array `map` was called upon.
--
-- Return values are written back to the array. See the main description about
-- returning `nil` from the callback.
-- @return `tbl`
function array.map(tbl, callback)
  for index = 1, #tbl do
    tbl[index] = callback(tbl[index], index, tbl)
  end

  return tbl
end

--- Apply a function against an accumulator and each element of an array from
-- lowest to highest index.
-- @tparam table tbl The array to be reduced.
-- @tparam function callback Function to execute for each element in the array.
--
-- Will take four parameters:
--
-- **accumulator**
--> Initial value or value last returned by callback.
--
-- **value**
--> The current element being processed in the array.
--
-- **index**
--> The index of the current element being processed in the array.
--
-- **tbl**
--> The array `map` was called upon.
--
-- The return value is stored in an accumulator for the next invocation of
-- `callback`.
-- @param[opt] init Initial value for the accumulator. If omitted, the
-- accumulator will be set to the value of the first array entry and the first
-- call to `callback` will be skipped.
-- @return The accumulator value returned by the last call to `callback`.
function array.reduce(tbl, callback, init)
  local start, accumulator
  if type(init) ~= "nil" then
    start, accumulator = 1, init
  else
    start, accumulator = 2, tbl[1]
  end

  for index = start, #tbl do
    accumulator = callback(accumulator, tbl[index], index, tbl)
  end

  return accumulator
end

--- Apply a function against an accumulator and each element of an array from
-- highest to lowest index.
-- @tparam table tbl The array to be reduced.
-- @tparam function callback Function to execute for each element in the array.
--
-- Will take four parameters:
--
-- **accumulator**
--> Initial value or value last returned by callback.
--
-- **value**
--> The current element being processed in the array.
--
-- **index**
--> The index of the current element being processed in the array.
--
-- **tbl**
--> The array `map` was called upon.
--
-- The return value is stored in an accumulator for the next invocation of
-- `callback`.
-- @param[opt] init Initial value for the accumulator. If omitted, the
-- accumulator will be set to the value of the last array entry and the first
-- call to `callback` will be skipped.
-- @return The accumulator value returned by the last call to `callback`.
function array.reduceRight(tbl, callback, init)
  local start, accumulator = #tbl
  if type(init) ~= "nil" then
    accumulator = init
  else
    start, accumulator = start - 1, tbl[start]
  end

  for index = start, 1, -1 do
    accumulator = callback(accumulator, tbl[index], index, tbl)
  end

  return accumulator
end

--- Join multiple arrays into a single big array.
-- This will add all the elements of second table onwards to the end of the
-- first array.
--
-- As this function will mutate its first argument, a call like
-- `array.join(a, a, a)` will not behave as expected. If the first argument
-- appears again anywhere but in the second argument, consider calling this
-- function as `a = array.join({}, a, a, a)`.
-- @tparam table tbl The array to be written to.
-- @tparam[opt] table ... The arrays to append to the end of tbl.
-- @return `tbl`
function array.join(tbl, ...)
  local last = #tbl

  for i = 1, select('#', ...) do
    local other = select(i, ...)
    local length = #other

    for index = 1, length do
      tbl[last + index] = other[index]
    end

    last = last + length
  end

  return tbl
end

--- Append multiple elements to the end of an array.
-- Ths will append each of its argument from the second onward to the end of the
-- array passed as the first argument.
-- @tparam table tbl The array to be written to.
-- @param[opt] ... The elements to be added to the end of `tbl`.
-- @return `tbl`
function array.append(tbl, ...)
  local last = #tbl

  for index = 1, select('#', ...) do
    tbl[last + index] = select(index, ...)
  end

  return tbl
end

function array.clear(tbl)
  for index = 1, #tbl do
    tbl[index] = nil
  end

  return tbl
end

return array
