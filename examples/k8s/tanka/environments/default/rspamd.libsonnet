local configData = import 'config.libsonnet';
local vars = import 'vars.libsonnet';

local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local configMap = k.core.v1.configMap;
local container = k.core.v1.container;
local deployment = k.apps.v1.deployment;
local namespace = k.core.v1.namespace;
local persistentVolumeClaim = k.core.v1.persistentVolumeClaim;
local service = k.core.v1.service;
local serviceAccount = k.core.v1.serviceAccount;

local configMapRoot = configMap.new('rspamd-config-root') + configMap.withData(configData.root);
local configMapLocal = configMap.new('rspamd-config-locald') + configMap.withData(configData.locald);
local configMapOverride = configMap.new('rspamd-config-overrided') + configMap.withData(configData.overrided);
local configHash = std.native('sha256')(std.manifestJson(configMapRoot) + std.manifestJson(configMapLocal) + std.manifestJson(configMapOverride));

local spec = std.native('parseJson')(importstr 'spec.json').spec;
local rspamdNamespace = namespace.new(spec.namespace);

local pvc = persistentVolumeClaim.new(vars.dbdir_name) +
            persistentVolumeClaim.mixin.spec.withAccessModes(['ReadWriteOncePod']) +
            persistentVolumeClaim.mixin.spec.withStorageClassName(vars.storageclass) +
            persistentVolumeClaim.mixin.spec.resources.withRequests({ storage: vars.dbdir_size });

local labels = {
  name: vars.name,
  namespace: spec.namespace,
};

local volumeMounts = [
  {
    name: 'config-root',
    mountPath: '/etc/rspamd',
  },
  {
    name: 'config-locald',
    mountPath: '/etc/rspamd/local.d',
  },
  {
    name: 'config-overrided',
    mountPath: '/etc/rspamd/override.d',
  },
  {
    name: 'dbdir',
    mountPath: '/var/lib/rspamd',
  },
];

local volumes = [
  {
    name: 'dbdir',
  } + (if vars.enable_pvc then
         { persistentVolumeClaim: { claimName: vars.dbdir_name } }
       else
         { emptyDir: { sizeLimit: vars.dbdir_size } }),
  {
    name: 'config-root',
    configMap: {
      name: 'rspamd-config-root',
    },
  },
  {
    name: 'config-locald',
    configMap: {
      name: 'rspamd-config-locald',
    },
  },
  {
    name: 'config-overrided',
    configMap: {
      name: 'rspamd-config-overrided',
    },
  },
];

local rspamdDeployment = deployment.new(
                           name=vars.name,
                           replicas=vars.replicas,
                           containers=[
                             container.new(
                               name=vars.name,
                               image=vars.image_name + ':' + vars.image_tag,
                             )
                             + container.withImagePullPolicy(vars.image_pull_policy)
                             + container.mixin.withPorts([
                               { containerPort: 11332, name: 'proxy' },
                               { containerPort: 11333, name: 'normal' },
                               { containerPort: 11334, name: 'controller' },
                             ])
                             + container.mixin.withVolumeMounts(volumeMounts),
                           ],
                         ) + deployment.mixin.spec.selector.withMatchLabels(labels)
                         + (if vars.service_account != '' then deployment.mixin.spec.template.spec.withServiceAccountName(vars.service_account) else {})
                         + deployment.mixin.spec.template.spec.withVolumes(volumes)
                         + deployment.metadata.withAnnotations({ 'checksum/config': configHash })
                         + deployment.mixin.spec.template.metadata.withLabels(labels);

local rspamdService = service.new(
  name=vars.name,
  selector=labels,
  ports=[
    {
      name: 'proxy',
      protocol: 'TCP',
      port: 11332,
      targetPort: 11332,
    },
    {
      name: 'normal',
      protocol: 'TCP',
      port: 11333,
      targetPort: 11333,
    },
    {
      name: 'controller',
      protocol: 'TCP',
      port: 11334,
      targetPort: 11334,
    },
  ],
);

{
  rspamd: {
            configmap_root: configMap.new('rspamd-config-root') + configMap.withData(configData.root),
            configmap_locald: configMap.new('rspamd-config-locald') + configMap.withData(configData.locald),
            configmap_overrided: configMap.new('rspamd-config-overrided') + configMap.withData(configData.overrided),
            deployment: rspamdDeployment,
          }
          + (if vars.create_namespace != '' then { namespace: rspamdNamespace } else {})
          + (if vars.service_account != '' then { service_account: serviceAccount.new(vars.service_account) } else {})
          + (if vars.enable_pvc then { pvc: pvc } else {})
          + (if vars.enable_service then { service: rspamdService } else {}),
}
