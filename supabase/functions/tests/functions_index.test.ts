/**
 * The deployable functions. Every workspace member is a directory holding an
 * index.ts whose default export is `{ fetch }`, the module shape the Supabase
 * Edge Runtime serves. Each entry point is imported here, so one that fails
 * to load fails the suite, and every index.ts is counted in coverage.
 */

import { assert, assertEquals, assertMatch, assertStrictEquals } from '@std/assert';
import { stub } from '@std/testing/mock';
import { request } from './_helpers.ts';

const ROOT = new URL('../', import.meta.url);
const UUID_V4 = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

/** The members of the root deno.json workspace, as directory names. */
async function workspaceMembers(): Promise<string[]> {
  const config: { readonly workspace?: unknown } = JSON.parse(
    await Deno.readTextFile(new URL('deno.json', ROOT)),
  );
  const members = config.workspace;
  assert(Array.isArray(members), 'deno.json lists no workspace members');
  return members.map((member) => {
    assert(typeof member === 'string', `workspace member ${member} is not a path`);
    // A top-level directory whose name is a valid function name.
    assertMatch(member, /^\.\/[A-Za-z][A-Za-z0-9_-]*$/);
    return member.slice(2);
  });
}

/** Whether the directory [name] next to deno.json holds an index.ts. */
async function hasEntryPoint(name: string): Promise<boolean> {
  try {
    return (await Deno.stat(new URL(`${name}/index.ts`, ROOT))).isFile;
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) return false;
    throw error;
  }
}

/** The directories next to deno.json that hold an index.ts, sorted. */
async function entryPointDirectories(): Promise<string[]> {
  const names: string[] = [];
  for await (const entry of Deno.readDir(ROOT)) {
    if (entry.isDirectory && await hasEntryPoint(entry.name)) names.push(entry.name);
  }
  return names.sort();
}

interface EntryPoint {
  readonly fetch: (req: Request) => Promise<Response>;
}

/** Imports `<member>/index.ts`, checking that it exports `{ fetch }` and nothing else. */
async function loadEntryPoint(member: string): Promise<EntryPoint> {
  const module: Record<string, unknown> = await import(`../${member}/index.ts`);
  assertEquals(Object.keys(module), ['default'], `${member}/index.ts has named exports`);
  const entry = module['default'];
  assert(
    typeof entry === 'object' && entry !== null,
    `${member}: the default export is not an object`,
  );
  assertEquals(Object.keys(entry), ['fetch'], `${member}: the default export is not { fetch }`);
  const { fetch } = entry as { readonly fetch?: unknown };
  assert(typeof fetch === 'function', `${member}: fetch is not a function`);
  return entry as EntryPoint;
}

Deno.test('the workspace lists exactly the directories that hold an index.ts, once each', async () => {
  const members = await workspaceMembers();
  assert(members.length > 0, 'the workspace lists no functions');
  assertEquals(new Set(members).size, members.length, 'a member is listed twice');
  assertEquals([...members].sort(), await entryPointDirectories());
});

Deno.test('every member’s index.ts default-exports { fetch }, the Edge Runtime entry point', async (t) => {
  for (const member of await workspaceMembers()) {
    await t.step(member, async () => {
      const entry = await loadEntryPoint(member);
      // One module instance: a second import yields the same handler.
      const again: Record<string, unknown> = await import(`../${member}/index.ts`);
      assertStrictEquals(again['default'], entry);
    });
  }
});

Deno.test('every entry point answers a preflight through the pipeline, logging under its own name', async (t) => {
  for (const member of await workspaceMembers()) {
    await t.step(member, async () => {
      const { fetch: serve } = await loadEntryPoint(member);
      // A preflight is answered before authentication and routing: no secret,
      // no network, only the CORS configuration (here: none) is read.
      const env = stub(Deno.env, 'get', () => undefined);
      const lines: string[] = [];
      const log = stub(console, 'log', (line: string) => void lines.push(line));
      const now = stub(performance, 'now', () => 1_000);
      try {
        const res = await serve(request({ method: 'OPTIONS', path: `/${member}`, token: null }));
        assertEquals(res.status, 204);
        assertStrictEquals(res.body, null);
        assertEquals(res.headers.get('vary'), 'Origin');
        assertEquals(res.headers.get('access-control-allow-origin'), null);
        const requestId = res.headers.get('x-request-id') ?? '';
        assertMatch(requestId, UUID_V4);
        assertEquals(lines.map((line) => JSON.parse(line)), [{
          fn: member,
          request_id: requestId,
          method: 'OPTIONS',
          status: 204,
          duration_ms: 0,
          user_id: null,
          level: 'info',
          event: 'request',
        }]);
      } finally {
        now.restore();
        log.restore();
        env.restore();
      }
    });
  }
});
