local com = import 'lib/commodore.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local inv = com.inventory();
local params = inv.parameters.paralus;

local manifests_dir = std.extVar('output_path');

local dashboard_nginx_configmap = kube.ConfigMap('dashboard-nginx-config') {
  data: {
    // contents copied from https://github.com/paralus/dashboard/blob/main/deploy/nginx.conf
    'nginx.conf': |||
      server {
        listen %(dashboard_container_port)d;

        location / {
          root /usr/share/nginx/html;
          index index.html index.htm;
          try_files $uri $uri/ /index.html;
        }
      }
    ||| % params,
  },
};

local fixupDashboardDeploy(obj) =
  obj {
    spec+: {
      template+: {
        spec+: {
          containers: [
            if c.name == 'dashboard' then
              c {
                ports: [
                  if p.name == 'nginx' then
                    p {
                      containerPort: params.dashboard_container_port,
                    }
                  else
                    p
                  for p in super.ports
                ],
                volumeMounts: [
                  {
                    mountPath: '/var/cache/nginx',
                    name: 'cache',
                  },
                  {
                    mountPath: '/var/run',
                    name: 'varrun',
                  },
                  {
                    mountPath: '/etc/nginx/conf.d/default.conf',
                    name: 'nginx-config',
                    subPath: 'nginx.conf',
                  },
                ],
              }
            else
              c
            for c in super.containers
          ],
          volumes: [
            {
              name: 'cache',
              emptyDir: {},
            },
            {
              name: 'varrun',
              emptyDir: {},
            },
            {
              name: 'nginx-config',
              configMap: {
                name: dashboard_nginx_configmap.metadata.name,
              },
            },
          ],
        },
      },
    },
  };

local fixupBusyboxImage(obj) =
  local fixupContainer(c) =
    if c.image == 'busybox:latest' then
      c {
        image: '%(registry)s/%(repository)s:%(tag)s' % params.images.busybox,
      }
    else
      c;

  obj {
    spec+: {
      template+: {
        spec+: {
          containers: [
            fixupContainer(c)
            for c in super.containers
          ],
          initContainers: [
            fixupContainer(c)
            for c in super.initContainers
          ],
        },
      },
    },
  };

local fixupManifests(obj) =
  if obj.kind == 'Deployment' && obj.metadata.name == 'dashboard' then
    fixupDashboardDeploy(obj)
  else if
    obj.kind == 'Deployment' &&
    std.member([ 'paralus', 'prompt' ], obj.metadata.name)
  then
    fixupBusyboxImage(obj)
  else
    obj;

com.fixupDir(manifests_dir, fixupManifests) + {
  'dashboard-nginx-configmap': dashboard_nginx_configmap,
}
