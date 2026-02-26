local com = import 'lib/commodore.libjsonnet';

local dir = std.extVar('output_path');
local inv = com.inventory();
local params = inv.parameters.paralus;

// fixupDir already drops `null` objects, so we can just give the identity
// function as the 2nd argument.

if !params.openshift_compatibility then
  com.fixupDir(dir, function(o) o)
else
  {}
