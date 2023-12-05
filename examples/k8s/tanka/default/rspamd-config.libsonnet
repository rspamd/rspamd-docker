{
  // configmaps for user's rspamd configuration files
  configmaps: {
    root: {},
    locald: {},
    overrided: {},
  },
  // should we create our namespace
  create_namespace: true,
  // name for dbdir volume
  dbdir_name: 'rspamd-dbdir',
  // size limit for dbdir
  dbdir_size: '1Gi',
  // create a pvc for dbdir (recommended)
  enable_pvc: false,
  // create a service
  enable_service: true,
  // name of the rspamd image
  image_name: 'rspamd/rspamd',
  // rspamd image pull policy
  image_pull_policy: 'Always',
  // rspamd image version
  image_tag: 'latest',
  // name used for various bits
  name: 'rspamd',
  // number of replicas in deployment
  replicas: 1,
  // name of service account, set to empty string for default
  service_account: 'rspamd',
  // name of storage class for pvc
  storageclass: 'longhorn',
}
