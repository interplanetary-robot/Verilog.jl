
function Base.:~{R}(w::Wire{R})
  #if any of them are undefined we have a problem.
  unks = unknown_check(w)
  Wire{R}(~w.values, unks)
end

function Base.:&{R}(lhs::Wire{R}, rhs::Wire{R})
  unks = unknown_check(lhs, rhs)
  mask = (~lhs.values & lhs.assigned) | (~rhs.values & rhs.assigned)
  Wire{R}(lhs.values & rhs.values, unks | mask)
end

function Base.:|{R}(lhs::Wire{R}, rhs::Wire{R})
  unks = unknown_check(lhs, rhs)
  mask = (lhs.values & lhs.assigned) | (rhs.values & rhs.assigned)
  Wire{R}(lhs.values | rhs.values, unks | mask)
end

function Base.:^{R}(lhs::Wire{R}, rhs::Wire{R})
  unks = unknown_check(lhs, rhs)
  Wire{R}(lhs.values $ rhs.values, unks)
end

#unary operators
function Base.:&{R}(tgt::Wire{R})
  res = (&)(tgt.values...)
  unks = unknown_check(tgt)
  Wire{R}((&)(tgt.values...), &(unks) | !res)
end

function Base.:|{R}(tgt::Wire{R})
  res = (|)(tgt.values...)
  unks = unknown_check(tgt)
  Wire{R}(res, &(unks) | res)
end

function Base.:^{R}(tgt::Wire{R})
  unks = unknown_check(tgt)
  Wire{R}(($)(tgt.values...), &(unks))
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
