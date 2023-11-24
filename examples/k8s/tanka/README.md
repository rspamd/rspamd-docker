## Example kubernetes manifests for Rspamd

### Usage

* Install [Tanka](https://tanka.dev/install) and `jb`
* Install dependencies with `jb install`
* Edit tunables in `environments/default/vars.libsonnet` as desired
* Populate Rspamd configuration in `environments/default/config` directory as desired
* Import whatever files you populate there in `environments/default/config.libsonnet`
* Edit `environments/default/spec.json` as appropriate for your install target
* Deploy with `tk apply environments/default`
