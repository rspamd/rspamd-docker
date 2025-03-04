local rspamd_config = import 'rspamd-config.libsonnet';

local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';

local configMap = k.core.v1.configMap;
local container = k.core.v1.container;
local deployment = k.apps.v1.deployment;
local namespace = k.core.v1.namespace;
local persistentVolumeClaim = k.core.v1.persistentVolumeClaim;
local service = k.core.v1.service;
local serviceAccount = k.core.v1.serviceAccount;

local configMapRoot = configMap.new('rspamd-config-root') + configMap.withData(rspamd_config.configmaps.root);
local configMapLocal = configMap.new('rspamd-config-locald') + configMap.withData(rspamd_config.configmaps.locald);
local configMapOverride = configMap.new('rspamd-config-overrided') + configMap.withData(rspamd_config.configmaps.overrided);
local configHash = std.native('sha256')(std.manifestJson(configMapRoot) + std.manifestJson(configMapLocal) + std.manifestJson(configMapOverride));

local tk = import 'tk';
local rspamdNamespace = namespace.new(tk.env.spec.namespace);

local pvc = persistentVolumeClaim.new(rspamd_config.dbdir_name) +
            persistentVolumeClaim.mixin.spec.withAccessModes(['ReadWriteOncePod']) +
            persistentVolumeClaim.mixin.spec.withStorageClassName(rspamd_config.storageclass) +
            persistentVolumeClaim.mixin.spec.resources.withRequests({ storage: rspamd_config.dbdir_size });

local labels = {
  name: rspamd_config.name,
  namespace: tk.env.spec.namespace,
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
  } + (if rspamd_config.enable_pvc then
         { persistentVolumeClaim: { claimName: rspamd_config.dbdir_name } }
       else
         { emptyDir: { sizeLimit: rspamd_config.dbdir_size } }),
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
                           name=rspamd_config.name,
                           replicas=rspamd_config.replicas,
                           containers=[
                             container.mixin.startupProbe.httpGet.withPath('/ping')
                             + container.mixin.startupProbe.httpGet.withPort(11333)
                             + container.mixin.startupProbe.withPeriodSeconds(10)
                             + container.mixin.startupProbe.withFailureThreshold(30)
                             + container.mixin.livenessProbe.httpGet.withPath('/ping')
                             + container.mixin.livenessProbe.httpGet.withPort(11333)
                             + container.mixin.livenessProbe.withFailureThreshold(3)
                             + container.new(
                               name=rspamd_config.name,
                               image=rspamd_config.image_name + ':' + rspamd_config.image_tag,
                             )
                             + container.mixin.withImagePullPolicy(rspamd_config.image_pull_policy)
                             + container.mixin.withPorts([
                               { containerPort: 11332, name: 'proxy' },
                               { containerPort: 11333, name: 'normal' },
                               { containerPort: 11334, name: 'controller' },
                             ])
                             + container.mixin.withVolumeMounts(volumeMounts),
                           ],
                         ) + deployment.mixin.spec.selector.withMatchLabels(labels)
                         + (if rspamd_config.service_account != '' then deployment.mixin.spec.template.spec.withServiceAccountName(rspamd_config.service_account) else {})
                         + deployment.mixin.spec.template.spec.withVolumes(volumes)
                         + deployment.metadata.withAnnotations({ 'checksum/config': configHash })
                         + deployment.mixin.spec.template.metadata.withLabels(labels);


local rspamdService = service.new(
  name=rspamd_config.name,
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
            configmap_root: configMapRoot,
            configmap_locald: configMapLocal,
            configmap_overrided: configMapOverride,
            deployment: rspamdDeployment,
          }
          + (if rspamd_config.create_namespace != '' then { namespace: rspamdNamespace } else {})
          + (if rspamd_config.service_account != '' then { service_account: serviceAccount.new(rspamd_config.service_account) } else {})
          + (if rspamd_config.enable_pvc then { pvc: pvc } else {})
          + (if rspamd_config.enable_service then { service: rspamdService } else {}),
}
