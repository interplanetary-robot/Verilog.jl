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
  modname = __global_definition_cache[ident].module_name
  if length(__global_definition_cache[ident].outputlist) == 1
    #extract the output symbol for this module.
    oup = first(__global_definition_cache[ident].outputlist).first
    """
extern "C" unsigned long long get(){
  return $(modname)->$(oup);
}
    """
  else
    #in the case where the result is more complex, we'll have to output a
    #struct for each of output values, which will be encoded as a 64-bit integer.
    outputs = __global_definition_cache[ident].outputlist
    olist = join(["  unsigned long long $(oup.first);" for oup in outputs], "\n")
    getters = join(["  value->$(oup.first) = $(modname)->$(oup.first);" for oup in outputs], "\n")
    """
typedef struct{
$(olist)
} output_struct;

extern "C" void get(output_struct *value){
  $getters
}
    """
  end
end
