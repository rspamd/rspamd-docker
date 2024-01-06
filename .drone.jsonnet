local docker_defaults = {
  username: {
    from_secret: 'docker_username',
  },
  password: {
    from_secret: 'docker_password',
  },
};

local pipeline_defaults = {
  kind: 'pipeline',
  type: 'docker',
};

local trigger_on(what_event) = {
  trigger: {
    event: {
      include: [
        what_event,
      ],
    },
  },
};

local rspamd_image = 'rspamd/rspamd';

local image_tags(asan_tag, arch) = [
  std.format('image%s-%s-${DRONE_SEMVER_SHORT}-${DRONE_SEMVER_BUILD}', [asan_tag, arch]),
];

local pkg_tags(arch) = [
  std.format('pkg-%s-${DRONE_SEMVER_SHORT}-${DRONE_SEMVER_BUILD}', arch),
];

local architecture_specific_pipeline(arch, get_image_tags=image_tags, get_pkg_tags=pkg_tags, rspamd_git='${DRONE_SEMVER_SHORT}', rspamd_version='${DRONE_SEMVER_SHORT}', long_version='${DRONE_SEMVER_SHORT}-${DRONE_SEMVER_BUILD}') = {
  local step_default_settings = {
    platform: 'linux/' + arch,
    repo: rspamd_image,
  },
  local install_step(name, asan_tag) = {
    name: name,
    depends_on: [
      'pkg_' + arch,
    ],
    image: 'rspamd/drone-docker-plugin',
    privileged: true,
    settings: {
      local asan_build_tag = if std.length(asan_tag) != 0 then ['ASAN_TAG=' + asan_tag] else [],
      dockerfile: 'Dockerfile',
      build_args: [
        'PKG_TAG=' + get_pkg_tags(arch)[0],
        'TARGETARCH=' + arch,
      ] + asan_build_tag,
      squash: true,
      tags: get_image_tags(asan_tag, arch),
      target: 'install',
    } + step_default_settings + docker_defaults,
  },
  name: 'rspamd_' + arch,
  platform: {
    os: 'linux',
    arch: arch,
  },
  steps: [
    {
      name: 'pkg_' + arch,
      image: 'rspamd/drone-docker-plugin',
      privileged: true,
      settings: {
        dockerfile: 'Dockerfile.pkg',
        build_args: [
          'RSPAMD_GIT=' + rspamd_git,
          'RSPAMD_VERSION=' + rspamd_version,
          'TARGETARCH=' + arch,
        ],
        tags: get_pkg_tags(arch),
        target: 'pkg',
      } + step_default_settings + docker_defaults,
    },
    install_step('install_' + arch, ''),
    install_step('install_asan_' + arch, '-asan'),
  ],
} + trigger_on('tag') + pipeline_defaults;

local multiarch_pipeline = {
  name: 'rspamd_multiarch',
  depends_on: [
    'rspamd_amd64',
    'rspamd_arm64',
  ],
  local multiarch_step(step_name, asan_tag) = {
    name: step_name,
    image: 'plugins/manifest',
    settings: {
      target: std.format('%s:image%s-${DRONE_SEMVER_SHORT}-${DRONE_SEMVER_BUILD}', [rspamd_image, asan_tag]),
      template: std.format('%s:image%s-ARCH-${DRONE_SEMVER_SHORT}-${DRONE_SEMVER_BUILD}', [rspamd_image, asan_tag]),
      platforms: [
        'linux/amd64',
        'linux/arm64',
      ],
    } + docker_defaults,
  },
  steps: [
    multiarch_step('multiarch_image', ''),
    multiarch_step('multiarch_asan_image', '-asan'),
  ],
} + trigger_on('tag') + pipeline_defaults;

local promo_get_image_name(rspamd_image, arch) =
  std.format('%s:image-%s-${DRONE_SEMVER_SHORT}-${DRONE_SEMVER_BUILD}', [rspamd_image, arch]);

local cron_promo_get_image_name(rspamd_image, arch) =
  std.format('%s:nightly-%s', [rspamd_image, arch]);

