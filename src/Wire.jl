type UnassignedError   <: Exception; end
type AssignedError     <: Exception; end
type SizeMismatchError <: Exception; end


#wire.jl - defines the Wire type.  Wires are stored under the hood as bitvectors.
doc"""
  `Wire{R}`

  is the basic type for Verilog operations.  R specifies a "unit range" of integers.
  Use the "v" suffix to enable verilog-style ranging.

  Wire{3:0v} declares a four-digit verilog wire with indices spanning from 0->3;
  Wire{6:2v} declares a five-bit verilog wire with indices spanning from
  2->6.
"""

immutable Wire{R}
  values::BitVector
  assigned::BitVector

  function Wire(bv1, bv2)
    (R.start <= R.stop) || throw(TypeError(:Wire, "constructor range direction failed", UnitRange, "backwards"))
    (length(bv1) == length(bv2) == length(R)) || throw(SizeMismatchError())
    new(bv1, bv2)
  end
end

################################################################################
## Aliased naked constructors.

(::Type{Wire})(v::Bool)                = Wire{0:0}(BitVector([v]), trues(1))
(::Type{Wire})(N::Signed)              = Wire{0:(N-1)}(BitVector(N), falses(N))
(::Type{Wire})(R::UnitRange)           = Wire{R}(BitVector(length(R)), falses(length(R)))
(::Type{Wire})(bv::BitVector)          = Wire{0:(length(bv)-1)}(bv, trues(length(bv)))
#allow initialization of wire with an array, but remember to reverse it.
(::Type{Wire})(wa::Vector{Wire})       = Wire(vcat(map((w) -> w.values, reverse(wa))...))
(::Type{Wire}){N}(wa::Vector{Wire{N}}) = Wire(vcat(map((w) -> w.values, reverse(wa))...))
(::Type{Wire})(ws::Wire...)            = Wire(collect(Wire, ws))

#declaration with an unsigned integer
function (::Type{Wire})(N::Unsigned, l::Integer = 0)
  #override an unspecified length.
  l = (l == 0) ? sizeof(N) * 8 : l
  #mask out crap we don't want.
  Wire(N, range(l))
end
function (::Type{Wire})(N::Unsigned, r::UnitRange)
  Wire{r}(N)
end
function (::Type{Wire{R}}){R}(N::Unsigned)
  #instantiate a bitarray.
  l = length(R)
  ba = BitVector(length(R))

  N = (l < 64) ? (UInt64(N) & ((1 << l) - 1)) : UInt64(N)
  ba.chunks[1] = N
  #pass this to the bitarray-based constructor.
  Wire{R}(ba, trues(l))
end

type UnsignedBigInt <: Unsigned
  value::BitArray
end

################################################################################
# conversion away from wires - necessary for integer reintepretation of verilog
# wire definitons
function Base.convert{R}(::Type{Unsigned}, w::Wire{R})
  if length(R) <= 64
    return w.values.chunks[1]
  else
    return UnsignedBigInt(w.values)
  end
end

################################################################################

#useful helper functions
import Base: length, range

length{R}(w::Wire{R}) = length(R)
range{R}(w::Wire{R}) = R
assigned(w::Wire) = (&)(w.assigned...)

################################################################################
# getters and setters
import Base: getindex, setindex!

function getindex{R}(w::Wire{R}, n::Integer)
  (n in R) || throw(BoundsError(w, n))
  #adjust for array indexing.
  access_idx = n + 1 - R.start
  #gets the relevant index, if it's been defined.
  w.assigned[access_idx] || throw(UnassignedError())
  Wire(w.values[access_idx])
end

function getindex{R}(w::Wire{R}, r::UnitRange)
  #returns a wire with the relevant selected values.
  issubset(r, R) || throw(BoundsError(w, r))
  for idx in (r + 1 - R.start)
    w.assigned[idx] || throw(UnassignedError())
  end

  Wire(w.values[r + 1 - R.start])
end

function setindex!{R}(dst::Wire{R}, src::Wire{0:0}, n::Integer)
  (n in R) || throw(BoundsError(dst, n))
  offset_idx = n - R.start + 1

  #chcek that the src value exists.
  src.assigned[1] || throw(UnassignedError())
  dst.assigned[offset_idx] && throw(AssignedError())
  dst.assigned[offset_idx] = true
  dst.values[offset_idx] = src.values[1]
  nothing
end

function Base.setindex!{RD, RS}(dst::Wire{RD}, src::Wire{RS}, r::UnitRange)
  #check for size mismatch.
  (length(r) == length(RS)) || throw(SizeMismatchError())
  (issubset(r, RD)) || throw(BoundsError(dst, r))

  #the range offset to where they're actually stored in the destination array
  offset_range = r - RD.start + 1
  for idx in 1:length(r)
    dst.assigned[offset_range[idx]] && throw(AssignedError())
    src.assigned[idx]               || throw(UnassignedError())
  end

  for idx in 1:length(r)
    dst.assigned[offset_range[idx]] = true
    dst.values[offset_range[idx]]   = src.values[idx]
  end

  nothing
end


doc"""
  `@wire` binds a wire value to a certain size.
"""
macro wire(identifier, rangedescriptor)
  esc(quote
    #in the general case
    if isa($identifier, Integer)
      $identifier = Wire{$rangedescriptor}($identifier)
    elseif isa($identifier, Wire)
      $rangedescriptor == range($identifier) || throw(SizeMismatchError())
    end
  end)
end

#it's useful to declare a single wire shorthand
typealias SingleWire Wire{0:0}

export Wire, @wire, SingleWire
