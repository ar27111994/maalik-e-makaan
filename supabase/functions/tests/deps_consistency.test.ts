/**
 * Every function deploys with its own deno.json (Supabase's recommendation),
 * so the runtime dependencies are declared once per function and again in the
 * workspace root used for type-checking and tests. These checks keep those
 * copies identical and exactly pinned, every package a function's code
 * imports declared where it deploys, and the shared lockfile in step.
 */

import { assert, assertEquals, assertExists, assertMatch } from '@std/assert';

const ROOT = new URL('../', import.meta.url);
/** The deployed functions, storage-cleanup included. */
const FUNCTIONS = ['delete-account', 'health', 'invite-member', 'storage-cleanup'];
/** The runtime dependencies each function's deno.json pins, as the root does. */
const RUNTIME_IMPORTS = ['@supabase/server', '@supabase/server/core', '@supabase/supabase-js'];

type Imports = Readonly<Record<string, string>>;

interface DenoConfig {
  readonly workspace?: readonly string[];
  readonly imports?: Imports;
}

interface Lockfile {
  readonly npm?: Readonly<Record<string, unknown>>;
  readonly workspace?: {
    readonly dependencies?: readonly string[];
    readonly members?: Readonly<Record<string, { readonly dependencies?: readonly string[] }>>;
  };
}

async function readJson<T>(path: string): Promise<T> {
  return JSON.parse(await Deno.readTextFile(new URL(path, ROOT)));
}

async function importsOf(path: string): Promise<Imports> {
  return (await readJson<DenoConfig>(path)).imports ?? {};
}

/** The workspace members of the root deno.json, as directory names. */
async function members(): Promise<string[]> {
  const root = await readJson<DenoConfig>('deno.json');
  return (root.workspace ?? []).map((member) => member.replace(/^\.\//, ''));
}

/** `import … from '…'` and `export … from '…'` (deno fmt writes single quotes). */
const FROM_CLAUSE = /^\s*(?:import|export)\b[\w\s{},*$]*?\bfrom\s*'([^']+)'/gm;
/** `import '…'` for side effects, and `import('…')` with a literal specifier. */
const BARE_IMPORT = /^\s*import\s*'([^']+)'|\bimport\s*\(\s*'([^']+)'\s*\)/gm;

function specifiersIn(source: string): string[] {
  return [
    ...[...source.matchAll(FROM_CLAUSE)].map((match) => match[1]),
    ...[...source.matchAll(BARE_IMPORT)].map((match) => match[1] ?? match[2]),
  ].filter((specifier): specifier is string => specifier !== undefined);
}

/** The package specifiers reachable from [entry] through its relative imports. */
async function packagesImportedFrom(entry: URL): Promise<Set<string>> {
  const packages = new Set<string>();
  const visited = new Set<string>();
  const pending = [entry];
  for (let file = pending.pop(); file !== undefined; file = pending.pop()) {
    if (visited.has(file.href)) continue;
    visited.add(file.href);
    for (const specifier of specifiersIn(await Deno.readTextFile(file))) {
      if (/^\.\.?\//.test(specifier)) pending.push(new URL(specifier, file));
      else packages.add(specifier);
    }
  }
  return packages;
}

/** The registry package a specifier pins: `npm:@scope/name@1.2.3/sub` → `npm:@scope/name@1.2.3`. */
function packageOf(specifier: string): string {
  const match = /^(?:npm|jsr):(?:@[^/]+\/)?[^/@]+@[^/]+/.exec(specifier);
  assertExists(match, `${specifier} is not a registry specifier`);
  return match[0];
}

/** The distinct packages an import map pins, sorted as the lockfile lists them. */
function packagesOf(imports: Imports): string[] {
  return [...new Set(Object.values(imports).map(packageOf))].sort();
}

Deno.test('the workspace members are the four deployed functions, storage-cleanup included', async () => {
  assertEquals((await members()).sort(), FUNCTIONS);
});

Deno.test('every function’s deno.json imports exactly the root’s pins for its runtime dependencies', async (t) => {
  const root = await importsOf('deno.json');
  for (const name of RUNTIME_IMPORTS) assertExists(root[name], `the root does not pin ${name}`);
  const pins = Object.fromEntries(RUNTIME_IMPORTS.map((name) => [name, root[name]]));
  for (const fn of await members()) {
    await t.step(fn, async () => {
      assertEquals(await importsOf(`${fn}/deno.json`), pins);
    });
  }
});

Deno.test('every package a function’s code imports is declared in that function’s deno.json', async (t) => {
  for (const fn of await members()) {
    await t.step(fn, async () => {
      const declared = Object.keys(await importsOf(`${fn}/deno.json`));
      const used = await packagesImportedFrom(new URL(`${fn}/index.ts`, ROOT));
      // Every function runs through _shared/handler.ts, which imports @supabase/server.
      assert(used.has('@supabase/server'), `${fn}: the scan found no package import`);
      for (const specifier of used) {
        assert(
          declared.includes(specifier),
          `${fn} imports ${specifier}, which ${fn}/deno.json does not declare`,
        );
      }
    });
  }
});

Deno.test('every dependency of the workspace is pinned to an exact version', async () => {
  const root = await importsOf('deno.json');
  assert(Object.keys(root).length > 0, 'the root pins nothing');
  for (const [name, specifier] of Object.entries(root)) {
    assertMatch(
      specifier,
      /^(?:npm|jsr):(?:@[\w.-]+\/)?[\w.-]+@\d+\.\d+\.\d+(?:\/[\w./-]+)?$/,
      `${name} → ${specifier} is not an exact pin`,
    );
  }
});

Deno.test('the frozen lockfile records the root and every function with the pins they declare', async (t) => {
  const lock = await readJson<Lockfile>('deno.lock');
  assertEquals(
    [...(lock.workspace?.dependencies ?? [])].sort(),
    packagesOf(await importsOf('deno.json')),
  );
  const recorded = lock.workspace?.members ?? {};
  assertEquals(Object.keys(recorded).sort(), (await members()).sort());
  for (const fn of await members()) {
    await t.step(fn, async () => {
      assertEquals(
        [...(recorded[fn]?.dependencies ?? [])].sort(),
        packagesOf(await importsOf(`${fn}/deno.json`)),
      );
    });
  }
});

Deno.test('one supabase-js, the pinned one, serves the functions and @supabase/server alike', async () => {
  const lock = await readJson<Lockfile>('deno.lock');
  const pin = (await importsOf('deno.json'))['@supabase/supabase-js'];
  assertExists(pin);
  // npm:@supabase/supabase-js@2.118.0 → @supabase/supabase-js@2.118.0
  const pinned = packageOf(pin).replace(/^npm:/, '');
  const resolved = Object.keys(lock.npm ?? {}).filter((key) =>
    key.startsWith('@supabase/supabase-js@')
  );
  assertEquals(resolved, [pinned]);
});
