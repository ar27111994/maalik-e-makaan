import { assertEquals, assertInstanceOf, assertRejects } from '@std/assert';
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

const MESSAGE: EmailMessage = {
  to: 'imran@example.com',
  subject: 'You are\ninvited',
  html: '<p>Hi</p>',
  text: 'Hi',
  idempotencyKey: 'invitation:1',
  tags: { category: 'invitation', role: 'manager' },
};

function fakeFetch(respond: (url: string, init: RequestInit) => Response | Promise<Response>) {
  const calls: Array<{ url: string; init: RequestInit }> = [];
  const impl: typeof fetch = (input, init) => {
    const url = String(input);
    calls.push({ url, init: init ?? {} });
    return Promise.resolve(respond(url, init ?? {}));
  };
  return { impl, calls };
}

Deno.test('sends one idempotent request to the Resend API', async () => {
  const { impl, calls } = fakeFetch(() => Response.json({ id: 'msg_1' }));
  assertEquals(await createResendSender(CONFIG, impl).send(MESSAGE), { id: 'msg_1' });

  assertEquals(calls.length, 1);
  const [{ url, init }] = calls as [{ url: string; init: RequestInit }];
  assertEquals(url, RESEND_ENDPOINT);
  assertEquals(init.method, 'POST');
  assertEquals(init.headers, {
    authorization: 'Bearer re_test_key',
    'content-type': 'application/json',
    'idempotency-key': 'invitation:1',
  });
  assertInstanceOf(init.signal, AbortSignal);
  assertEquals(JSON.parse(String(init.body)), {
    from: 'Maalik-e-Makaan <invites@example.com>',
    to: ['imran@example.com'],
    subject: 'You are invited',
    html: '<p>Hi</p>',
    text: 'Hi',
    reply_to: 'support@example.com',
    tags: [{ name: 'category', value: 'invitation' }, { name: 'role', value: 'manager' }],
  });
});

Deno.test('omits reply_to and tags when there are none', async () => {
  const { impl, calls } = fakeFetch(() => Response.json({ id: 'msg_2' }));
  const { tags: _tags, ...untagged } = MESSAGE;
  await createResendSender({ ...CONFIG, replyTo: null }, impl).send(untagged);
  const body = JSON.parse(String(calls[0]?.init.body));
  assertEquals('reply_to' in body, false);
  assertEquals('tags' in body, false);
});

Deno.test('rejects tags the provider would refuse, before calling it', async () => {
  const { impl, calls } = fakeFetch(() => Response.json({ id: 'never' }));
  const error = await assertRejects(
    () => createResendSender(CONFIG, impl).send({ ...MESSAGE, tags: { role: 'co owner' } }),
    EmailDeliveryError,
  );
  assertEquals([error.status, error.reason], [0, 'invalid tag role']);
  assertEquals(calls.length, 0);
});

Deno.test('reports network failures and timeouts with status 0', async () => {
  const failing: typeof fetch = () => Promise.reject(new DOMException('timed out', 'TimeoutError'));
  const error = await assertRejects(
    () => createResendSender(CONFIG, failing).send(MESSAGE),
    EmailDeliveryError,
  );
  assertEquals([error.status, error.reason, error.name], [0, 'TimeoutError', 'EmailDeliveryError']);

  const odd: typeof fetch = () => Promise.reject('not an error object');
  const unknown = await assertRejects(
    () => createResendSender(CONFIG, odd).send(MESSAGE),
    EmailDeliveryError,
  );
  assertEquals(unknown.reason, 'network_error');
});

Deno.test('reports provider errors by their machine-readable name only', async () => {
  const rejected = fakeFetch(() =>
    Response.json({ statusCode: 422, name: 'validation_error', message: 'Bad from' }, {
      status: 422,
    })
  );
  const error = await assertRejects(
    () => createResendSender(CONFIG, rejected.impl).send(MESSAGE),
    EmailDeliveryError,
  );
  assertEquals([error.status, error.reason], [422, 'validation_error']);
  assertEquals(error.message, 'e-mail delivery failed (422): validation_error');

  const opaque = fakeFetch(() => new Response('<html>Bad gateway</html>', { status: 502 }));
  const unknown = await assertRejects(
    () => createResendSender(CONFIG, opaque.impl).send(MESSAGE),
    EmailDeliveryError,
  );
  assertEquals([unknown.status, unknown.reason], [502, 'unknown_error']);
});

Deno.test('treats a success response without a message id as a failure', async () => {
  const { impl } = fakeFetch(() => Response.json({}));
  const error = await assertRejects(
    () => createResendSender(CONFIG, impl).send(MESSAGE),
    EmailDeliveryError,
  );
  assertEquals([error.status, error.reason], [200, 'missing_message_id']);
});

Deno.test('uses the global fetch by default', () => {
  // Constructing the sender must not perform any request.
  assertEquals(typeof createResendSender(CONFIG).send, 'function');
});
