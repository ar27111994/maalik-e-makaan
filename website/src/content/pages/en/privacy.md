---
title: "Privacy"
description: "How this website and the Maalik-e-Makaan app treat your data: no cookies or trackers on the site, and in the app, your records seen only by the people you invite."
lastUpdated: 2026-11-12
---

## In short

- This website sets no cookies, uses no analytics or trackers and loads nothing from other sites.
- The calculators work inside your browser. Nothing you type into them leaves your device.
- In the app, your records are yours. Only the people you invite can see them, as far as their role allows. They are never sold, and never used for advertising.

## This website

The site is a set of plain pages. Its fonts and images are served from the site itself, so your browser contacts no one else while you read it.

Like every website, its pages are delivered by a hosting provider, [Vercel](https://vercel.com/legal/privacy-policy), whose servers necessarily receive the technical details of each request, such as your IP address and the page asked for. We do not add any tracking to that, and we do not use it to identify you.

## The app

This section describes version 1.0 of the app, released on 9 November 2026, and the versions after it. If anything here changes, this page will show the new date at the top.

### What it stores

- **Your account:** your email address, your name, your phone number if you give one, and your choice of language. The sign-in service, Supabase Auth, also keeps a scrambled (hashed) form of your password and sign-in details such as when you last signed in.
- **What you enter:** your properties and units; your tenants' details (such as names, CNIC numbers, phone numbers and references); tenancies, rent, payments, receipts, expenses, utility bills and meter readings; and any photos or documents you attach.
- **Reminders:** a log of each WhatsApp reminder you open from the app: when, to which tenancy, in which language, and the message itself, up to its first 1,000 characters.
- **Who did what:** an audit trail of changes to the records and the money, with who made each one and when, so that an owner can trust what a caretaker records. CNIC numbers are not written into that trail.

### Where it is kept, and who can see it

- The records are kept in a database run by [Supabase](https://supabase.com/privacy), in its Mumbai (ap-south-1) region.
- Each portfolio's records are kept apart in the database. Only the people you invite to a portfolio can reach them, and each person only as far as their role allows.
- CNIC numbers are masked on screen by default.
- Identity documents and photos are held in private storage, and are opened only through links that expire after a short time.
- The app's emails, such as the link that confirms your address, a password reset and invitations to join a portfolio, are sent through [Resend](https://resend.com/legal/privacy-policy), which receives the recipient's address and the message.
- In a web browser, the app carries its own fonts. When a text needs a character they lack, such as an emoji or a letter of another script, the browser downloads a font for it from [Google Fonts](https://policies.google.com/privacy) (fonts.gstatic.com). Google then receives your IP address and which font was asked for, but not your text. The app on Android and iPhone does not do this.
- WhatsApp reminders open in WhatsApp on your own phone and are sent by you, from your number. The app does not send them for you, and does not read your WhatsApp.

The app has no advertising, no analytics and no trackers.

### Your tenants' details

When you record a tenant, you hold their personal details. The app asks you to record the tenant's consent, the date it was given and its purpose. Collect only what you need, such as what the police registration asks for, and keep it up to date.

### How long it is kept

Your records are kept until you delete them, or delete your account. Version 1.0 does not delete identity documents automatically when a tenancy ends; that is planned for a later version. Financial records that are cancelled are kept, marked as cancelled, so that the receipt series stays complete.

Once a week an encrypted copy of the database, with the photos and documents, is made so that the records can be restored after a mistake or an outage. An automated job on [GitHub](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement)'s servers makes it and encrypts it there, so that only the person who runs the app can open it, and GitHub keeps it for 90 days. Something you delete can stay in these copies until they expire, at most 90 days later.

### Deleting your account

You can delete your account from inside the app, in Settings. Deletion removes your account and every portfolio in which you are the only owner, with its records and files, and removes you from portfolios that others own.

## Who runs it, and how to reach us

The website and the app are run by **AR LABS (SMC-PRIVATE) LIMITED**, a company registered with the Securities and Exchange Commission of Pakistan (CUIN 0361950), which decides how this data is used. Write to us at [maalik-e-makaan@news.ar27111994.dev](mailto:maalik-e-makaan@news.ar27111994.dev) about your data, to correct it or to have it deleted.

## Questions

The code of this website and the app is public, so anyone can check what it does. Ask a question, or report a problem, on the project's [GitHub page](https://github.com/ar27111994/maalik-e-makaan/issues). Report a security problem privately, as our [security policy](https://github.com/ar27111994/maalik-e-makaan/security/policy) explains.
