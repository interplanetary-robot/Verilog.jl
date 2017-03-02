doc"""
  Verilog.verilator_adapter(id)

  creates the required C file for verilation.
"""
function verilator_adapter(ident)
  modname = __global_definition_cache[ident].module_name
  """
#include <verilated.h>
#include <iostream>
#include "V$(modname).h"

V$(modname) *$(modname);
vluint64_t main_time = 0;

extern "C" void init(){
  $(modname) = new V$(modname);
}

extern "C" void step(){
  $(modname)->eval();
}

extern "C" void finish(){
  $(modname)->final();
  delete $(modname);
}

$(verilator_setter(ident))

$(verilator_getter(ident))
"""
end

function verilator_setter(ident)
  inputs = __global_definition_cache[ident].inputs
  modname = __global_definition_cache[ident].module_name
  ilist   = join(["unsigned long long $inp" for inp in inputs], ",")
  setters = join(["  $(modname)->$(inp) = $inp;" for inp in inputs], "\n")
  """
extern "C" void set($ilist){
$setters
}
"""
end

function verilator_getter(ident)
  output = __global_definition_cache[ident].output
  modname = __global_definition_cache[ident].module_name
"""
extern "C" unsigned long long get(){
  return $(modname)->$(output);
}
"""
end
