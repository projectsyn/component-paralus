// main template for paralus
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();

// The hiera parameters for the component
local params = inv.parameters.paralus;

local namespace = kube.Namespace(params.namespace) {
  metadata+: {
    annotations+: {
      'openshift.io/node-selector': '',
    },
    labels+: {
      'app.kubernetes.io/name': params.namespace,
      'topolvm.cybozu.com/webhook': 'ignore',
      // Configure the namespaces so that the OCP4 cluster-monitoring
      // Prometheus can find the servicemonitors and rules.
      'openshift.io/cluster-monitoring': 'true',
    },
  },
};

local cronJob = kube.CronJob('paralus-pgdb-log-cleanup-cronjob') {
  metadata+: {
    namespace: inv.parameters.paralus.namespace,
  },
  spec+: {
    schedule: params.dbCronJob.schedule,
    failedJobsHistoryLimit: params.dbCronJob.jobHistoryLimit.failed,
    successfulJobsHistoryLimit: params.dbCronJob.jobHistoryLimit.successful,
    jobTemplate+: {
      spec+: {
        template+: {
          spec+: {
            restartPolicy: 'OnFailure',
            containers: [
              {
                name: 'postgres-cleanup',
                image: '%(registry)s/%(repository)s:%(tag)s' % params.images.dbCronJob,
                args: [
                  'psql',
                  '-h',
                  '$(DB_ADDR)',
                  '-U',
                  '$(DB_USER)',
                  '-d',
                  '$(DB_NAME)',
                  '-c',
                  "DELETE FROM audit_logs WHERE time < NOW() - INTERVAL '%d days';" % params.dbCronJob.retention,
                ],
                env: [
                  {
                    name: 'PGPASSWORD',
                    valueFrom: {
                      secretKeyRef: {
                        name: 'paralus-db',
                        key: 'DB_PASSWORD',
                      },
                    },
                  },
                  {
                    name: 'DB_ADDR',
                    valueFrom: {
                      secretKeyRef: {
                        name: 'paralus-db',
                        key: 'DB_ADDR',
                      },
                    },
                  },
                  {
                    name: 'DB_USER',
                    valueFrom: {
                      secretKeyRef: {
                        name: 'paralus-db',
                        key: 'DB_USER',
                      },
                    },
                  },
                  {
                    name: 'DB_NAME',
                    valueFrom: {
                      secretKeyRef: {
                        name: 'paralus-db',
                        key: 'DB_NAME',
                      },
                    },
                  },
                ],
              },
            ],
          },
        },
      },
    },
  },
};

{
  '10_namespace': namespace,
  '20_cronjob': cronJob,
}
