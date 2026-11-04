/**
 * Every function deploys with its own deno.json (Supabase's recommendation),
 * so the runtime dependencies are declared four times: in each function and
 * in the workspace root used for type-checking and tests. This keeps them
 * identical and exactly pinned.
 */

import { assert, assertEquals } from '@std/assert';

const ROOT = new URL('../', import.meta.url);
const FUNCTIONS = ['delete-account', 'invite-member', 'health'];
const RUNTIME_IMPORTS = ['@supabase/server', '@supabase/server/core', '@supabase/supabase-js'];

async function imports(path: string): Promise<Record<string, string>> {
  const config = JSON.parse(await Deno.readTextFile(new URL(path, ROOT)));
  return config.imports ?? {};
}

Deno.test('each function pins exactly the runtime dependencies of the workspace', async () => {
  const root = await imports('deno.json');
  for (const fn of FUNCTIONS) {
    const own = await imports(`${fn}/deno.json`);
    assertEquals(Object.keys(own).sort(), [...RUNTIME_IMPORTS].sort(), fn);
    for (const name of RUNTIME_IMPORTS) {
      assertEquals(own[name], root[name], `${fn}: ${name}`);
    }
  }
});

Deno.test('every dependency is pinned to an exact version', async () => {
  const root = await imports('deno.json');
  for (const [name, specifier] of Object.entries(root)) {
    assert(/@\d+\.\d+\.\d+(\/|$)/.test(specifier), `${name} → ${specifier} is not pinned`);
  }
});

Deno.test('the workspace lists every function', async () => {
  const config = JSON.parse(await Deno.readTextFile(new URL('deno.json', ROOT)));
  assertEquals(config.workspace, FUNCTIONS.map((fn) => `./${fn}`));
});
