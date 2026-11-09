// The local Supabase stack the app talks to: Mailpit for the e-mails Auth
// sends, and SQL for what no screen does (running the daily job, reading
// the ledger to compare with what the screens show).
import { execFileSync } from "node:child_process";
import { crc32, deflateSync } from "node:zlib";

function required(name: string, fallback?: string): string {
  const value = process.env[name] ?? fallback;
  if (!value) throw new Error(`${name} is not set (tool/uat/run.sh sets it from supabase status)`);
  return value;
}

export const stack = {
  apiUrl: required("UAT_API_URL", "http://127.0.0.1:54321"),
  publishableKey: required("UAT_PUBLISHABLE_KEY"),
  mailpitUrl: required("UAT_MAILPIT_URL", "http://127.0.0.1:54324"),
  cleanupToken: required("UAT_CLEANUP_TOKEN"),
  dbUrl: required("UAT_DB_URL", "postgresql://postgres:postgres@127.0.0.1:54322/postgres"),
};

/** A run-unique suffix, so the suite can run again on the same stack. */
export const runId = Date.now().toString(36);

/** A unique address on the example.com domain Mailpit captures. */
export function emailFor(who: string): string {
  return `uat-${who}-${runId}@example.com`;
}

interface MailSummary {
  ID: string;
  Subject: string;
  To: { Address: string }[];
  Created: string;
}

/** The newest e-mail to [address], waiting up to [timeoutMs] for it. */
export async function latestMailTo(
  address: string,
  timeoutMs = 30_000,
): Promise<{ subject: string; text: string; html: string }> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const response = await fetch(
      `${stack.mailpitUrl}/api/v1/search?query=${encodeURIComponent(`to:"${address}"`)}&limit=5`,
    );
    if (response.ok) {
      const body = (await response.json()) as { messages: MailSummary[] };
      const newest = body.messages?.[0];
      if (newest) {
        const message = (await (
          await fetch(`${stack.mailpitUrl}/api/v1/message/${newest.ID}`)
        ).json()) as {
          Subject: string;
          Text: string;
          HTML: string;
        };
        return { subject: message.Subject, text: message.Text, html: message.HTML };
      }
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error(`No e-mail reached ${address} within ${timeoutMs} ms`);
}

/** The first link in [mail] that goes to Auth's verify endpoint. */
export function verifyLink(mail: { text: string; html: string }): string {
  const source = `${mail.html}\n${mail.text}`;
  const match = source.match(/https?:\/\/[^\s"'<>]+\/auth\/v1\/verify\?[^\s"'<>]+/);
  if (!match) throw new Error(`No verify link in the e-mail:\n${mail.text}`);
  return match[0].replace(/&amp;/g, "&");
}

/** Runs [sql] as the database owner and returns psql's unaligned rows. */
export function sql(statement: string): string[][] {
  const output = execFileSync(
    "psql",
    [stack.dbUrl, "-X", "-q", "-A", "-t", "-F", "\t", "-v", "ON_ERROR_STOP=1", "-c", statement],
    {
      encoding: "utf8",
    },
  );
  return output
    .split("\n")
    .filter((line) => line.length > 0)
    .map((line) => line.split("\t"));
}

/** Single-quoted SQL literal. */
export function literal(value: string): string {
  return `'${value.replace(/'/g, "''")}'`;
}

/** A small synthetic PNG (a flat colour, no personal data) for uploads. */
export function samplePng(width = 64, height = 48): Buffer {
  const chunk = (type: string, data: Buffer) => {
    const length = Buffer.alloc(4);
    length.writeUInt32BE(data.length);
    const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
    const crc = Buffer.alloc(4);
    crc.writeUInt32BE(crc32(body) >>> 0);
    return Buffer.concat([length, body, crc]);
  };
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8; // bit depth
  header[9] = 2; // RGB
  const row = Buffer.concat([Buffer.from([0]), Buffer.alloc(width * 3, 0x5a)]);
  const pixels = Buffer.concat(Array.from({ length: height }, () => row));
  return Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk("IHDR", header),
    chunk("IDAT", deflateSync(pixels)),
    chunk("IEND", Buffer.alloc(0)),
  ]);
}

/** The number of pages of [pdf]: the largest /Count of its page tree. */
export function pdfPages(pdf: Buffer): number {
  const counts = [...pdf.toString("latin1").matchAll(/\/Count\s+(\d+)/g)].map((m) => Number(m[1]));
  return counts.length === 0 ? 0 : Math.max(...counts);
}