local prepromotion_test(arch, get_image_name=promo_get_image_name, branch_name='${DRONE_SEMVER_SHORT}') = {
  name: 'prepromo_' + arch,
  platform: {
    os: 'linux',
    arch: arch,
  },
  steps: [
    {
      name: 'pre_promotion_test',
      image: get_image_name(rspamd_image, arch),
      user: 'root',
      commands: [
        'apt-get update',
        'apt-get install -y git miltertest python3 python3-dev python3-pip python3-venv redis-server',
        'python3 -mvenv $DRONE_WORKSPACE/venv',
        'bash -c "source $DRONE_WORKSPACE/venv/bin/activate && pip3 install --no-cache --disable-pip-version-check --no-binary :all: setuptools==57.5.0"',  // https://github.com/dmeranda/demjson/issues/43
        'bash -c "source $DRONE_WORKSPACE/venv/bin/activate && pip3 install --no-cache --disable-pip-version-check --no-binary :all: demjson psutil requests robotframework tornado"',
        'git clone -b ' + branch_name + ' https://github.com/rspamd/rspamd.git',
        'RSPAMD_INSTALLROOT=/usr bash -c "source $DRONE_WORKSPACE/venv/bin/activate && umask 0000 && robot --removekeywords wuks --exclude isbroken $DRONE_WORKSPACE/rspamd/test/functional/cases"',
      ],
    },
  ],
} + trigger_on('promote') + pipeline_defaults;

local promotion_multiarch(name, step_name, asan_tag) = {
  depends_on: [
    'prepromo_amd64',
    'prepromo_arm64',
  ],
  name: name,
  steps: [
    {
      name: step_name,
      image: 'plugins/manifest',
      settings: {
        target: std.format('%s:%s${DRONE_SEMVER_SHORT}', [rspamd_image, asan_tag]),
        template: std.format('%s:image-%sARCH-${DRONE_SEMVER_SHORT}-${DRONE_SEMVER_BUILD}', [rspamd_image, asan_tag]),
        platforms: [
          'linux/amd64',
          'linux/arm64',
        ],
        tags: [
          asan_tag + 'latest',
          asan_tag + '${DRONE_SEMVER_MAJOR}.${DRONE_SEMVER_MINOR}',
        ],
      } + docker_defaults,
    },
  ],
} + trigger_on('promote') + pipeline_defaults;

local cron_promotion(asan_tag) = {
  depends_on: [
    'cron_prepromo_amd64',
    'cron_prepromo_arm64',
  ],
  name: std.format('cron-%spromotion', [asan_tag]),
  steps: [
    {
      name: 'cron_promotion',
      image: 'plugins/manifest',
      settings: {
        target: std.format('%s:%snightly', [rspamd_image, asan_tag]),
        template: std.format('%s:nightly-%sARCH', [rspamd_image, asan_tag]),
        platforms: [
          'linux/amd64',
          'linux/arm64',
        ],
      } + docker_defaults,
    },
  ],
} + trigger_on('cron') + pipeline_defaults;

local cron_image_tags(asan_tag, arch) = [
  std.format('nightly%s-%s', [asan_tag, arch]),
];

local cron_pkg_tags(arch) = [
  std.format('pkg-%s-nightly', arch),
];

local cron_archspecific_splice(arch) = {
  name: 'cron_rspamd_' + arch,
} + trigger_on('cron');

local cron_prepromo_splice(arch) = {
  name: 'cron_prepromo_' + arch,
  depends_on: [
    'cron_rspamd_' + arch,
  ],
} + trigger_on('cron');

[
  architecture_specific_pipeline('amd64'),
  architecture_specific_pipeline('arm64'),
  architecture_specific_pipeline('amd64', cron_image_tags, cron_pkg_tags, 'master', 'auto') + cron_archspecific_splice('amd64'),
  architecture_specific_pipeline('arm64', cron_image_tags, cron_pkg_tags, 'master', 'auto') + cron_archspecific_splice('arm64'),
  multiarch_pipeline,
  prepromotion_test('amd64'),
  prepromotion_test('arm64'),
  prepromotion_test('amd64', cron_promo_get_image_name, 'master') + cron_prepromo_splice('amd64'),
  prepromotion_test('arm64', cron_promo_get_image_name, 'master') + cron_prepromo_splice('arm64'),
  promotion_multiarch('promotion_multiarch', 'promote_multiarch', ''),
  promotion_multiarch('promotion_multiarch_asan', 'promote_multiarch_asan', 'asan-'),
  cron_promotion(''),
  cron_promotion('asan-'),
  {
    kind: 'signature',
    hmac: '0000000000000000000000000000000000000000000000000000000000000000',
  },
]
