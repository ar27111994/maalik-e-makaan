/**
 * The Resend sender (_shared/email.ts): every message is one idempotent HTTPS POST, and
 * every failure is an EmailDeliveryError carrying the provider's status (0 when no
 * response arrived) and a machine-readable reason, never the provider's free text.
 */

import { assertEquals, assertInstanceOf, assertRejects, assertStrictEquals } from '@std/assert';
import { stub } from '@std/testing/mock';
import type { EmailConfig } from '../_shared/config.ts';
import {
  createResendSender,
  EmailDeliveryError,
  type EmailMessage,
  RESEND_ENDPOINT,
} from '../_shared/email.ts';

const CONFIG: EmailConfig = {
  apiKey: 're_test_key',
  from: 'Maalik-e-Makaan <invites@example.com>',
  replyTo: 'support@example.com',
};

/** A message without tags. */
const MESSAGE: EmailMessage = {
  to: 'imran@example.com',
  subject: 'You are invited',
  html: '<p>Hi</p>',
  text: 'Hi\nthere',
  idempotencyKey: 'invitation:0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8aa0',
};

const TAGGED: EmailMessage = { ...MESSAGE, tags: { category: 'invitation', role: 'manager' } };

interface Sent {
  readonly url: string;
  readonly init: RequestInit;
}

/** A fetch that records every request and answers it with [respond]. */
function fakeFetch(respond: () => Response): { impl: typeof fetch; requests: Sent[] } {
  const requests: Sent[] = [];
  const impl: typeof fetch = (input, init) => {
    requests.push({ url: String(input), init: init ?? {} });
    return Promise.resolve(respond());
  };
  return { impl, requests };
}

/** The JSON body of the single request in [requests]. */
function bodyOf(requests: readonly Sent[]): Record<string, unknown> {
  assertEquals(requests.length, 1);
  return JSON.parse(String(requests[0]?.init.body));
}

/** Sends [message] through [fetchImpl] while AbortSignal.timeout is stubbed: no timer starts. */
async function send(
  fetchImpl: typeof fetch,
  message: EmailMessage = TAGGED,
  config: EmailConfig = CONFIG,
): Promise<{ id: string }> {
  const timeout = stub(AbortSignal, 'timeout', () => new AbortController().signal);
  try {
    return await createResendSender(config, fetchImpl).send(message);
  } finally {
    timeout.restore();
  }
}

/** The EmailDeliveryError that sending [message] through [fetchImpl] rejects with. */
function failure(fetchImpl: typeof fetch, message: EmailMessage = TAGGED) {
  return assertRejects(() => send(fetchImpl, message), EmailDeliveryError);
}

// --- the request -------------------------------------------------------------------------

Deno.test('send POSTs one JSON request to Resend with the API key, the idempotency key and a 10 s timeout', async () => {
  assertEquals(RESEND_ENDPOINT, 'https://api.resend.com/emails');
  const { impl, requests } = fakeFetch(() => Response.json({ id: 'msg_1', object: 'email' }));
  const signal = new AbortController().signal;
  const timeout = stub(AbortSignal, 'timeout', () => signal);
  try {
    // Only the message id is returned, whatever else the provider answers.
    assertEquals(await createResendSender(CONFIG, impl).send(TAGGED), { id: 'msg_1' });
  } finally {
    timeout.restore();
  }

  assertEquals(timeout.calls.map((call) => call.args), [[10_000]]);
  assertEquals(requests.length, 1);
  const [{ url, init }] = requests as [Sent];
  assertEquals(url, RESEND_ENDPOINT);
  assertEquals(Object.keys(init).sort(), ['body', 'headers', 'method', 'signal']);
  assertEquals(init.method, 'POST');
  assertEquals(init.headers, {
    authorization: 'Bearer re_test_key',
    'content-type': 'application/json',
    'idempotency-key': 'invitation:0192d0c4-7a5e-7c1e-9a4b-2f6d1e3c8aa0',
  });
  assertStrictEquals(init.signal, signal);
  assertEquals(JSON.parse(String(init.body)), {
    from: 'Maalik-e-Makaan <invites@example.com>',
    to: ['imran@example.com'],
    subject: 'You are invited',
    html: '<p>Hi</p>',
    text: 'Hi\nthere',
    reply_to: 'support@example.com',
    tags: [{ name: 'category', value: 'invitation' }, { name: 'role', value: 'manager' }],
  });
});

