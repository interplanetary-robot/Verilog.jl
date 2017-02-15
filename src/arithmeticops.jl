Base.:*(times::Integer, w::Wire) = Wire(repeat(w.values, outer=times))
