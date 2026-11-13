// The UAT journeys (docs/uat.md): a landlord and a viewer, from sign-up to
// account deletion, against the local Supabase stack. They run in order and
// share their data; each journey checks what the screens show against the
// database. Run them with `make test-uat` (tool/uat/run.sh).
import { expect, test, type Page } from "@playwright/test";
import { readFileSync, writeFileSync } from "node:fs";
import {
  activate,
  button,
  chooseDate,
  fill,
  loose,
  open,
  openTab,
  pickerDate,
  reload,
  see,
  shot,
  tap,
} from "../support/app";
import {
  emailFor,
  latestMailTo,
  literal,
  pdfPages,
  samplePng,
  sql,
  stack,
  verifyLink,
} from "../support/stack";

const password = "Uat-Passw0rd-2026";
const owner = { name: "Owner Uat", email: emailFor("owner") };
const viewer = { name: "Viewer Uat", email: emailFor("viewer") };
let moveIn: Date;
let leaseId: string;
const today = pktToday();
const year = today.getFullYear();
// The tenancy starts on the 1st, two months ago: three rents (two of them
// long overdue) and the deposit are owed at once.
const months = [0, 1, 2].map((i) => monthName(today.getFullYear(), today.getMonth() - 2 + i));
const receipt1 = `MM-${year}-00001`;
// A rent is late once more than 5 grace days have passed since its due day
// (the 5th): always for the first two months, and for this month after the
// 10th.
const lateFees = today.getDate() > 10 ? 3 : 2;

/**
 * What a browser still holds of an account once its session ended: nothing
 * (docs/architecture/app.md, On the device). The display settings stay: they
 * are the device's.
 */
async function expectAccountForgotten(page: Page): Promise<void> {
  const keys = () => page.evaluate(() => Object.keys(localStorage));
  await expect
    .poll(async () =>
      (await keys()).filter(
        (key) =>
          key.startsWith("mm.swr.") ||
          key === "mm.portfolio.current" ||
          key === "mm.documents.camera_target" ||
          key === "mm.invitation.pending" ||
          /^sb-.+-auth-token$/.test(key),
      ),
    )
    .toEqual([]);
  expect(await keys()).toContain("mm.settings.locale");
}

/** "September 2026", as the app names a rent month in English. */
function monthName(year: number, monthIndex: number): string {
  return new Intl.DateTimeFormat("en-GB", { month: "long", year: "numeric" }).format(
    new Date(year, monthIndex, 1),
  );
}

