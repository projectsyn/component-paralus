/*
* Deploys the Paralus PostgreSQL audit logs cleanup cronjob
*/
local common = import 'common.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.paralus.dbCronJob;
local com = import 'lib/commodore.libjsonnet';

local namespace = {
  metadata+: {
    namespace: inv.parameters.paralus.namespace,
  },
};

local cronJob = kube.CronJob('paralus-pgdb-log-cleanup-cronjob') + namespace {
  spec+: {
    schedule: params.schedule,
    failedJobsHistoryLimit: params.jobHistoryLimit.failed,
    successfulJobsHistoryLimit: params.jobHistoryLimit.successful,
    jobTemplate+: {
      spec+: {
        template+: {
          spec+: {
            nodeSelector: params.nodeSelector,
            restartPolicy: 'OnFailure',
            containers_+: {
              postgres_cleanup: kube.Container('postgres-cleanup') {
                image: params.image,
                args: [
                  "psql",
                  "-h", "$(DB_ADDR)",
                  "-U", "$(DB_USER)",
                  "-d", "$(DB_NAME)",
                  "-c", "DELETE FROM audit_logs WHERE time < NOW() - INTERVAL '%(retention)s days';" % params
                ],
                env: [
                  {
                    name: "PGPASSWORD",
                    valueFrom: {
                      secretKeyRef: {
                        name: "paralus-db",
                        key: "DB_PASSWORD"
                      }
                    }
                  },
                  {
                    name: "DB_ADDR",
                    valueFrom: {
                      secretKeyRef: {
                        name: "paralus-db",
                        key: "DB_ADDR"
                      }
                    }
                  },
                  {
                    name: "DB_USER",
                    valueFrom: {
                      secretKeyRef: {
                        name: "paralus-db",
                        key: "DB_USER"
                      }
                    }
                  },
                  {
                    name: "DB_NAME",
                    valueFrom: {
                      secretKeyRef: {
                        name: "paralus-db",
                        key: "DB_NAME"
                      }
                    }
                  }
                ] + params.extraEnv,
              },
            },
          },
        },
      },
    },
  },
};

[ cronJob ]
