local com = import 'lib/commodore.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = com.inventory();
local params = inv.parameters.paralus;

local manifests_dir = std.extVar('output_path');

// Only patch Kratos securityContext on OpenShift
local fixupKratosRunAsUser =
  if params.openshift_compatibility then {
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
  }
  else
    {};

local fixupBusyboxImage = {
  initContainers: [
    if c.image == 'busybox:latest' then
      c {
        image: '%(registry)s/%(repository)s:%(tag)s' % params.images.busybox,
      }
    else
      c
    for c in super.initContainers
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
          spec+:
            fixupKratosRunAsUser +
            fixupBusyboxImage,
        },
      },
    }
  else
    obj;

com.fixupDir(manifests_dir, fixupKratos)
