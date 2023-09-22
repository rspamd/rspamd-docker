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

local trigger_on_tag = {
  trigger: {
    event: {
      include: [
        'tag',
      ],
    },
  },
};

local trigger_on_promotion = {
  trigger: {
    event: [
      'promote',
    ],
  },
};

local rspamd_image = 'rspamd/rspamd';

local architecture_specific_pipeline(arch) = {
  local step_default_settings = {
    platform: 'linux/' + arch,
    repo: rspamd_image,
  },
  local install_step(name, asan_tag) = {
    name: name,
    depends_on: [
      'pkg_' + arch,
    ],
    image: 'plugins/docker',
    settings: {
      local asan_build_tag = if std.length(asan_tag) != 0 then ['ASAN_TAG=' + asan_tag] else [],
      dockerfile: 'Dockerfile',
      build_args: [
        'LONG_VERSION=${DRONE_SEMVER_SHORT}-${DRONE_SEMVER_BUILD}',
        'TARGETARCH=' + arch,
      ] + asan_build_tag,
      squash: true,
      tags: [
        std.format('image%s-%s-${DRONE_SEMVER_SHORT}-${DRONE_SEMVER_BUILD}', [asan_tag, arch]),
      ],
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
      image: 'plugins/docker',
      settings: {
        dockerfile: 'Dockerfile.pkg',
        build_args: [
          'RSPAMD_VERSION=${DRONE_SEMVER_MAJOR}.${DRONE_SEMVER_MINOR}',
          'TARGETARCH=' + arch,
        ],
        tags: [
          std.format('pkg-%s-${DRONE_SEMVER_SHORT}-${DRONE_SEMVER_BUILD}', arch),
        ],
        target: 'pkg',
      } + step_default_settings + docker_defaults,
    },
    install_step('install_' + arch, ''),
    install_step('install_asan_' + arch, '-asan'),
  ],
} + trigger_on_tag + pipeline_defaults;

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
} + trigger_on_tag + pipeline_defaults;

local promotion_multiarch(name, step_name, asan_tag) = {
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
} + trigger_on_promotion + pipeline_defaults;

[
  architecture_specific_pipeline('amd64'),
  architecture_specific_pipeline('arm64'),
  multiarch_pipeline,
  promotion_multiarch('promotion_multiarch', 'promote_multiarch', ''),
  promotion_multiarch('promotion_multiarch_asan', 'promote_multiarch_asan', 'asan-'),
  {
    kind: 'signature',
    hmac: '0000000000000000000000000000000000000000000000000000000000000000',
  },
]
