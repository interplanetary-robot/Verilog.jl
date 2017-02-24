
function Base.:~(w::Wire)
  #if any of them are undefined we have a problem.
  assigned(w) || throw(UnassignedError())
  Wire(~w.values)
end

macro sidescheck()
  esc(quote
    assigned(lhs) || throw(UnassignedError())
    assigned(rhs) || throw(UnassignedError())
    length(lhs) == length(rhs) || throw(SizeMismatchError())
  end)
end


function Base.:&(lhs::Wire, rhs::Wire)
  @sidescheck
  Wire(lhs.values & rhs.values)
end

function Base.:|{N}(lhs::Wire{N}, rhs::Wire{N})
  @sidescheck
  Wire(lhs.values | rhs.values)
end

function Base.:^{N}(lhs::Wire{N}, rhs::Wire{N})
  @sidescheck
  Wire(lhs.values $ rhs.values)
end

#unary operators
function Base.:&{N}(tgt::Wire{N})
  assigned(tgt) || throw(UnassignedError())
  Wire((&)(tgt.values...))
end

function Base.:|{N}(tgt::Wire{N})
  assigned(tgt) || throw(UnassignedError())
  Wire((|)(tgt.values...))
end

function Base.:^{N}(tgt::Wire{N})
  assigned(tgt) || throw(UnassignedError())
  Wire(($)(tgt.values...))
end

#negated operators
and(x) = (&)(x)
or(x) = (|)(x)
xor(x) = (^)(x)
nand(x) = ~((&)(x))
nor(x)  = ~((|)(x))
xnor(x) = ~((^)(x))
nand(x,y) = ~((&)(x,y))
nor(x,y)  = ~((|)(x,y))
xnor(x,y) = ~((^)(x,y))
Base.:~(::typeof(&)) = nand
Base.:~(::typeof(|)) = nor
Base.:~(::typeof(^)) = xnor

function xorxnor(w::Wire)
  assigned(w) || throw(UnassignedError())
  Wire([(^)(w), (~^)(w)])
end

export xorxnor, and, or, nand, nor, xnor
