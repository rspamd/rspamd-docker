## Example kubernetes manifests for Rspamd

### Usage

* Install [Tanka](https://tanka.dev/install) and `jb`
* Install dependencies with `jb install`
* Edit tunables in `environments/default/rspamd-config.libsonnet` as desired (refer to `default/rspamd-config.libsonnet`)
* Populate Rspamd configuration in `environments/default/config` directory as desired
* Import whatever files you populate there in `environments/default/rspamd-config.libsonnet`
* Edit `environments/default/spec.json` as appropriate for your install target
* Further customisations can be applied in `environments/default/main.jsonnet`
* Deploy with `tk apply environments/default`
