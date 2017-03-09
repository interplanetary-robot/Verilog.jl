Base.:*(times::Integer, w::Wire) = Wire(repeat(w.values, outer=times))

function Base.:+{R,S}(lhs::Wire{R}, rhs::Wire{S})
  (length(R) == length(S)) || throw(SizeMismatchError())

  #for now, disallow bitvectors of length more than 64
  if (length(R) > 64)
    warn("currently > 64 bit wires not supported.")
    throw(SizeMismatchError())
  end

  #create a new uninitialized wire of the same length
  result = Wire{range(length(R))}(BitVector(length(R)), trues(length(R)))
  result.values.chunks[1] = lhs.values.chunks[1] + rhs.values.chunks[1]
  result
end

function Base.:-{R,S}(lhs::Wire{R}, rhs::Wire{S})
  (length(R) == length(S)) || throw(SizeMismatchError())

  #for now, disallow bitvectors of length more than 64
  if (length(R) > 64)
    warn("currently > 64 bit wires not supported.")
    throw(SizeMismatchError())
  end

  #create a new uninitialized wire of the same length
  result = Wire{range(length(R))}(BitVector(length(R)), trues(length(R)))
  result.values.chunks[1] = lhs.values.chunks[1] - rhs.values.chunks[1]
  result
end

function Base.:*{R,S}(lhs::Wire{R}, rhs::Wire{S})
  new_length = length(R) + length(S)

  if (length(R) + length(S) > 64)
    warn("current > 64 bit results not supported.")
    throw(SizeMismatchError())
  end

  result = Wire{range(new_length)}(BitVector(new_length), trues(new_length))
  result.values.chunks[1] = lhs.values.chunks[1] * rhs.values.chunks[1]
  result
end

function Base.:-{R}(tgt::Wire{R})
  #for now, disallow bitvectors of length more than 64
  if (length(R) > 64)
    warn("currently > 64 bit wires not supported.")
    throw(SizeMismatchError())
  end

  #create a new uninitialized wire of the same length
  result = Wire{range(length(R))}(BitVector(length(R)), trues(length(R)))
  result.values.chunks[1] = -tgt.values.chunks[1]
  result
end

function trimInt64(n::Integer)
  ~(-(one(UInt64) << n))
end

function Base.:<{R,S}(lhs::Wire{R}, rhs::Wire{S})
  (length(R) == length(S)) || throw(SizeMismatchError())
  if (length(R) > 64)
    warn("currently > 64 bit wires not supported.")
    throw(SizeMismatchError())
  end
  assigned(lhs) && assigned(rhs) || throw(UnassignedError())

  mask = trimInt64(length(R))

  result = Wire((lhs.values.chunks[1] & mask) < (rhs.values.chunks[1] & mask))
end

# >, <=, >= come for free.

function Base.:(==){R,S}(lhs::Wire{R}, rhs::Wire{S})
  (length(R) == length(S)) || throw(SizeMismatchError())
  if (length(R) > 64)
    warn("currently > 64 bit wires not supported.")
    throw(SizeMismatchError())
  end
  assigned(lhs) && assigned(rhs) || throw(UnassignedError())

  mask = trimInt64(length(R))

  result = Wire((lhs.values.chunks[1] & mask) == (rhs.values.chunks[1] & mask))
end

################################################################################
## shifters

function Base.:(<<){R,S}(lhs::Wire{R}, rhs::Wire{S})
  if (length(R) > 64)
    warn("currently > 64 bit wires not supported.")
    throw(SizeMismatchError())
  end
  if (length(S) > 64)
    warn("> 64 bit wires for shifter RHS not supported.")
    throw(SizeMismatchError())
  end
  assigned(lhs) && assigned(rhs) || throw(UnassignedError())
  result = Wire(lhs.values.chunks[1] << rhs.values.chunks[1], length(R))
end

function Base.:(>>){R,S}(lhs::Wire{R}, rhs::Wire{S})
  if (length(R) > 64)
    warn("currently > 64 bit wires not supported.")
    throw(SizeMismatchError())
  end
  if (length(S) > 64)
    warn("> 64 bit wires for shifter RHS not supported.")
    throw(SizeMismatchError())
  end
  assigned(lhs) && assigned(rhs) || throw(UnassignedError())
  result = Wire(lhs.values.chunks[1] >> rhs.values.chunks[1], length(R))
end

function Base.:(>>>){R,S}(lhs::Wire{R}, rhs::Wire{S})
  if (length(R) > 64)
    warn("currently > 64 bit wires not supported.")
    throw(SizeMismatchError())
  end
  if (length(S) > 64)
    warn("> 64 bit wires for shifter RHS not supported.")
    throw(SizeMismatchError())
  end
  assigned(lhs) && assigned(rhs) || throw(UnassignedError())

  #if the top value is true, then we'll have to spoof negativity.
  #the trimInt64() function can help, by masking those invisible values
  #as ones.
  if (lhs.values[end] == true)
    lhs.values.chunks[1] |= ~trimInt64(length(R))
  end

  result = Wire(lhs.values.chunks[1] >> rhs.values.chunks[1], length(R))
end
