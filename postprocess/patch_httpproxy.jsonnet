local com = import 'lib/commodore.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = com.inventory();
local params = inv.parameters.paralus;

local manifests_dir = std.extVar('output_path');

local fixupHTTPProxyConsole(obj) =
  std.prune(obj) {
    spec+: {
      routes: [
        if r.services[0].name == 'paralus' then
          r {
            loadBalancerPolicy: params.httpProxyParalus.loadBalancerPolicy,
          }
        else
          r
        for r in super.routes
      ],
    },
  };

local fixupManifests(obj) =
  if obj.kind == 'HTTPProxy' && obj.metadata.name == 'console' then
    fixupHTTPProxyConsole(obj)
  else
    obj;

com.fixupDir(manifests_dir, fixupManifests)
