#creates an appendage that enables verilog-style range semantics.

type v
  value::Integer
end

function Base.:*(i::Integer, ::Type{v}); v(i); end

function Base.colon(i::Integer, vv::v)
  if vv.value < i
    return vv.value:i
  elseif vv.value == i
    return i:i
  else
    return i:-1:vv.value
  end
end

export v

#because verilog often uses zero-indexing, a python-style range() operator
#is helpful for creating for loop generators.

Base.range(i::Integer) = 0:(i-1)
