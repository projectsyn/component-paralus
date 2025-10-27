local com = import 'lib/commodore.libjsonnet';
local inv = com.inventory();
local instance = inv.parameters._instance;
local manifests_dir = std.extVar('output_path');

local stripCRDs(obj) =
  if instance == 'paralus-test' then
    if obj.kind == 'CustomResourceDefinition' then
      null
    else
      obj
  else
    obj;

com.fixupDir(manifests_dir, stripCRDs)
