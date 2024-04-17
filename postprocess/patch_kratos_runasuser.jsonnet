local com = import 'lib/commodore.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = com.inventory();
local params = inv.parameters.paralus;

local manifests_dir = std.extVar('output_path');


local fixupKratosRunAsUser(podspec) =
  podspec {
    containers: [
      if std.get(std.get(c, 'securityContext', {}), 'runAsUser', null) != null then
        c {
          securityContext+: {
            runAsUser:: super.runAsUser,
          },
        }
      else
        c
      for c in super.containers
    ],
  };

local fixupKratos(obj) =
  if
    obj.kind == 'Deployment' && obj.metadata.name == 'ztka-kratos' ||
    obj.kind == 'StatefulSet' && obj.metadata.name == 'ztka-kratos-courier'
  then
    obj {
      spec+: {
        template+: {
          spec: fixupKratosRunAsUser(obj.spec.template.spec),
        },
      },
    }
  else
    obj;

com.fixupDir(manifests_dir, fixupKratos)
