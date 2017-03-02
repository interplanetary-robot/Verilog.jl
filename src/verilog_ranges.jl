#verilog-ranges.jl..
#creates ranges that help with making the julia verilog and the verilog much
#more interpretable.

doc"""
  v

  is an appendage that reverses the order of julia's ranges so that they have
  the cosmetic appearance of a verilog range.  This can be used both in setters
  and getters for wire collections.

  For example:
  `my_wire[5:0v]`  references a wire over indices 0-5
  `my_wire[6:2v]`  references a wire over indices 2-6

  For dereferencing (getting) you can reverse this:
  `my_wire[2:6v]`  references the wire over indices 2-6 with the msb order reversed.

  if you are using a variable, be sure to put the value in paretheses.

  For example:

  `my_wire[bits:(bits-4)v]`
"""
immutable v
  value
end

doc"""
  msb

  is a special keyword which indicates that the value should go to the most
  significant bit.  There is no equivalent "lsb", since in most cases this will
  be a fairly easy-to-reference value.  Plan your code accordingly.

  For example:
  my_wire[16:0v] = Wire(0xF000, 16)
  my_wire[msb:12]              # ==> Wire{3:0v}(0xF)

  my_wire_2[16:0v] = Wire(0x0F00, 16)
  my_wire[(msb-4):(msb-8)]     # ==> Wire{3:0v}(0xF)
"""
immutable msb;
  value::Integer
end

doc"""
  VerilogRange

  is a range object that represents a verilog range.  These are declared by
  using the v ranges, so 5:0v is a VerilogRange from 0 to 5.
"""
immutable VerilogRange <: AbstractUnitRange{Int64}
  start::Int64
  stop::Int64
end

doc"""
  RelativeRange

  is a range object that can take values which can be relative to the most
  significant bit.
"""
immutable RelativeRange
  start::Union{Int64, msb}
  stop::Union{Int64, msb}
end

function Base.:*(i, ::Type{v}); v(i); end
#allows

function Base.colon(i::Integer, vv::v)
  #first possibility, vv.value is actually the type msb.
  if vv.value == msb
    RelativeRange(msb(0), i)
  elseif isa(vv.value, msb)
    RelativeRange(vv.value, i)
  else
    VerilogRange(vv.value, i)
  end
end

function Base.colon(m::Union{Type{msb}, msb}, vv::v)
  left = (m == msb) ? msb(0) : m
  (vv.value == msb) ? RelativeRange(msb(0), left) : RelativeRange(vv.value, left)
end

function Base.:-(::Type{msb}, n::Integer)
  msb(n)
end

function parse_msb(rr::RelativeRange, vr::VerilogRange)
  true_start = isa(rr.start, msb) ? vr.stop - rr.start.value : rr.start
  true_stop  = isa(rr.stop, msb)  ? vr.stop - rr.stop.value  : rr.stop
  true_stop:(true_start)v
end

export v, msb

#because verilog often uses zero-indexing, a python-style range() operator
#is helpful for creating for loop generators.

Base.range(i::Integer) = (i-1):0v

#making a VerilogRange a well-defined iterable.
Base.start(v::VerilogRange) = v.start
Base.next(v::VerilogRange, state) = (state, state + ((v.stop >= v.start) ? 1 : - 1))
Base.done(v::VerilogRange, state) = state == v.stop + ((v.stop >= v.start) ? 1 : -1)
Base.eltype(v::VerilogRange) = Int64
Base.length(v::VerilogRange) = ((v.stop > v.start) ? (v.stop - v.start) : (v.start - v.stop)) + 1

Base.show(io::IO, v::VerilogRange) = print(io, v.stop, ":", v.start, "v")

function Base.reverse(r::VerilogRange)
  if r.start < r.stop
    r.stop:-1:r.start
  else
    r.stop:r.start
  end
end