Deno.test('reply_to and tags are sent only when set', async () => {
  const cases: Array<[string, string | null, EmailMessage['tags'], Record<string, unknown>]> = [
    ['neither', null, undefined, {}],
    ['an empty tag map', null, {}, {}],
    ['a reply-to address only', 'support@example.com', undefined, {
      reply_to: 'support@example.com',
    }],
    ['a tag only', null, { category: 'invitation' }, {
      tags: [{ name: 'category', value: 'invitation' }],
    }],
  ];
  for (const [label, replyTo, tags, extra] of cases) {
    const { impl, requests } = fakeFetch(() => Response.json({ id: 'msg_2' }));
    const message: EmailMessage = tags === undefined ? MESSAGE : { ...MESSAGE, tags };
    assertEquals(await send(impl, message, { ...CONFIG, replyTo }), { id: 'msg_2' }, label);
    assertEquals(bodyOf(requests), {
      from: CONFIG.from,
      to: [MESSAGE.to],
      subject: MESSAGE.subject,
      html: MESSAGE.html,
      text: MESSAGE.text,
      ...extra,
    }, label);
  }
});

Deno.test('the subject is sent on a single line; the html and text parts are sent as given', async () => {
  const cases: Array<[string, string]> = [
    ['You are\ninvited', 'You are invited'],
    ['  Line one\r\n\tLine two  ', 'Line one Line two'],
    ['Invitation\r\nBcc: victim@example.com', 'Invitation Bcc: victim@example.com'],
    ['Already one line', 'Already one line'],
  ];
  for (const [subject, sent] of cases) {
    const { impl, requests } = fakeFetch(() => Response.json({ id: 'msg_3' }));
    await send(impl, { ...MESSAGE, subject, html: '<p>a</p>\n<p>b</p>', text: 'a\n\nb' });
    const body = bodyOf(requests);
    assertEquals(
      [body['subject'], body['html'], body['text']],
      [sent, '<p>a</p>\n<p>b</p>', 'a\n\nb'],
      JSON.stringify(subject),
    );
  }
});

// --- tags ----------------------------------------------------------------------------------

Deno.test('tags of 1 to 256 ASCII letters, digits, "_" and "-" are sent in order', async () => {
  const name = `${'N'.repeat(255)}_`;
  const value = `v-${'9'.repeat(254)}`;
  const { impl, requests } = fakeFetch(() => Response.json({ id: 'msg_4' }));
  await send(impl, { ...MESSAGE, tags: { a: 'b', 'A-z_09': 'X-y_1', [name]: value } });
  assertEquals(bodyOf(requests)['tags'], [
    { name: 'a', value: 'b' },
    { name: 'A-z_09', value: 'X-y_1' },
    { name, value },
  ]);
});

Deno.test('a tag Resend would refuse is an EmailDeliveryError(0) naming it, before any request', async () => {
  const long = 'a'.repeat(257);
  const cases: Array<[string, Record<string, string>, string]> = [
    ['a space in the value', { role: 'co owner' }, 'role'],
    ['a space in the name', { 'bad name': 'x' }, 'bad name'],
    ['an empty value', { role: '' }, 'role'],
    ['an empty name', { '': 'x' }, ''],
    ['a trailing line break', { role: 'manager\n' }, 'role'],
    ['a non-ASCII letter', { role: 'mänager' }, 'role'],
    ['a dot', { 'role.name': 'owner' }, 'role.name'],
    ['a 257-character value', { role: long }, 'role'],
    ['a 257-character name', { [long]: 'x' }, long],
    ['a bad tag after a good one', { category: 'invitation', role: 'co owner' }, 'role'],
  ];
  for (const [label, tags, name] of cases) {
    const { impl, requests } = fakeFetch(() => Response.json({ id: 'never' }));
    const error = await failure(impl, { ...MESSAGE, tags });
    assertEquals(
      [error.status, error.reason, error.message],
      [0, `invalid tag ${name}`, `e-mail delivery failed (0): invalid tag ${name}`],
      label,
    );
    assertEquals(requests, [], label);
  }
});

// --- failures ------------------------------------------------------------------------------

