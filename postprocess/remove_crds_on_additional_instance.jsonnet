local com = import 'lib/commodore.libjsonnet';
local inv = com.inventory();
local instance = inv.parameters._instance;

local removeCrdsFilter(objs) =
  if instance == 'paralus-test' then
    std.filter(
      function(o)
        o.kind != 'CustomResourceDefinition',
      objs
    )
  else
    objs;

removeCrdsFilter
