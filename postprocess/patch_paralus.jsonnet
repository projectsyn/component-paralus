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

local fixupRunAsUser(obj) =
  obj {
    spec+: {
      template+: {
        spec+: {
          containers: [
            if c.name == 'relay-server' then
              c {
                securityContext: {
                  runAsUser: 0,
                },
              }
            else
              c
            for c in super.containers
          ],
        },
      },
    },
  };

local fixupFluentbitConfig(obj) =
  local dbAddr = params.helm_values.deploy.postgresql.address;
  local dbConn =
    local addrParts = std.split(dbAddr, ':');
    if std.length(addrParts) > 1 then
      { addr: addrParts[0], port: addrParts[1] }
    else
      { addr: addrParts[0], port: '5432' };

  obj {
    data+: {
      'fluent-bit.conf': std.strReplace(
        std.strReplace(
          obj.data['fluent-bit.conf'],
          'Port 5432',
          'Port %s' % dbConn.port,
        ),
        'Host %s' % dbAddr,
        'Host %s' % dbConn.addr,
      ),
    },
  };

local fixedDsn =
  if std.objectHas(params.helm_values.deploy.postgresql, 'dsn') then
    std.base64(params.helm_values.deploy.postgresql.dsn)
  else
    local args = std.join(
      '&',
      std.objectValues(std.mapWithKey(
        function(k, v) '%s=%s' % [ k, v ],
        params.db_args
      ))
    );
    local argStr = if std.length(args) > 0 then '?%s' % args else '';
    local dsn =
      'postgres://%(username)s:%(password)s@%(address)s/%(database)s%(args)s' %
      params.helm_values.deploy.postgresql {
        address:
          if std.length(std.findSubstr(':', super.address)) > 0 then
            super.address
          else
            '%s:5432' % super.address,
        args: argStr,
      };

    std.base64(dsn);

local fixupManifests(obj) =
  if obj.kind == 'Deployment' && obj.metadata.name == 'dashboard' then
    fixupDashboardDeploy(obj)
  else if
    obj.kind == 'Deployment' &&
    std.member([ 'paralus', 'prompt' ], obj.metadata.name)
  then
    fixupBusyboxImage(obj)
  else if
    obj.kind == 'Deployment' &&
    obj.metadata.name == 'relay-server'
  then
    fixupRunAsUser(obj)
  else if
    obj.kind == 'ConfigMap' &&
    obj.metadata.name == 'fluentbit-config'
  then
    fixupFluentbitConfig(obj)
  else if
    obj.kind == 'Secret' &&
    obj.metadata.name == 'paralus-db'
  then
    obj {
      data+: {
        DSN: fixedDsn,
      },
    }
  else if
    obj.kind == 'Secret' &&
    obj.metadata.name == 'kratos'
  then
    obj {
      data+: {
        dsn: fixedDsn,
      },
    }
  else
    obj;

com.fixupDir(manifests_dir, fixupManifests) + {
  'dashboard-nginx-configmap': dashboard_nginx_configmap,
}
