local com = import 'lib/commodore.libjsonnet';
local inv = com.inventory();
local params = inv.parameters.paralus;
local manifests_dir = std.extVar('output_path');

local install_crds = params.install_crds;

local stripCRDs(obj) =
  if install_crds then
    obj
  else
    if obj.kind == 'CustomResourceDefinition' then
      { apiVersion: 'v1', kind: 'List', items: [] }
    else
      obj;

com.fixupDir(manifests_dir, stripCRDs)
