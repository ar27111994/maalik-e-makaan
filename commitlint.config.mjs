// Conventional Commits (https://www.conventionalcommits.org) with the scopes
// used in this monorepo. release-please derives versions and changelogs from
// these messages, so they are enforced locally (lefthook) and in CI.
export default {
  extends: ['@commitlint/config-conventional'],
  // release-please's own commit (release-please-config.json sets its title). Its
  // body is the generated changelog, whose links run past body-max-line-length.
  ignores: [(message) => /^chore\(release\): release \d+\.\d+\.\d+/.test(message)],
  rules: {
    // The types and header limit @commitlint/config-conventional sets, stated here so the
    // repository has one list: tool/docs/sync_facts.py copies it into pr-title.yml and checks
    // release-please's changelog sections against it.
    'type-enum': [
      2,
      'always',
      [
        'build',
        'chore',
        'ci',
        'docs',
        'feat',
        'fix',
        'perf',
        'refactor',
        'revert',
        'style',
        'test',
      ],
    ],
    'header-max-length': [2, 'always', 100],
    'scope-enum': [
      2,
      'always',
      [
        'app',
        'core',
        'ui',
        'db',
        'functions',
        'web',
        'ci',
        'deps',
        // Dependabot's scope for development dependencies.
        'deps-dev',
        'docs',
        'formal',
        'planning',
        'release',
        'repo',
        'security',
        'test',
      ],
    ],
    'body-max-line-length': [2, 'always', 100],
    'footer-max-line-length': [0],
    'subject-case': [2, 'never', ['upper-case', 'pascal-case', 'start-case']],
  },
};
