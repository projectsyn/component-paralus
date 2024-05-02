local com = import 'lib/commodore.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = com.inventory();
local params = inv.parameters.paralus;

local manifests_dir = std.extVar('output_path');

local fixupZtkaIngress(obj) =
  std.prune(obj) {
    metadata+: {
      annotations+: {
        'route.openshift.io/termination': 'passthrough',
      },
    },
    spec+: {
      rules: [
        r {
          http+: {
            paths: [
              super.paths[0] {
                path:: '',
                pathType: 'ImplementationSpecific',
              },
            ],
          },
        }
        for r in super.rules
      ],
    },
  };

local fixupManifests(obj) =
  if obj.kind == 'Ingress' && obj.metadata.name == 'ztka' then
    fixupZtkaIngress(obj)
  else
    obj;

if params.openshift_compatibility then
  com.fixupDir(manifests_dir, fixupManifests)
else
  {}
