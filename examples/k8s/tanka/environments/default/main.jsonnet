local k = import 'github.com/grafana/jsonnet-libs/ksonnet-util/kausal.libsonnet';
local rspamd = import 'rspamd.libsonnet';

rspamd
// make local modifications here; see also rspamd-config.libsonnet
/*
{
  rspamd+: {
    deployment+: {
      metadata+: {
        annotations+: {
          foo: 'bar',
        },
      },
    },
  },
}
*/