/** "9 Nov 2026", as the app writes a day in English. */
function shortDate(date: Date): string {
  return new Intl.DateTimeFormat("en-GB", {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(date);
}

/** Notes an observation in the report (and the log) without failing. */
function record(type: string, description: string): void {
  test.info().annotations.push({ type, description });
  console.log(`[observed] ${test.info().title}: ${type} = ${description}`);
}

/** Today in Pakistan, as a local Date at midnight. */
function pktToday(): Date {
  const [y, m, d] = new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Karachi" })
    .format(new Date())
    .split("-")
    .map(Number);
  return new Date(y, m - 1, d);
}

test.describe.serial("Landlord journeys", () => {
  let page: Page;
  let viewerPage: Page;

  test.beforeAll(async ({ browser }) => {
    // The daily job runs every 10 minutes through pg_cron. It is paused for
    // the suite so that J6 decides when late fees appear, then resumed.
    sql(
      "select cron.alter_job(jobid, active := false) from cron.job where jobname = 'mm-daily-jobs'",
    );
    page = await browser.newPage();
  });

  test.afterAll(() => {
    sql(
      "select cron.alter_job(jobid, active := true) from cron.job where jobname = 'mm-daily-jobs'",
    );
  });

  test("J1 sign up in English and confirm the e-mail", async () => {
    await open(page, "/");
    await tap(page, "Continue in English");
    await tap(page, "Create account");
    await fill(page, "Your name", owner.name);
    await fill(page, "E-mail", owner.email);
    await fill(page, "Password", password);
    await tap(page, "Create account");
    await see(page, "Check your e-mail");
    await shot(page, "en-01-check-email");
    const mail = await latestMailTo(owner.email);
    expect(mail.subject).toBe("Confirm your e-mail address · اپنی ای میل کی تصدیق کریں");
    expect(mail.html).toContain("Welcome to Maalik-e-Makaan.");
    expect(mail.html).toContain("مالکِ مکان ایپ میں خوش آمدید۔");
    await open(page, verifyLink(mail));
    await expect(page).toHaveURL(/\/portfolios\/new/);
    await fill(page, "Portfolio name", "UAT Rentals");
    await tap(page, "Create portfolio");
    await see(page, "UAT Rentals is ready.");
    await see(page, "No properties yet");
  });

  test("J2 add a property and a unit", async () => {
    await tap(page, "Add property");
    await fill(page, "Name", "Gulberg House");
    await fill(page, "Address", "12 Main Boulevard");
    await fill(page, "City", "Lahore");
    await tap(page, "Province");
    await tap(page, "Punjab");
    await tap(page, "Save");
    await see(page, "Gulberg House added.");
    await see(page, loose("register each tenancy with the police within 15 days"));
    await tap(page, "Add unit");
    await fill(page, "Name or number", "Ground floor");
    await fill(page, "Asking rent", "50000");
    await tap(page, "Save");
    await see(page, "Ground floor added.");
    // Vacant since today in Pakistan, not the UTC date of the unit's
    // creation (defect D5, fixed by 20261109081109_uat_display_fixes.sql).
    await see(page, loose(`Vacant since ${shortDate(today)}`));
    await see(page, loose("Asking rent, 50000 rupees"));
  });

  test("J3 add a tenant", async () => {
    await openTab(page, "Tenants");
    await see(page, "No tenants yet");
    await tap(page, "Add tenant");
    await fill(page, "Full name", "Tenant Uat");
    await fill(page, "CNIC", "1111111111111");
    await fill(page, "Phone", "0300123456");
    await activate(
      page.getByRole("checkbox", { name: "I told the tenant what details are kept and why" }),
    );
    await tap(page, "Save");
    await expect(page.getByRole("textbox", { name: "CNIC" })).toHaveAttribute(
      "aria-invalid",
      "true",
    );
    await see(page, "Enter the 13 digits of a CNIC, like 35202-1234567-1.");
    await see(page, "Enter a phone number like 03001234567.");
    await shot(page, "en-03-tenant-invalid");
    await fill(page, "CNIC", "3520298765431");
    await fill(page, "Phone", "03001234567");
    await tap(page, "Save");
    await see(page, "Tenant Uat added.");
    await see(page, loose("35202, 7 hidden digits, 1"));
    await shot(page, "en-04-tenant");
  });

  test("J4 start a tenancy", async () => {
    await tap(page, "Start tenancy");
    await tap(page, "Choose the unit");
    await tap(page, "Gulberg House Lahore");
    await tap(page, /^Ground floor/);
    // Moved in on the 1st, two months ago: two rents are overdue by now.
    moveIn = new Date(today.getFullYear(), today.getMonth() - 2, 1);
    await chooseDate(
      page,
      page.getByRole("button", { name: "Choose a date", exact: true }).first(),
      pickerDate(moveIn),
    );
    await fill(page, "Monthly rent", "50000");
    await fill(page, "Security deposit", "100000");
    await activate(page.getByRole("radio", { name: "A fixed amount" }));
    await fill(page, "Fee", "1000");
    // The stepper fields (grace days, increase interval) are sliders. The
    // web engine sets no aria-valuetext or aria-valuenow on them until their
    // value changes, so their name carries the value (defect D7: a screen
    // reader heard only "Grace days, slider").
    const sliders = await page.locator('input[type="range"]').evaluateAll((inputs) =>
      inputs.map((input) => ({
        label: input.getAttribute("aria-label") ?? input.parentElement?.getAttribute("aria-label"),
        valueText: input.getAttribute("aria-valuetext"),
      })),
    );
    record("Stepper sliders", JSON.stringify(sliders));
    expect(sliders.map((slider) => slider.label)).toEqual([
      expect.stringMatching(/^Grace days, 5 days$/),
      expect.stringMatching(/^Increase every \(months\), \d+/),
    ]);
    await shot(page, "en-05-tenancy-form");
    await tap(page, "Start tenancy");
    await see(page, "Tenancy started for Tenant Uat.");
    // Three months' rent and the deposit.
    await see(page, loose("Owed now: Rs 250,000"));
    await see(page, loose("Grace days, 5 days"));
    await see(page, loose("Late fee, A fixed amount · Rs 1,000"));
    await shot(page, "en-06-tenancy");
  });

  test("J5 record a payment, see the receipt and the ledger balance", async () => {
    await tap(page, /^Open the ledger/);
    await see(page, loose("Owed now, 250000 rupees"));
    await shot(page, "en-07-ledger-before");
    await tap(page, "Record payment");
    await fill(page, "Amount received", "120000");
    await fill(page, "Reference", "UAT-CASH-1");
    await tap(page, "Record payment");
    await see(page, `Payment recorded. Receipt ${receipt1}.`);
    await expect(page).toHaveURL(/\/receipts\//);
    // Oldest first: the deposit (Rs 100,000), then Rs 20,000 of the first rent.
    await see(page, loose(`Receipt no. ${receipt1}`));
    await see(page, "Security deposit, 100000 rupees");
    await see(page, `Rent, ${months[0]}, 20000 rupees`);
    await shot(page, "en-08-receipt");
    await tap(page, "Share receipt");
    const download = page.waitForEvent("download", { timeout: 60_000 });
    await tap(page, "Share PDF");
    const pdf = await download;
    expect(pdf.suggestedFilename()).toBe(`receipt-${receipt1}.pdf`);
    const english = readFileSync(await pdf.path());
    expect(english.subarray(0, 5).toString()).toBe("%PDF-");
    expect(pdfPages(english)).toBe(1);
    if (process.env.UAT_SCREENSHOTS) {
      writeFileSync(`${process.env.UAT_SCREENSHOTS}/en-08-receipt.pdf`, english);
    }
    await tap(page, "Open the ledger");
    await see(page, loose("Owed now, 130000 rupees"));
    await see(page, loose(`Rent, ${months[0]} Rs 30,000 left of Rs 50,000`));
    await see(page, loose("Deposit held, 100000 rupees"));
    await shot(page, "en-09-ledger-after");
    // The screen's balance is the database's.
    leaseId = page.url().match(/\/money\/leases\/([0-9a-f-]{36})/)![1];
    expect(
      sql(
        `select sum(outstanding) from public.charges where lease_id = ${literal(leaseId)} and voided_at is null`,
      )[0][0],
    ).toBe("130000.00");
  });

  test("J6 late fees from the daily job", async () => {
    // The scheduled job (pg_cron) runs the same function; run it now.
    const late = lateFees;
    const first = JSON.parse(sql("select private.run_daily_jobs()")[0][0]);
    expect(first.late_fees).toBe(late);
    // Running it again the same day adds nothing.
    const again = JSON.parse(sql("select private.run_daily_jobs()")[0][0]);
    expect(again.late_fees ?? 0).toBe(0);
    await reload(page);
    for (const month of months.slice(0, late))
      await see(page, loose(`Late fee, ${month} Rs 1,000`));
    await see(page, loose(`Owed now, ${130000 + 1000 * late} rupees`));
    await shot(page, "en-10-late-fees");
    const fees = sql(
      `select count(*), sum(amount) from public.charges where lease_id = ${literal(leaseId)} and kind = 'late_fee'`,
    )[0];
    expect(fees).toEqual([String(late), `${1000 * late}.00`]);
    // The fee carries no English note after its translated kind (defect D6,
    // fixed by 20261109081109_uat_display_fixes.sql).
    expect(
      sql(
        `select count(*) from public.charges where lease_id = ${literal(leaseId)} and kind = 'late_fee' and description is not null`,
      ),
    ).toEqual([["0"]]);
    expect(await page.getByText(/·\s*Late fee\s*$/).count()).toBe(0);
  });

  test("J7 invite a second user as viewer", async ({ browser }) => {
    await openTab(page, "More");
    await tap(page, /^Team /);
    await tap(page, "Invite someone");
    await fill(page, "Their e-mail", viewer.email);
    await activate(page.getByRole("radio", { name: /^Viewer / }));
    await tap(page, "Send invitation");
    await see(page, "Invitation ready", 60_000);
    // No e-mail provider locally (RESEND_API_KEY unset): the link is shown
    // to share by hand, which is the path every landlord without e-mail
    // set up takes.
    await see(
      page,
      loose(
        `E-mail is not set up, so nothing was sent. Share the link with ${viewer.email} yourself.`,
      ),
    );
    await shot(page, "en-11-invitation");
    // The link is shared the way a landlord shares it: Copy link, then the
    // clipboard.
    await page.context().grantPermissions(["clipboard-read", "clipboard-write"]);
    await tap(page, "Copy link");
    await see(page, "Link copied.");
    const inviteUrl = await page.evaluate(() => navigator.clipboard.readText());
    expect(inviteUrl).toMatch(/^https?:\/\/[^/]+\/invite#token=[\w.-]+$/);
    // A screen reader hears the link itself, labelled (defect D3: it was an
    // empty, unlabelled field).
    const escapedUrl = inviteUrl.replace(/[.*+?^${}()|[\]\\/]/g, "\\$&");
    await see(page, new RegExp(`^\\s*Invitation link\\s+${escapedUrl}\\s*$`));
    await tap(page, "Done");

    // The viewer, in their own browser: opens the link, has no account yet.
    const context = await browser.newContext();
    viewerPage = await context.newPage();
    await open(viewerPage, inviteUrl);
    // They use the app in Urdu.
    await tap(viewerPage, "اردو میں جاری رکھیں");
    await see(viewerPage, "سائن اِن");
    await tap(viewerPage, "اکاؤنٹ بنائیں");
    await fill(viewerPage, "آپ کا نام", viewer.name);
    await fill(viewerPage, "ای میل", viewer.email);
    await fill(viewerPage, "پاس ورڈ", password);
    await shot(viewerPage, "ur-01-sign-up");
    await tap(viewerPage, "اکاؤنٹ بنائیں");
    await see(viewerPage, "اپنی ای میل دیکھیں");
    const mail = await latestMailTo(viewer.email);
    await open(viewerPage, verifyLink(mail));
    // Confirming the address brings them back to the invitation, accepted.
    await see(viewerPage, loose("UAT Rentals میں خوش آمدید"));
    await see(viewerPage, "آپ شامل ہو گئے ہیں۔ آپ کا رول: صرف دیکھنے والا۔");
    await shot(viewerPage, "ur-02-invitation-accepted");
    const role = sql(
      `select m.role from public.portfolio_members m join auth.users u on u.id = m.user_id where u.email = ${literal(viewer.email)}`,
    );
    expect(role).toEqual([["viewer"]]);
  });

  test("J8 role limits: a viewer cannot record payments", async () => {
    await tap(viewerPage, "پورٹ فولیو کھولیں");
    await openTab(viewerPage, "حساب");
    // The viewer sees the same figures as the owner, in Urdu.
    await see(viewerPage, loose(`باقی رقم ${130000 + 1000 * lateFees} روپے`));
    await tap(viewerPage, /^Tenant Uat/);
    await see(viewerPage, "ادائیگیاں");
    await shot(viewerPage, "ur-03-viewer-ledger");
    // No way to record a payment, add a charge or touch the deposit.
    for (const action of [
      "ادائیگی درج کریں",
      "چارج لگائیں",
      "باقی رقم سیکیورٹی میں سے کاٹیں",
      "سیکیورٹی واپس کریں",
    ]) {
      await expect(viewerPage.getByRole("button", { name: action })).toHaveCount(0);
    }
    // And the database refuses it even when asked directly with the
    // viewer's own session (the API the app uses).
    const refusal = await viewerPage.evaluate(
      async ({ lease, apiUrl, apikey }) => {
        const key = Object.keys(localStorage).find(
          (k) => k.startsWith("sb-") && k.endsWith("-auth-token"),
        )!;
        const session = JSON.parse(localStorage.getItem(key)!);
        const response = await fetch(`${apiUrl}/rest/v1/rpc/record_payment`, {
          method: "POST",
          headers: {
            apikey,
            Authorization: `Bearer ${session.access_token}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({
            p_lease_id: lease,
            p_amount: 1000,
            p_paid_on: new Date().toISOString().slice(0, 10),
            p_method: "cash",
            p_idempotency_key: crypto.randomUUID(),
          }),
        });
        return { status: response.status, body: await response.text() };
      },
      { lease: leaseId, apiUrl: stack.apiUrl, apikey: stack.publishableKey },
    );
    expect(refusal.status).toBe(403);
    expect(JSON.parse(refusal.body).message).toBe("forbidden");
    expect(
      sql(`select count(*) from public.payments where lease_id = ${literal(leaseId)}`),
    ).toEqual([["1"]]);
  });

  test("J9 dashboard figures match the ledger", async () => {
    await openTab(page, "Dashboard");
    await see(page, loose(`This month, ${months[2]}`));
    // The ledger, from the database: what is owed, what is overdue, and the
    // ageing buckets the dashboard draws.
    const [owed, overdue, notDue, d1to30, d31to60, d61to90, over90, monthDue, monthPaid] = sql(`
      with c as (
        select * from public.charges where lease_id = ${literal(leaseId)} and voided_at is null
      ), t as (select app.today_pkt() as d)
      select
        (select sum(outstanding) from c)::bigint,
        (select sum(outstanding) from c, t where due_date < t.d)::bigint,
        (select coalesce(sum(outstanding), 0) from c, t where due_date >= t.d)::bigint,
        (select coalesce(sum(outstanding), 0) from c, t where t.d - due_date between 1 and 30)::bigint,
        (select coalesce(sum(outstanding), 0) from c, t where t.d - due_date between 31 and 60)::bigint,
        (select coalesce(sum(outstanding), 0) from c, t where t.d - due_date between 61 and 90)::bigint,
        (select coalesce(sum(outstanding), 0) from c, t where t.d - due_date > 90)::bigint,
        (select sum(amount - waived_amount) from c, t where kind <> 'security_deposit'
           and date_trunc('month', due_date) = date_trunc('month', t.d))::bigint,
        (select sum(paid_amount) from c, t where kind <> 'security_deposit'
           and date_trunc('month', due_date) = date_trunc('month', t.d))::bigint`)[0].map(Number);
    expect(owed).toBe(130000 + 1000 * lateFees);
    const rs = (n: number) => `Rs ${n.toLocaleString("en-US")}`;
    await see(page, loose(`Overdue ${overdue} rupees`));
    await see(page, loose(`${rs(owed)} owed in all`));
    await see(page, loose(`This month's dues paid ${monthPaid} rupees of ${rs(monthDue)} due`));
    // The money that came in this month, whichever dues it paid (defect D2:
    // "Collected this month Rs 0" on the day Rs 120,000 was received).
    const [received] = sql(`
      select coalesce(sum(amount), 0)::bigint from public.payments, (select app.today_pkt() as d) t
      where lease_id = ${literal(leaseId)} and voided_at is null and method <> 'deposit_adjustment'
        and date_trunc('month', paid_on) = date_trunc('month', t.d)`)[0].map(Number);
    expect(received).toBe(120000);
    await see(page, loose(`Received this month ${received} rupees`));
    await see(
      page,
      loose(
        `${owed} rupees owed: ${notDue} not yet due, ${d1to30} up to 30 days late, ` +
          `${d31to60} 31 to 60 days late, ${d61to90} 61 to 90 days late, ${over90} over 90 days late.`,
      ),
    );
    await see(page, loose("Units let 1 of 1"));
    await see(page, loose("Deposits held, 100000 rupees"));
    await shot(page, "en-12-dashboard");
  });

  test("J10 upload a document to private storage, then delete it", async () => {
    await openTab(page, "Tenants");
    // The list itself, not the dashboard J9 left behind: both name the tenant,
    // and the dashboard's entry opens the statement under Money instead.
    await see(page, "Add tenant");
    await tap(page, /^Tenant Uat/);
    await see(page, "No documents yet. Add photos of the CNIC, front and back.");
    await tap(page, "Add document");
    // The browser's file dialog needs a real click (a user gesture).
    const chooser = page.waitForEvent("filechooser");
    await button(page, "Choose a file").click();
    await (
      await chooser
    ).setFiles({ name: "cnic-front.png", mimeType: "image/png", buffer: samplePng() });
    // Photos are encoded again as JPEG on the device (which drops metadata).
    await see(page, loose("JPEG photo"));
    await see(page, loose("Kind CNIC, front"));
    await shot(page, "en-13-document-upload");
    await tap(page, "Upload");
    // Named after the file when no name is typed.
    await see(page, "cnic-front added.");
    const documentRow = `
      from public.documents d
      join public.leases l on l.tenant_id = d.entity_id and l.id = ${literal(leaseId)}
      left join storage.objects o on o.bucket_id = 'documents' and o.name = d.storage_path
      where d.entity_type = 'tenant'`;
    const [storagePath, rowMime, objectMime, kind] = sql(
      `select d.storage_path, d.mime_type, o.metadata->>'mimetype', d.kind ${documentRow}`,
    )[0];
    expect([rowMime, objectMime, kind]).toEqual(["image/jpeg", "image/jpeg", "cnic_front"]);
    // The bucket is private: the file is not served without a signed link.
    const anonymous = await fetch(
      `${stack.apiUrl}/storage/v1/object/public/documents/${storagePath}`,
    );
    expect(anonymous.ok).toBe(false);
    await tap(page, /^cnic-front CNIC, front/);
    await see(page, loose("Kind, CNIC, front"));
    // Download goes through a short-lived signed link.
    const download = page.waitForEvent("download", { timeout: 60_000 });
    await tap(page, "Download");
    const file = await download;
    expect(file.suggestedFilename()).toBe("cnic-front.jpg");
    expect([...readFileSync(await file.path()).subarray(0, 3)]).toEqual([0xff, 0xd8, 0xff]);
    await tap(page, "Delete");
    const confirm = page.getByRole("alertdialog");
    await see(page, "Delete cnic-front?");
    await tap(confirm, "Delete");
    await see(page, "cnic-front deleted.");
    await see(page, "No documents yet. Add photos of the CNIC, front and back.");
    // The row is gone at once; the file is queued for the storage-cleanup
    // function (pg_cron calls it every 10 minutes; here it is called now).
    expect(sql(`select count(*) ${documentRow}`)).toEqual([["0"]]);
    expect(
      sql(
        `select count(*) from private.storage_cleanup_queue where bucket_id = 'documents' and path = ${literal(storagePath)}`,
      ),
    ).toEqual([["1"]]);
    const cleanup = await fetch(`${stack.apiUrl}/functions/v1/storage-cleanup`, {
      method: "POST",
      headers: { "content-type": "application/json", "x-cleanup-token": stack.cleanupToken },
      body: "{}",
    });
    expect(cleanup.status).toBe(200);
    expect(
      sql(
        `select count(*) from storage.objects where bucket_id = 'documents' and name = ${literal(storagePath)}`,
      ),
    ).toEqual([["0"]]);
  });

  test("J11 end the tenancy", async () => {
    await tap(page, /^Ground floor, Gulberg House/);
    await tap(page, "End tenancy");
    await see(page, loose("Rent is billed through the month of moving out."));
    await shot(page, "en-14-end-tenancy");
    // Moving out today: the "End tenancy" button of the sheet, not the page's.
    await activate(page.getByRole("button", { name: "End tenancy", exact: true }).last());
    await see(page, "Tenancy ended.");
    await see(
      page,
      loose(
        `Ended on, ${new Intl.DateTimeFormat("en-GB", { day: "numeric", month: "short", year: "numeric" }).format(today)}`,
      ),
    );
    await see(page, loose("Why, The tenant moved out"));
    expect(
      sql(
        `select status, moved_out_on = app.today_pkt() from public.leases where id = ${literal(leaseId)}`,
      ),
    ).toEqual([["ended", "t"]]);
    // The unit is vacant again.
    await tap(page, /^Ground floor Unit/);
    await see(page, loose("Vacant since"));
    await shot(page, "en-15-unit-vacant");
  });

  test("J12 the owner switches to Urdu: dashboard and an Urdu receipt", async () => {
    await openTab(page, "More");
    // The More tab comes back where it was left: the Team screen of J7,
    // refreshed: the accepted invitation is no longer waiting and the viewer
    // is a member (defect D4: it stayed stale until opened again).
    await see(page, "Team");
    await see(page, loose(`Viewer Uat Viewer · ${viewer.email}`));
    await expect(page.getByText("Invitations waiting for an answer")).toHaveCount(0);
    await tap(page, "Back");
    await tap(page, /^Settings /);
    await tap(page.getByRole("group", { name: "Language" }), "اردو");
    await see(page, "سیٹنگز");
    expect(
      sql(
        `select p.locale from public.profiles p join auth.users u on u.id = p.id where u.email = ${literal(owner.email)}`,
      ),
    ).toEqual([["ur"]]);
    // The whole UI turns right to left.
    // The page declares Urdu to assistive technology (Flutter sets <html lang>).
    expect(await page.evaluate(() => document.documentElement.lang)).toBe("ur");
    await shot(page, "ur-04-settings");

    await openTab(page, "ڈیش بورڈ");
    await see(
      page,
      loose(`کل باقی رقم ${(130000 + 1000 * lateFees).toLocaleString("en-US")} روپے`),
    );
    await shot(page, "ur-05-dashboard");

    // The Money tab is still on the tenancy's ledger, now in Urdu.
    await openTab(page, "حساب");
    await see(page, loose(`ابھی باقی، ${130000 + 1000 * lateFees} روپے`));
    await shot(page, "ur-06-ledger");
    await tap(page, new RegExp(`^120,000 روپے رسید ${receipt1}`));
    await tap(page, "رسید بھیجیں");
    await activate(page.getByRole("radio", { name: "اردو" }));
    const download = page.waitForEvent("download", { timeout: 60_000 });
    await tap(page, "پی ڈی ایف بھیجیں");
    const pdf = await download;
    expect(pdf.suggestedFilename()).toBe(`receipt-${receipt1}.pdf`);
    const bytes = readFileSync(await pdf.path());
    expect(bytes.subarray(0, 5).toString()).toBe("%PDF-");
    // One A5 page, like the English one (defect D8: the footer line spilled
    // on to a second page).
    expect(pdfPages(bytes)).toBe(1);
    if (process.env.UAT_SCREENSHOTS) {
      writeFileSync(`${process.env.UAT_SCREENSHOTS}/ur-07-receipt.pdf`, bytes);
    }
  });

  test("J13 settle the deposit after the tenancy ends (Urdu)", async () => {
    await tap(page, "حساب کھولیں");
    await tap(page, "باقی رقم سیکیورٹی میں سے کاٹیں");
    await see(
      page,
      loose(`جمع: 100,000 روپے۔ ذمے باقی: ${(130000 + 1000 * lateFees).toLocaleString("en-US")} روپے۔`),
    );
    await fill(page, "رقم", "100000");
    await shot(page, "ur-08-apply-deposit");
    await activate(
      page.getByRole("button", { name: "باقی رقم سیکیورٹی میں سے کاٹیں", exact: true }).last(),
    );
    await see(page, "سیکیورٹی میں سے 100,000 روپے باقی رقم میں کٹ گئے۔");
    // Oldest first: the rest of the first rent, the second, then part of
    // this month's; the deposit is used up and a second receipt is issued.
    await see(page, loose(`ابھی باقی، ${30000 + 1000 * lateFees} روپے`));
    await see(page, loose("اب جمع سیکیورٹی، 0 روپے"));
    await see(page, loose(`100,000 روپے رسید MM-${year}-00002`));
    await shot(page, "ur-09-deposit-applied");
    expect(
      sql(
        `select sum(outstanding)::bigint from public.charges where lease_id = ${literal(leaseId)} and voided_at is null`,
      ),
    ).toEqual([[String(30000 + 1000 * lateFees)]]);
  });

  test("J14 account deletion: the viewer, then the owner", async () => {
    // A plain sign-out first: the browser forgets the account and keeps the
    // language; the viewer then signs in again.
    await openTab(viewerPage, "مزید");
    await tap(viewerPage, /^سیٹنگز /);
    await tap(viewerPage, "سائن آؤٹ کریں");
    await expect(viewerPage).toHaveURL(/\/sign-in$/);
    await expectAccountForgotten(viewerPage);
    await fill(viewerPage, "ای میل", viewer.email);
    await fill(viewerPage, "پاس ورڈ", password);
    await tap(viewerPage, "سائن اِن کریں");
    await expect(viewerPage).not.toHaveURL(/\/sign-in$/);
    await openTab(viewerPage, "مزید");
    await tap(viewerPage, /^سیٹنگز /);
    await tap(viewerPage, "اکاؤنٹ ڈیلیٹ کریں");
    // Not the only owner of anything: no portfolio goes with the account.
    await see(
      viewerPage,
      loose("آپ کسی پورٹ فولیو کے اکیلے مالک نہیں، اس لیے کوئی پورٹ فولیو ڈیلیٹ نہیں ہو گا۔"),
    );
    await fill(viewerPage, "پاس ورڈ", password);
    await fill(viewerPage, /^تصدیق کے لیے/, viewer.email);
    await shot(viewerPage, "ur-10-delete-account");
    await tap(viewerPage, "میرا اکاؤنٹ ڈیلیٹ کریں");
    await see(viewerPage, loose("آپ کا اکاؤنٹ ڈیلیٹ ہو گیا ہے"), 60_000);
    await expect(viewerPage).toHaveURL(/\/sign-in$/);
    await expectAccountForgotten(viewerPage);
    expect(sql(`select count(*) from auth.users where email = ${literal(viewer.email)}`)).toEqual([
      ["0"],
    ]);
    const portfolio =
      sql(`select p.id from public.portfolios p join public.portfolio_members m on m.portfolio_id = p.id
      join auth.users u on u.id = m.user_id where u.email = ${literal(owner.email)}`);
    expect(portfolio.length).toBe(1);
    expect(
      sql(
        `select count(*) from public.portfolio_members where portfolio_id = ${literal(portfolio[0][0])}`,
      ),
    ).toEqual([["1"]]);

    // The owner, the only owner of UAT Rentals: the portfolio goes too.
    // (The More tab is still on Settings, where J12 left it.)
    await openTab(page, "مزید");
    await tap(page, "اکاؤنٹ ڈیلیٹ کریں");
    await see(
      page,
      loose("آپ اس پورٹ فولیو کے اکیلے مالک ہیں، اس لیے یہ اپنی ہر چیز سمیت ڈیلیٹ ہو جائے گا"),
    );
    const portfolioId = portfolio[0][0];
    await fill(page, "پاس ورڈ", password);
    await fill(page, /^تصدیق کے لیے/, owner.email);
    await shot(page, "ur-11-delete-owner");
    await tap(page, "میرا اکاؤنٹ ڈیلیٹ کریں");
    await see(page, loose("آپ کا اکاؤنٹ ڈیلیٹ ہو گیا ہے"), 60_000);
    await expect(page).toHaveURL(/\/sign-in$/);
    await expectAccountForgotten(page);
    // The user, the portfolio and everything in it are gone.
    expect(sql(`select count(*) from auth.users where email = ${literal(owner.email)}`)).toEqual([
      ["0"],
    ]);
    for (const table of [
      "portfolios",
      "leases",
      "tenants",
      "properties",
      "payments",
      "charges",
      "documents",
    ]) {
      const column = table === "portfolios" ? "id" : "portfolio_id";
      expect(
        sql(`select count(*) from public.${table} where ${column} = ${literal(portfolioId)}`),
        table,
      ).toEqual([["0"]]);
    }
  });
});