Deno.test('a request that gets no response is an EmailDeliveryError(0) named after the error', async () => {
  const cases: Array<[string, typeof fetch, string]> = [
    [
      'a connection failure',
      () => Promise.reject(new TypeError('error sending request for url (https://api.resend.com)')),
      'TypeError',
    ],
    [
      'the timeout',
      () => Promise.reject(new DOMException('Signal timed out.', 'TimeoutError')),
      'TimeoutError',
    ],
    [
      'an abort',
      () => Promise.reject(new DOMException('The signal has been aborted', 'AbortError')),
      'AbortError',
    ],
    ['a synchronous throw', () => {
      throw new RangeError('bad request init');
    }, 'RangeError'],
    ['a rejection that is not an Error', () => Promise.reject('offline'), 'network_error'],
  ];
  for (const [label, impl, reason] of cases) {
    const error = await failure(impl);
    assertEquals(
      [error.name, error.status, error.reason, error.message],
      ['EmailDeliveryError', 0, reason, `e-mail delivery failed (0): ${reason}`],
      label,
    );
  }
});

Deno.test('an error response is an EmailDeliveryError(status) with the JSON name only, else unknown_error', async () => {
  const cases: Array<[string, () => Response, number, string]> = [
    [
      'a Resend validation error',
      () =>
        Response.json({
          statusCode: 422,
          name: 'validation_error',
          message: 'Invalid `to` field: imran@example.com',
        }, { status: 422 }),
      422,
      'validation_error',
    ],
    [
      'a Resend rate limit',
      () =>
        Response.json({
          statusCode: 429,
          name: 'rate_limit_exceeded',
          message: 'Too many requests',
        }, {
          status: 429,
        }),
      429,
      'rate_limit_exceeded',
    ],
    [
      'an HTML gateway page',
      () => new Response('<html>Bad gateway</html>', { status: 502 }),
      502,
      'unknown_error',
    ],
    ['an empty body', () => new Response(null, { status: 503 }), 503, 'unknown_error'],
    ['JSON null', () => Response.json(null, { status: 500 }), 500, 'unknown_error'],
    [
      'a name that is not text',
      () => Response.json({ name: 401 }, { status: 401 }),
      401,
      'unknown_error',
    ],
  ];
  for (const [label, respond, status, reason] of cases) {
    const { impl, requests } = fakeFetch(respond);
    const error = await failure(impl);
    // The provider's message (which may quote the recipient) never reaches the error.
    assertEquals(
      [error.status, error.reason, error.message],
      [status, reason, `e-mail delivery failed (${status}): ${reason}`],
      label,
    );
    assertEquals(requests.length, 1, label);
  }
});

Deno.test('a success response without a message id is an EmailDeliveryError(status, missing_message_id)', async () => {
  const cases: Array<[string, () => Response, number]> = [
    ['an empty object', () => Response.json({}), 200],
    ['a numeric id', () => Response.json({ id: 42 }), 200],
    ['JSON null', () => Response.json(null, { status: 202 }), 202],
    ['a body that is not JSON', () => new Response('queued', { status: 202 }), 202],
    ['no body', () => new Response(null, { status: 200 }), 200],
  ];
  for (const [label, respond, status] of cases) {
    const { impl } = fakeFetch(respond);
    const error = await failure(impl);
    assertEquals(
      [error.status, error.reason, error.message],
      [status, 'missing_message_id', `e-mail delivery failed (${status}): missing_message_id`],
      label,
    );
  }
});

Deno.test('EmailDeliveryError is an Error carrying the status and the reason', () => {
  const error = new EmailDeliveryError(503, 'service_unavailable');
  assertInstanceOf(error, Error);
  assertEquals(
    [error.name, error.status, error.reason, error.message],
    [
      'EmailDeliveryError',
      503,
      'service_unavailable',
      'e-mail delivery failed (503): service_unavailable',
    ],
  );
});

// --- wiring --------------------------------------------------------------------------------

Deno.test('createResendSender sends through the global fetch by default', async () => {
  const requests: Sent[] = [];
  const fetchStub = stub(globalThis, 'fetch', (input, init) => {
    requests.push({ url: String(input), init: init ?? {} });
    return Promise.resolve(Response.json({ id: 'msg_default' }));
  });
  const timeout = stub(AbortSignal, 'timeout', () => new AbortController().signal);
  try {
    assertEquals(await createResendSender(CONFIG).send(TAGGED), { id: 'msg_default' });
  } finally {
    timeout.restore();
    fetchStub.restore();
  }
  assertEquals(requests.map(({ url }) => url), [RESEND_ENDPOINT]);
  assertEquals(
    (requests[0]?.init.headers as Record<string, string>)['authorization'],
    'Bearer re_test_key',
  );
});
