
import Base.show

function show{R}(io::IO, w::Wire{R})
  show(io, typeof(w))
  print(io, "(0b")
  print(io, join([w.assigned[idx] ? (w.values[idx] ? "1" : "0") : "X" for idx = length(w):-1:1],""))
  print(io, ")")
end

function show{R}(io::IO, ::Type{Wire{R}})
  print(io, "Wire{",R.stop,":",R.start,"v}")
end
