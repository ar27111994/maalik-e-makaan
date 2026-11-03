// Conventional Commits (https://www.conventionalcommits.org) with the scopes
// used in this monorepo. release-please derives versions and changelogs from
// these messages, so they are enforced locally (lefthook) and in CI.
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
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
        'docs',
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
