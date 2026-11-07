# Website facts: police registration, tenancy, rental tax, utilities and increments (Pakistan)

**Last reviewed 2026-11-05.** This is the fact base for the public website (WEB-01 to WEB-03). It is
informational research, not legal or tax advice. It corrects and extends
[`legal-tax-formats.md`](legal-tax-formats.md); §7 lists every correction.

## 0. Method, limits and how to read this file

**What I could reach on 2026-11-05.**

- WebFetch failed with `getaddrinfo ENOTFOUND` for `punjablaws.gov.pk` and `www.fbr.gov.pk`. The tool
  said to stop trying further hosts, so I did not fetch any page in full.
- `curl` through the session proxy got `CONNECT tunnel failed, response 403` for `www.fbr.gov.pk`, and
  `000` (proxy `connect_rejected`) for every official host I tried:
  - punjablaws, punjabcode, pakistancode, FBR, Punjab and Sindh police;
  - kpcode, pakp, balochistan.gov.pk, islamabadpolice;
  - nepra, ogra, sngpl, ssgc;
  - the LHC, SHC, IHC and Supreme Court sites.
- Only `registry.npmjs.org` answered.
- WebSearch (server-side) worked. I ran about 45 searches, most of them restricted to official
  domains (`fbr.gov.pk`, `download1.fbr.gov.pk`, `kpcode.kp.gov.pk`, `pas.gov.pk`, `sindhlaws.gov.pk`,
  `pakistancode.gov.pk`, `nepra.org.pk`, `sngpl.com.pk`, `islamabadpolice.gov.pk`, court sites and others).

**So every statement below rests on the search engine's excerpt of the cited page, not on a full
reading.** Where the excerpt quoted statutory wording, I say "text excerpt". The s.155 worked
examples and the proration examples come from a local script:
`/tmp/claude-0/-home-user-maalik-e-makaan/65cec986-d5bd-5e66-96c4-4b2ed1d37e27/scratchpad/website/s155_vectors.py`,
run with `python3 -I`. The output is reproduced in §3.6 and §5.3.

**Access date.** Every source below was accessed on **2026-11-05** through WebSearch.

**Confidence.**

- **High:** an official text excerpt (statute, gazette, FBR card or official portal), corroborated by
  a second independent source, with no conflicting source found.
- **Medium:** one official excerpt, or several reputable secondary sources (KPMG, PwC, Dawn) that
  agree, or an official excerpt with a minor conflict.
- **Low:** secondary sources only, sources in conflict, or absence of evidence.

`legislation.pk` and `nasirlawsite.com` are private reproductions of statutes, not official sources.
I use them only to corroborate.

**Rules for the website that follow from this file**

1. Every legal or tax page shows "Last reviewed 2026-11-05". It says plainly that it is not legal or
   tax advice, and it cites the official source inline next to each claim.
2. State the law, not the app's defaults. Since migration `20261107172908_police_registration_rules`
   the app follows §1 (`app.police_registration_rule`: KP 7 calendar days and Balochistan 3 days from
   the agreement), but for ICT, which has no statutory deadline, it still shows its own 1-day
   reminder, flagged `statutory = false` (§1).
3. Never estimate final income tax (D-10). The s.155 calculator shows **withholding only**, labelled
   "adjustable, not your final tax".
4. Do not publish figures this file marks **Low** or **UNVERIFIED**. In particular, do not publish
   lease stamp-duty amounts, the "4% deemed commercial rent" rule, or a "Punjab 10% default increase".
5. Where sources conflict (Low), say so in the copy rather than picking one.

---

## 1. Police tenant registration

### 1.1 Summary for the site

| Jurisdiction | Law | Who must report | Deadline (law) | Clock starts | Penalty | Channels |
|---|---|---|---|---|---|---|
| Punjab | Punjab Information of Temporary Residents Act 2015 | property dealer, landlord and tenant (one report discharges all) | 15 days | delivery of possession | knowing breach: up to 6 months' imprisonment and a fine of Rs 10,000–100,000; cognizable, non-bailable | online TRS, police station, Police Khidmat Markaz |
| Sindh | Sindh Information of Temporary Residents Act 2015 (Sindh Act XXI of 2015) | property dealer, landlord and tenant | 48 hours | delivery of possession | knowing breach: up to 6 months' imprisonment and a fine of Rs 10,000–45,000; cognizable, non-bailable | TRUST portal, police station, facilitation centre |
| Khyber Pakhtunkhwa | KP Restriction of Rented Buildings (Security) Act 2014 (Act XIV of 2014) | landlord, lessee or manager, and the property dealer if any | 7 days, excluding public holidays | signing of the agreement | up to 1 year's imprisonment, or a fine, or both; cognizable, non-bailable | in person at the police station (TIF form); no online portal found |
| Balochistan | Balochistan Restrictions of Rented Buildings (Security) Act 2015 | landlord, lessee or manager, and the property dealer if any | 3 days | signing of the agreement | up to 1 year's imprisonment, or a fine, or both | in person to the SHO of the police station or Levies thana (Form-I); no online portal found |
| Islamabad (ICT) | no statute found; past District Magistrate orders under s.144 CrPC | landlord (as the ICT Police describe it) | none fixed by statute | — | under the s.144 order in force, if any | ICT Police online form, Police Khidmat Markaz, police station |

### 1.2 Punjab

- **PB-1.** The Punjab Information of Temporary Residents Act 2015 governs this. It replaced the Punjab
  Information of Temporary Residents Ordinance 2015 (Ordinance II of 2015).
  - Sources: [punjablaws.gov.pk/laws/2591](http://punjablaws.gov.pk/laws/2591.html) (text excerpt);
    [Punjab Police copy of the Ordinance](https://dporjp.punjabpolice.gov.pk/system/files/PUNJAB%20INFORMATION%20OF%20TEMPORARY%20RESIDENTS%20ORDINANCE%202015.doc_.pdf).
  - Accessed 2026-11-05. Confidence: **High**.
- **PB-2.** Under s.3(1), the property dealer, landlord and tenant must provide information about the
  tenant to the police, in the prescribed manner, **within fifteen days from the time of delivery of
  possession** of the rented premises to the tenant. If any one of the concurrently responsible
  persons provides the information, the others are not liable.
  - Sources: [punjablaws.gov.pk/laws/2591](http://punjablaws.gov.pk/laws/2591.html) (text excerpt);
    corroborated by [Dawn](https://www.dawn.com/news/1317260) and [Pakera](https://pakera.pk/punjab-tenant-registration-police/).
  - Accessed 2026-11-05. Confidence: **High**.
- **PB-3.** Under s.11, a person who **knowingly** contravenes the Act, or fails to allow access or to
  give information to the police, is liable to imprisonment of up to six months and a fine of **not
  less than Rs 10,000 and not more than Rs 100,000**.
  - Older summaries say "fine up to Rs 10,000"; the enacted text excerpt contradicts them.
  - Sources: [punjablaws.gov.pk/laws/2591](http://punjablaws.gov.pk/laws/2591.html) (text excerpt);
    the [Ordinance PDF](https://dporjp.punjabpolice.gov.pk/system/files/PUNJAB%20INFORMATION%20OF%20TEMPORARY%20RESIDENTS%20ORDINANCE%202015.doc_.pdf) has the same wording.
  - Accessed 2026-11-05. Confidence: **High**.
- **PB-4.** Under s.12 the offence is cognizable and non-bailable. Under s.13 the Government or an
  authorised officer may compound it, subject to an administrative penalty of at least Rs 10,000. It
  cannot be compounded if the accused was previously convicted under the Act, or a previous offence was
  compounded.
  - Source: [punjablaws.gov.pk/laws/2591](http://punjablaws.gov.pk/laws/2591.html) (text excerpt).
  - Accessed 2026-11-05. Confidence: **High**.
- **PB-5.** Hotels and guest houses: the owner or manager reports a guest within 24 hours of arrival.
  This is context only, not for the landlord guide.
  - Source: [punjablaws.gov.pk/laws/2591](http://punjablaws.gov.pk/laws/2591.html) (text excerpt).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **PB-6.** Channels:
  - the online Tenant Registration System, which the Punjab Police TRS page points to as
    `trs.punjabpolice.gov.pk`;
  - in person at the nearest police station or Police Khidmat Markaz;
  - a PKM kiosk form exists.
  - Sources: [Punjab Police TRS](https://punjabpolice.gov.pk/trs), [PKM services](https://pkm.punjab.gov.pk/public/app/our_services?id=i),
    [PKM kiosk form](https://kiosk.pkm.punjabpolice.gov.pk/tenants/create), [PITB TRS](https://pitb.gov.pk/trs).
  - Accessed 2026-11-05. Confidence: **Medium** (official pages, undated).
- **PB-7.** Documents for in-person registration, per Lahore Police:
  - the house owner's CNIC (original and copy);
  - the tenant's CNIC (original and copy);
  - the rent agreement (original and copy);
  - an affidavit;
  - a photograph of the tenant.

  The TRS page also lists owner and tenant photographs. The same Lahore page gives the processing fee as
  **free**, with on-the-spot registration in about 15–20 minutes. No source states a fee for the online
  route.
  - Sources: [Lahore Police tenants registration](https://lahorepolice.punjab.gov.pk/tenants-registration),
    [Lahore Police tenants/employee registration](https://lahorepolice.punjab.gov.pk/tenants-employee-registration),
    [Punjab Police TRS](https://punjabpolice.gov.pk/trs).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **PB-8.** The previous brief said s.5 obliges the landlord to check the tenant's CNIC or passport and
  give a copy to police. I did not see this in today's Punjab excerpts; the Sindh equivalent is SD-4.
  Confidence: **Medium** (carried over, not re-verified).

### 1.3 Sindh

- **SD-1.** The Sindh Information of Temporary Residents Act 2015 is Sindh Act No. XXI of 2015,
  notified on 18 May 2015. Section 15 makes it prevail over conflicting law, and s.16 repealed the 2015
  Ordinance.
  - Sources: [Provincial Assembly of Sindh gazette PDF](https://www.pas.gov.pk/uploads/acts/Sindh%20Act%20No.XXI%20of%202015.pdf),
    [legislation.pk copy](https://www.legislation.pk/browse-legislation/sindh-legislation/30-the-sindh-information-of-temporary-residents-2015).
  - Accessed 2026-11-05. Confidence: **High**.
- **SD-2.** Under s.3(1), the property dealer, landlord and tenant must give the tenant's details to the
  police **within 48 hours of delivery of possession**. Hotel and guest-house managers report guests
  within **3 hours** of check-in.
  - Sources: [PAS gazette PDF](https://www.pas.gov.pk/uploads/acts/Sindh%20Act%20No.XXI%20of%202015.pdf) and
    [legislation.pk](https://www.legislation.pk/browse-legislation/sindh-legislation/30-the-sindh-information-of-temporary-residents-2015) (text excerpts);
    [Dawn on the bill's passage](https://www.dawn.com/news/1175771).
  - Accessed 2026-11-05. Confidence: **High**.
- **SD-3.** The previous brief said that under s.3(3) one person's report covers the others. Today's
  excerpts did not show this. Confidence: **Medium** (carried over).
- **SD-4.** A landlord, manager or property dealer may not let a tenant or guest stay unless the CNIC or
  passport has been checked, and must give a copy to the police. A Sub-Inspector or above may inspect
  rented premises on reasonable notice. Police enforce the Act through spot inspections and local
  verification.
  - Source: [PAS gazette PDF](https://www.pas.gov.pk/uploads/acts/Sindh%20Act%20No.XXI%20of%202015.pdf) (text excerpt).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **SD-5.** Under s.11, a person who knowingly contravenes ss.3, 4, 5 or 8, or fails to allow access or
  give information under s.7 or s.10, is "liable to punishment of imprisonment which may extend to six
  months **and** fine which shall not be less than ten thousand rupees or more than forty five thousand
  rupees". Under s.12 the offence is cognizable and non-bailable.
  - Sources: [PAS gazette PDF](https://www.pas.gov.pk/uploads/acts/Sindh%20Act%20No.XXI%20of%202015.pdf) (text excerpt);
    [Dawn](https://www.dawn.com/news/1175771).
  - Accessed 2026-11-05. Confidence: **High**.
- **SD-6.** Channels:
  - **TRUST** (Tenant Registration for Urban Security and Tracking) at `tenantregister.sindhpolice.gov.pk`.
    Sign-in is by email or CNIC. The Sindh Police Services Portal app lists it.
  - In person at the police station or a facilitation centre. Karachi Police say a certificate is
    issued after successful registration at a police station.
  - Online launch reported on 18 December 2025.
  - Sources: [TRUST](https://tenantregister.sindhpolice.gov.pk/), [TRUST login](https://tenantregister.sindhpolice.gov.pk/login),
    [Sindh Police Services Portal app](https://play.google.com/store/apps/details?id=com.sindhpolice.servicesportal),
    [Karachi Police](https://karachipolice.gov.pk/services/how-to-apply-for-tenant-registration-process/),
    [ProPakistani 2025-12-18](https://propakistani.pk/2025/12/18/sindh-makes-tenant-registration-easier/).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **SD-7.** Documents (owner and tenant CNICs, rent agreement, affidavit, photo) and a **free** fee are
  stated only by a secondary guide. An online submission goes to the police station for verification.
  - Source: [Pakera](https://pakera.pk/sindh-tenant-registration-police/).
  - Accessed 2026-11-05. Confidence: **Low**.

### 1.4 Khyber Pakhtunkhwa

- **KP-1.** The law is the Khyber Pakhtunkhwa Restriction of Rented Buildings (Security) Act 2014 (Act
  No. XIV of 2014). It began as an Ordinance in 2014.
  - Sources: [KP Code PDF](https://kpcode.kp.gov.pk/uploads/2014_14_THE_KHYBER_PAKHTUNKHWA_RENTED_BUILDINGS_SECURITY_ACT_2014.pdf),
    [KP Code entry](https://kpcode.kp.gov.pk/homepage/lawDetails/658),
    [KP Assembly PDF](https://www.pakp.gov.pk/wp-content/uploads/2024/05/The-Khyber-Pakhtunkhwa-Restriction-of-Rented-Buildings-Security-Act-2014-Act-No.-XIV-2014.pdf),
    [Dawn](https://www.dawn.com/news/1317260).
  - Accessed 2026-11-05. Confidence: **High**.
- **KP-2.** Under s.4(1), the landlord, lessee or manager (and the property dealer, if one is involved)
  must give the prescribed information to the police station "**within seven days excluding public
  holidays of signing of the agreement**".
  - Sources: [legislation.pk copy](https://www.legislation.pk/browse-legislation/kpk-legislation/32-the-khyber-pakhtunkhwa-restriction-of-rented-buildings--security-act-2014) (text excerpt);
    the search attributed the same s.4 list to the [KP Code PDF](https://kpcode.kp.gov.pk/uploads/2014_14_THE_KHYBER_PAKHTUNKHWA_RENTED_BUILDINGS_SECURITY_ACT_2014.pdf).
  - Accessed 2026-11-05. Confidence: **Medium**: the seven-day wording is seen in the private copy
    only, so confirm it against the KP Code PDF.
- **KP-3.** The information required:
  - an attested copy of the rent agreement;
  - an attested copy of the tenant's CNIC;
  - the names, CNIC copies and contact numbers of **two references** who identify the tenant;
  - particulars of **male members over 14** living with the tenant.
  - Source: [KP Code PDF](https://kpcode.kp.gov.pk/uploads/2014_14_THE_KHYBER_PAKHTUNKHWA_RENTED_BUILDINGS_SECURITY_ACT_2014.pdf) (text excerpt, items (a)–(d)).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **KP-4.** The receipt and inspection process:
  - Once satisfied, the station in-charge issues a "**tenant acknowledgment receipt**" (TAR) and enters
    it in the Daily Diary.
  - Under s.6 the police may call for the ownership papers, the rent agreement and the TAR from any
    tenant, who must produce them **within 24 hours**.
  - Sources: [KP Code PDF](https://kpcode.kp.gov.pk/uploads/2014_14_THE_KHYBER_PAKHTUNKHWA_RENTED_BUILDINGS_SECURITY_ACT_2014.pdf),
    [legislation.pk](https://www.legislation.pk/browse-legislation/kpk-legislation/32-the-khyber-pakhtunkhwa-restriction-of-rented-buildings--security-act-2014).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **KP-5.** Penalties:
  - Under s.10(1), whoever contravenes ss.3–6 "shall be punished with imprisonment which may extend to
    **one year** or with fine or with both". No fine amount is stated.
  - Under s.10(2), a landlord, lessee, manager or property dealer who was aware of the tenant's criminal
    designs, or did not use due care in verifying the tenant's credentials, may be charged with abetment.
  - Under s.12 the offence is cognizable and non-bailable, and is tried by a Judicial Magistrate of the
    First Class.
  - Sources: [KP Code PDF](https://kpcode.kp.gov.pk/uploads/2014_14_THE_KHYBER_PAKHTUNKHWA_RENTED_BUILDINGS_SECURITY_ACT_2014.pdf),
    [legislation.pk](https://www.legislation.pk/browse-legislation/kpk-legislation/32-the-khyber-pakhtunkhwa-restriction-of-rented-buildings--security-act-2014) (text excerpts).
  - Conflict: a 2014-era [Dawn report](https://www.dawn.com/news/1317260) says six months and a fine of
    Rs 10,000–100,000. The [IRB](https://www.ecoi.net/en/document/1424022.html) says up to one year in KP.
  - Accessed 2026-11-05. Confidence: **Medium**.
- **KP-6.** Channel: in person at the local police station. KP Police publish the Tenant Information Form
  (TIF-1-2014) and the TAR. Peshawar Police tell tenants to register and obtain an NOC from the local
  police. **No online KP portal was found.**
  - Sources: [KP Police TIF form](https://www.kppolice.gov.pk/photos/cba.pdf), [KP Police forms](https://www.kppolice.gov.pk/viewer.php?pid=84),
    [Peshawar Police tenants](https://www.peshawarpolice.gov.pk/tenant.php), [Peshawar Police downloads](http://peshawarpolice.gov.pk/tenant_downloads.php).
  - Accessed 2026-11-05. Confidence: **Medium**.

### 1.5 Balochistan

- **BL-1.** The law is the Balochistan Restrictions of Rented Buildings (Security) Act 2015.
  - Source: [Balochistan Code PDF](http://balochistancode.gob.pk/lawdir/404fb117-5e1b-4040-a6a6-2b88c2369f3a.pdf).
  - Accessed 2026-11-05. Confidence: **High**.
- **BL-2.** The landlord, lessee or manager (and any property dealer) must give the information to the
  Officer Incharge "**within three days of signing of the agreement on Form-I** of the schedule". The
  Officer Incharge is the SHO of the police station **or Levies thana** for the building.
  - Source: [Balochistan Code PDF](http://balochistancode.gob.pk/lawdir/404fb117-5e1b-4040-a6a6-2b88c2369f3a.pdf) (text excerpt).
  - Conflict: a [LUMS analysis](https://sahsol.lums.edu.pk/node/12877) says fifteen days for the
    Balochistan and KP Acts. A secondary guide agrees with three days:
    [Pakera](https://pakera.pk/register-tenant-balochistan-police-levies-3-days-form-i/).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **BL-3.** The package includes an attested copy of the rent agreement and an attested copy of the
  tenant's CNIC. Police issue a tenant acknowledgment receipt.
  - Source: [Balochistan Code PDF](http://balochistancode.gob.pk/lawdir/404fb117-5e1b-4040-a6a6-2b88c2369f3a.pdf) (text excerpt).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **BL-4.** Contravening ss.3–6 is punishable with imprisonment of up to one year, or a fine, or both.
  - Source: [Balochistan Code PDF](http://balochistancode.gob.pk/lawdir/404fb117-5e1b-4040-a6a6-2b88c2369f3a.pdf) (text excerpt).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **BL-5.** In April 2026 the provincial government made registration mandatory province-wide, including
  Quetta. An aide to the home department, Babar Khan Yousafzai, announced it.
  - Officials warned of cases being registered and "possible sealing of the property". I did not find a
    sealing power in the Act's text, so present sealing as the officials' warning, not the law.
  - Guests staying more than 24 hours must be reported.
  - Sources: [Dawn](https://www.dawn.com/news/1991809), [ProPakistani 2026-04-15](https://propakistani.pk/2026/04/15/balochistan-makes-tenant-registration-mandatory/).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **BL-6.** No online channel was found. Registration is in person.
  - Sources: as BL-2.
  - Accessed 2026-11-05. Confidence: **Low** (absence of evidence).

### 1.6 Islamabad Capital Territory

- **ICT-1.** **No ICT statute on tenant registration was found.** The duty has been imposed through
  District Magistrate orders under s.144 CrPC for fixed periods. One such order (reported about 2022)
  barred property dealers, brokers and owners from renting out property for two months without giving
  tenant details to the police.
  - No tenant-specific s.144 order for 2026 was found. The 2026 s.144 orders I found (March 2026, and
    18 September 2026 for two months) cover public gatherings.
  - Sources: [Dawn, owners told to inform police](https://www.dawn.com/news/1667666/owners-told-to-inform-police-before-renting-houses-in-capital),
    [Dawn, s.144 Sept 2026](https://www.dawn.com/news/2032130/section-144-imposed-in-islamabad-district-admin-warns-citizens-against-participating-in-any-illegal-activity),
    [Business Recorder, March 2026](https://www.brecorder.com/news/40409620/section-144-enforced-in-ict-all-gatherings-banned).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **ICT-2.** ICT Police say tenant registration is **mandatory for all tenants** in ICT. Channels: the
  online form on the ICT Police site, any Police Khidmat Markaz, or the local police station. There is
  also an ICTP app.
  - Sources: [ICT Police tenant service](https://islamabadpolice.gov.pk/srv-tr.php), [ICT Police public services](https://islamabadpolice.gov.pk/public_services.php),
    [ICTP app](https://play.google.com/store/apps/details?id=pk.pitb.gov.ictp&hl=en).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **ICT-3.** Documents:
  - tenant and owner CNIC copies;
  - the original rent agreement or lease agreement;
  - for the online form: CNIC front and back, passport-size photos, and a thumb impression photographed
    on plain paper.

  The older ICT page says the tenant must attend in person, and so must a property dealer (with photo and
  CNIC) if one is involved.
  - Sources: [ICT Police srv-tr](https://islamabadpolice.gov.pk/srv-tr.php), [ICT Police tenant form](https://islamabadpolice.gov.pk/ipwe/tenant.php).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **ICT-4.** The fee is given as **Rs 500** in one search excerpt of the ICT Police service page; a second
  excerpt of the same domain showed the "What is the fee?" heading without an amount. "About one working
  day" appears only in a secondary guide.
  - Sources: [ICT Police srv-tr](https://islamabadpolice.gov.pk/srv-tr.php), [Pakera](https://pakera.pk/islamabad-tenant-registration-police/).
  - Accessed 2026-11-05. Confidence: **Low**.

---

## 2. Tenancy agreements

### 2.1 Punjab: Punjab Rented Premises Act 2009

- **PRA-1.** Section 5 requires the following:
  - A landlord shall not let premises except under a **tenancy agreement in writing**.
  - The **landlord** presents it to the **Rent Registrar**, who records the particulars, affixes the
    official seal, keeps a copy and returns the original.
  - A registered tenancy agreement proves the landlord–tenant relationship.
  - The Registration Act duties still apply.
  - Sources: [legislation.pk copy](https://www.legislation.pk/browse-legislation/punjab-legislation/3-the-punjab-rented-premises-act-2009) (text excerpt),
    [punjablaws.gov.pk/laws/498](http://punjablaws.gov.pk/laws/498.html) (listed);
    the [LHC case-law bulletin, 16–31 Dec 2023](https://researchcenter.lhc.gov.pk/pdf/CaseLawBulletin/Bulletinfrom16.12.2023to31.12.2023_3d1a.pdf) describes the same.
  - Accessed 2026-11-05. Confidence: **Medium**.
- **PRA-2.** The Government appoints a Rent Registrar for a district or area. The LHC holds that the role
  is **administrative**: the Registrar receives and registers agreements, and cannot decide whether
  someone is a tenant, which is for the Rent Tribunal. Until Rent Registrars were appointed, Rent
  Controllers under the repealed law performed the function. **I found no current notification naming
  who holds the post in any district.**
  - Sources: [legislation.pk](https://www.legislation.pk/browse-legislation/punjab-legislation/3-the-punjab-rented-premises-act-2009),
    [LHC bulletin](https://researchcenter.lhc.gov.pk/pdf/CaseLawBulletin/Bulletinfrom16.12.2023to31.12.2023_3d1a.pdf).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **PRA-3.** **No statutory deadline or fee** for presenting the agreement was found. A 2026 secondary
  guide says registration is due "within 30 days of execution" under "§ 6". That does not match the s.6
  text excerpt, which lists contents, not a deadline. Do not publish a deadline.
  - Source: [commoner-law.com](https://commoner-law.com/pakistan/housing-rights/registered-tenancy-agreement).
  - Accessed 2026-11-05. Confidence: **Low**.
- **PRA-4.** Section 6 lists the contents "as far as possible":
  - the particulars of the landlord and the tenant;
  - a description of the premises;
  - the period of the tenancy;
  - the rent, the **rate of enhancement**, the due date and the mode of payment;
  - bank account details where rent is paid through a bank;
  - the purpose of use;
  - advance rent, security and pagri.

  Pagri (s.2(e)) is any amount received when a tenancy is granted or renewed, other than advance rent or
  security. The LHC holds that an amount not recorded in the agreement cannot be treated as pagri.
  - Sources: [legislation.pk](https://www.legislation.pk/browse-legislation/punjab-legislation/3-the-punjab-rented-premises-act-2009),
    [LHC bulletin](https://researchcenter.lhc.gov.pk/pdf/CaseLawBulletin/Bulletinfrom16.12.2023to31.12.2023_3d1a.pdf).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **PRA-5.** Section 9 covers non-conforming tenancies. If a tenancy does not conform to the Act, the Rent
  Tribunal will not entertain an application:
  - from the **tenant**, unless he deposits a fine of **5% of the annual value of the rent**;
  - from the **landlord**, unless he deposits a fine of **10%**.

  The fine is paid into the Government treasury.
  - The LHC has held that the fine is mandatory but cannot be imposed arbitrarily. Where the rent is
    disputed, the Tribunal must first determine it tentatively from the material available (Dawn, 2025).
  - A reported LHC ruling (PLD 2020 Lahore 713, seen only through a secondary source) holds that the fine
    is not a one-time charge while the defect remains.
  - Sources: [legislation.pk](https://www.legislation.pk/browse-legislation/punjab-legislation/3-the-punjab-rented-premises-act-2009) (text excerpt),
    [punjablaws.gov.pk/laws/498](http://punjablaws.gov.pk/laws/498.html) (listed), [Dawn](https://www.dawn.com/news/1986401),
    [rentmatterslahore](https://rentmatterslahore.wordpress.com/rent-cases/) (secondary).
  - Accessed 2026-11-05. Confidence: **High** for 5% and 10%; **Low** for PLD 2020 Lahore 713.
- **PRA-6.** Section 15 lists the grounds on which a landlord may seek eviction:
  - (a) the period of the tenancy has expired;
  - (b) rent was not paid or tendered **within thirty days after the period stipulated in s.7**;
  - (c) breach of a term or condition of the agreement;
  - a breach of the tenant's obligations under s.13;
  - use for a purpose other than the one let for;
  - subletting without consent.

  "Personal need" is **not** among the grounds found.
  - Sources: [legislation.pk](https://www.legislation.pk/browse-legislation/punjab-legislation/3-the-punjab-rented-premises-act-2009) (text excerpt),
    [nasirlawsite](http://nasirlawsite.com/laws/rent2009.htm).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **PRA-7.** **No statutory default rent increase was found in the Punjab Act.** Secondary sources
  conflict:
  - an Okara advocate's article claims s.7 caps increases at 10% a year unless agreed;
  - other sources say the Act sets no limit, and that the enforceable increase is the one written in the
    agreement.

  Section 6 expects the agreement to state the "rate of enhancement". **The "Punjab Act's 10% a year
  default" in the task brief is not supported.** The statutory 10% default is ICT's (ICT-R1).
  - Sources: [Azam Ch Advocate](https://www.azamchadv.com/civil-law/ensuring-tenancy-rights-protection-under-the-punjab-rent-laws-a-comprehensive-legal-analysis/),
    [Pakera rent increase rules](https://pakera.pk/rent-control-rent-increase-rules-pakistan/),
    [legislation.pk](https://www.legislation.pk/browse-legislation/punjab-legislation/3-the-punjab-rented-premises-act-2009).
  - Accessed 2026-11-05. Confidence: **Medium** that the Act has no default.
- **PRA-8.** E-stamping:
  - The Board of Revenue collects stamp duty through the PITB **e-Stamping** system. The citizen portal
    on `es.punjab.gov.pk` generates the 32-A challan, which is paid at a designated bank or through ePay
    Punjab, and the e-stamp certificate is then printed.
  - PITB reports the same e-stamping system in Punjab, Sindh and KP.
  - **The current duty on a lease or rent agreement was not found.** The 2026 Punjab Stamp (Amendment)
    Ordinance cut duty on *immovable property transactions* to 1%; nothing shows it covers leases.
  - Sources: [PITB e-Stamping](https://pitb.gov.pk/estamping), [BoR Punjab e-stamping](https://bor.punjab.gov.pk/node/135),
    [eStamping citizen portal](https://es.punjab.gov.pk/eStampCitizenPortal/ChallanFormView/AddChallan?name=GenerateChallan&vCount=115394&agree=true),
    [PITB, e-stamping in three provinces](https://pitb.gov.pk/node/8837),
    [Tribune on the 2026 ordinance](https://tribune.com.pk/story/2603069/punjab-moves-to-cut-stamp-duty-on-property-transactions-from-3-to-1),
    [Dawn](https://www.dawn.com/news/1991242).
  - Accessed 2026-11-05. Confidence: **Medium** for the portal; **Low** (UNVERIFIED) for lease rates.

### 2.2 Sindh: Sindh Rented Premises Ordinance 1979

- **SRPO-1.** Under s.5, the agreement letting premises **shall be in writing**.
  - If it is not compulsorily registrable, it must be attested by the Controller, a Civil Judge or a
    First Class Magistrate.
  - The registered deed, or the attested original, is accepted as proof of the relationship.
  - The Supreme Court says s.5 exists to avoid disputes about the relationship, and has held that terms
    printed on the back of a rent receipt did not satisfy it (*Hakim Ali v. Muhammad Salim*, 1992 SCMR 46,
    as cited).
  - A Sindh High Court order notes that an oral tenancy can still invoke the Ordinance.
  - Sources: [Sindh Code PDF](https://www.sindhlaws.gov.pk/setup/publications_SindhCode/PUB-15-000484.pdf),
    [SJA updated text](https://sja.gos.pk/assets/Updated_Laws/Sindh%20Rented%20Premises%20Ordinance,1979.pdf),
    [Supreme Court C.A. 90-K/2023](https://www.supremecourt.gov.pk/downloads_judgements/c.a._90_k_2023.pdf).
  - Accessed 2026-11-05. Confidence: **High**.
- **SRPO-2.** Under s.7, no landlord may charge more than the rent mutually agreed, or more than a fair
  rent the Controller has fixed. Under s.8, the Controller fixes fair rent on application, considering
  comparable rents, construction and repair costs, new taxes and the annual value for property tax.
  - Source: [Sindh Code PDF](https://www.sindhlaws.gov.pk/setup/publications_SindhCode/PUB-15-000484.pdf) (text excerpt).
  - Accessed 2026-11-05. Confidence: **High**.
- **SRPO-3.** Under s.9, once fair rent is fixed, no increase is allowed until **three years** have
  passed, and an increase is then capped at **10% a year**.
  - The SHC reads this cap as applying where fair rent has been fixed. It holds that increases agreed by
    both parties are not unilateral and cannot later be disputed by the tenant.
  - The Supreme Court holds that even an agreement cannot oust the Controller's jurisdiction to fix fair
    rent.
  - Sources: [SJA updated text](https://sja.gos.pk/assets/Updated_Laws/Sindh%20Rented%20Premises%20Ordinance,1979.pdf),
    [Supreme Court C.P. 492-K/2023](https://www.supremecourt.gov.pk/downloads_judgements/c.p._492_k_2023.pdf).
  - Accessed 2026-11-05. Confidence: **High**.
- **SRPO-4.** Under s.10:
  - if no date is agreed, rent is due **not later than the tenth of the following month**;
  - the landlord acknowledges payment in writing so far as practicable;
  - if the landlord refuses rent, the tenant may send it by postal money order or deposit it with the
    Controller;
  - the acknowledgement, money-order receipt or Controller's receipt is proof of payment.
  - Sources: [Sindh Code PDF](https://www.sindhlaws.gov.pk/setup/publications_SindhCode/PUB-15-000484.pdf),
    [SJA updated text](https://sja.gos.pk/assets/Updated_Laws/Sindh%20Rented%20Premises%20Ordinance,1979.pdf).
  - Accessed 2026-11-05. Confidence: **High**.

### 2.3 Islamabad (ICT): Islamabad Rent Restriction Ordinance 2001

- **ICT-R1.** Section 10 was substituted by the **Islamabad Rent Restriction (Amendment) Act 2021 (XLVII
  of 2021)**. Parliament passed the bill at a joint sitting in November 2021.
  - The rent of residential and non-residential buildings now "shall stand automatically increased at the
    end of every one year of its tenancy by **ten percent**". This does not apply where landlord and
    tenant agree in writing to increase or not to increase rent.
  - The original 2001 text was 25% at the end of every three years.
  - Sources: [Pakistan Code PDF](https://pakistancode.gov.pk/pdffiles/administratorf55c8364472e13dc098d52c71def1f58.pdf) (text excerpt and footnote),
    [Dawn, NA passes the bill](https://www.dawn.com/news/1586314),
    [Dawn, joint session passes Islamabad bills](https://www.dawn.com/news/1658669/joint-session-passes-six-bills-related-to-islamabad).
  - Accessed 2026-11-05. Confidence: **High**.
- **ICT-R2.** The tenancy agreement must be **in writing**. The landlord presents it to the **Controller
  within thirty days of signing**, and the Controller records and seals it. A certified copy proves the
  relationship.
  - Sources: [Pakistan Code PDF](https://pakistancode.gov.pk/pdffiles/administratorf55c8364472e13dc098d52c71def1f58.pdf),
    [NA bill text 2019](https://na.gov.pk/uploads/documents/1569935121_996.pdf).
  - Dawn reports the presentment for record keeping but not the 30 days.
  - Accessed 2026-11-05. Confidence: **Medium**: the 30-day wording is from the 2019 bill, and the
    consolidated excerpt was not clean.
- **ICT-R3.** All payments in connection with the tenancy are made "**through crossed cheques or with
  proper receipt or acknowledgment**". Disputes go first to a **Mediation Council**; if mediation fails,
  the Controller decides.
  - Sources: [Pakistan Code PDF](https://pakistancode.gov.pk/pdffiles/administratorf55c8364472e13dc098d52c71def1f58.pdf),
    [Dawn](https://www.dawn.com/news/1586314).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **ICT-R4.** Where rent is fixed by agreement for a tenancy of under three years, no further increase is
  permissible while the agreement subsists, subject to exceptions for improvements the landlord funds.
  - Source: [Pakistan Code PDF](https://pakistancode.gov.pk/pdffiles/administratorf55c8364472e13dc098d52c71def1f58.pdf) (text excerpt).
  - Accessed 2026-11-05. Confidence: **Low**: I could not tell whether this survives the 2021 amendment.
- **ICT-R5.** The Pakistan Code listing for the Ordinance shows a "Lapse Date: July 29 2022" field, which
  I cannot explain.
  - Source: [Pakistan Code listing](https://pakistancode.gov.pk/english/UY2FqaJw1-apaUY2Fqa-apaUY2Npa5tr-sg-jjjjjjjjjjjjj).
  - Accessed 2026-11-05. Confidence: **Low**. See Uncertainties.

### 2.4 Khyber Pakhtunkhwa

- **KPR-1.** **No "Khyber Pakhtunkhwa Rented Premises Act 2019" was found** on the KP Code portal or the
  KP Assembly site. One secondary guide uses that name; nothing else does.
  - The **West Pakistan Urban Rent Restriction Ordinance 1959** still applies to the urban areas of the
    province. The KP Code hosts it, and the Peshawar High Court applied it in 2019 and in a 2025 writ on
    a shop tenancy (ejectment for unpaid rent and utility charges).
  - Sources: [KP Code 1959 Ordinance PDF](https://kpcode.kp.gov.pk/uploads/1959_06_THE_WEST_PAKISTAN_URBAN_RENT_RESTRICTION_ORDINANCE_1959.pdf),
    [PHC W.P. 5540/2019](https://peshawarhighcourt.gov.pk/PHCCMS//judgments/W.-P-5540-2019.pdf),
    [PHC W.P. 582/2024 (decided 2025)](https://peshawarhighcourt.gov.pk/PHCCMS//judgments/wp-582-2024-05-05-2025-0001.pdf),
    [acash.org.pk](https://www.acash.org.pk/rental-laws-in-pakistan-tenants-landlords-rights) (the source using the 2019 name).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **KPR-2.** Under the 1959 Ordinance:
  - the Rent Controller may fix fair rent;
  - under the s.4(2) proviso, an increase fixed under that section "shall not exceed **25 percent** of the
    rent being paid by the tenant";
  - eviction is under s.13, and covers default and reconstruction with municipal sanction.
  - Sources: [PHC W.P. 5540/2019](https://peshawarhighcourt.gov.pk/PHCCMS//judgments/W.-P-5540-2019.pdf),
    [PHC W.P. 582/2024](https://peshawarhighcourt.gov.pk/PHCCMS//judgments/wp-582-2024-05-05-2025-0001.pdf).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **KPR-3.** The 2014 security Act requires a written agreement for any non-family occupant, containing
  information that verifies the tenant's identity, with attested copies given to police (KP-3).
  - Source: [KP Assembly PDF](https://www.pakp.gov.pk/wp-content/uploads/2024/05/The-Khyber-Pakhtunkhwa-Restriction-of-Rented-Buildings-Security-Act-2014-Act-No.-XIV-2014.pdf).
  - Accessed 2026-11-05. Confidence: **Medium**.

### 2.5 Balochistan

- **BLR-1.** The Balochistan High Court applies the **West Pakistan Urban Rent Restriction Ordinance 1959**
  (Sibi Bench ejectment for default, ss.13 and 15). Another reported judgment refers to a "Balochistan
  Rent Restriction Ordinance" (ss.4 and 13(6)). I did not retrieve the Ordinance text from the
  Balochistan Code.
  - Sources: [BHC Sibi Bench judgments](https://bhc.gov.pk/sibi-bench/resources/judgments/justice-muhammad-noor-meskanzai),
    [BHC reported judgments](https://bhc.gov.pk/resources/judgments/justice-abdul-qadir-mengal/reported-judgments).
  - Accessed 2026-11-05. Confidence: **Low**.
- **BLR-2.** The 2015 security Act requires an attested rent agreement for the police (BL-3).
  Confidence: **Medium**.

### 2.6 All jurisdictions

- **REG-1.** Registration Act 1908, s.17(1)(d): leases "from year to year, or for any term exceeding one
  year, or reserving a yearly rent" must be registered.
  - The SHC treats a tenancy beyond one year, or for an indefinite period, as needing registration.
  - An unregistered instrument that must be registered does not create rights in immovable property
    (*Allah Diwaya v. Ghulam Fatima*, PLD 2008 SC 73, as cited by the SHC).
  - This is why "11-month" agreements are common. **No official source describes that practice itself.**
  - Sources: [Pakistan Code, Registration Act 1908](https://pakistancode.gov.pk/pdffiles/administrator0f29bc9f1e3dfed37c0034eed1e29d53.pdf),
    [KP Code copy](https://kpcode.kp.gov.pk/uploads/THE_REGISTRATION_ACT_1908.pdf),
    [SHC C.P. S-352/2018](https://caselaw.shc.gov.pk/caselaw/view-file/MTMwMzc1Y2Ztcy1kYzgz),
    [SHC order](https://caselaw.shc.gov.pk/caselaw/view-file/MTUyNzE0Y2Ztcy1kYzgz).
  - Accessed 2026-11-05. Confidence: **Medium**: the exact statutory wording is not in the excerpt.
- **REG-2.** The Supreme Court (summary attributed to Justice Faisal Arab) holds that:
  - periodic increases agreed in the tenancy agreement are "rent";
  - a mutually agreed increase cannot later be disputed by the tenant, except through an application to
    fix fair rent;
  - non-payment of the agreed rent can be default.

  The case concerned s.7(5) of the Cantonments Rent Restriction Act 1963 (no unilateral increase within
  three years). The citation (possibly 2025 SCP 350) is unverified.
  - Source: [Supreme Court latest judgments](https://www.supremecourt.gov.pk/wp-content/plugins/my-plugin/latest_judgements.php).
  - Accessed 2026-11-05. Confidence: **Medium**.
  - Added 2026-11-07: an unofficial copy of the Act is at [nasirlawsite](https://www.nasirlawsite.com/laws/cantrent.htm)
    (last updated 2008, so it may miss amendments); no Pakistan Code copy appeared in a WebSearch. The site's
    rent-increase calculator and agreement checklist now carry a "Cantonment areas" note citing both, at
    **Medium** confidence.

### 2.7 Practical agreement checklist (for the site)

This is a practical list, not a legal requirement unless an item cites one.

1. **Parties.** Full names, father's or husband's name, CNIC numbers, addresses and phone numbers of the
   landlord and the tenant, and of the property dealer if any (Punjab s.6; police forms need the CNICs).
2. **Premises.** Address, portion or floor, fixtures and furniture list, and meter reference numbers
   (Punjab s.6).
3. **Term.** Start and end dates and renewal terms. A term over one year, or a yearly rent, needs
   registration under the Registration Act (REG-1).
4. **Rent.** Monthly rent, plus the **rate and interval of increase**.
   - Punjab s.6 expects the rate of enhancement.
   - In ICT, 10% a year applies unless you agree otherwise in writing (ICT-R1).
   - In Sindh, agreed increases are enforceable (SRPO-3).
5. **Payment.** Due date and mode of payment, with bank details if paid through a bank (Punjab s.6).
   - In ICT, pay by crossed cheque or against a receipt (ICT-R3).
   - In Sindh, keep written receipts; the default due date is the 10th (SRPO-4).
6. **Advance rent, security deposit and any pagri**, with refund terms (Punjab s.6).
7. **Permitted use**, residential or commercial (misuse is a Punjab eviction ground, PRA-6).
8. **Subletting** only with written consent (PRA-6).
9. **Utilities.**
   - Who pays.
   - Meter readings and photos at handover and move-out.
   - Final bills settled before the deposit is returned.
   - Landlord liability for a tenant's own connection (§4).
10. **Repairs and maintenance**: who does what.
11. **Notice period and handover condition.**
12. **Adult occupants.** Names and CNICs. Punjab's online form has an "adults with tenant" step; KP needs
    male members over 14 and two references (KP-3).
13. **Execution.**
    - Signatures and two witnesses, on e-stamp paper (PRA-8).
    - Punjab: present the agreement to the Rent Registrar (PRA-1).
    - ICT: present it to the Controller (ICT-R2).
    - Sindh: attestation if it is not registered (SRPO-1).
14. **Police registration** reference or acknowledgment receipt number (§1).

---

## 3. Rental income tax, tax year 2026-27 (TY2027)

### 3.1 Framework

- **TX-1.** A tax year is the 12 months ending on 30 June, named by the calendar year in which it ends
  (ITO s.74). **TY2027 runs from 1 July 2026 to 30 June 2027.** Today (2026-11-05) falls in TY2027.
  - Source: [PwC, tax administration](https://taxsummaries.pwc.com/pakistan/individual/tax-administration).
  - Accessed 2026-11-05. Confidence: **High**.
- **TX-2.** Rent received or receivable for a tax year (other than exempt rent) is chargeable under the head
  "Income from Property" (s.15).
  - Sources: [pkrevenue, s.15A text](https://pkrevenue.com/tax-on-income-from-property-under-updated-ordinance/);
    the [FBR Ordinance as amended to 2026](https://download1.fbr.gov.pk/Docs/2026724177725705IncomeTaxOrdinanace2001.pdf) is listed.
  - Accessed 2026-11-05. Confidence: **Medium**.
- **TX-3.** Since the Finance Act 2021 (TY2022), property income of individuals and AOPs is **no longer taxed
  at separate block rates**. It is computed **net**, after s.15A deductions, and taxed with other income at
  the normal rates.
  - Sources: [PwC, income determination](https://taxsummaries.pwc.com/pakistan/individual/income-determination) (reviewed 24 Aug 2026),
    [pkrevenue, FBR explains chargeability](https://pkrevenue.com/fbr-explains-chargeability-of-tax-on-income-from-property/).
  - Accessed 2026-11-05. Confidence: **High**.
- **TX-4.** TY2027 normal rates for non-salaried individuals and AOPs (context only; **do not publish a
  final-tax estimate**, D-10):
  - nil up to Rs 600,000;
  - 15% on Rs 600,001–1,200,000;
  - Rs 90,000 + 20% on Rs 1,200,001–1,600,000;
  - the higher bands were truncated in the excerpt.

  The Finance Act 2026 revised the **salaried** slabs and abolished the surcharge on salary income. The
  **10% surcharge** for non-salaried individuals and AOPs with taxable income above Rs 10 million continues.
  - Source: [PwC, taxes on personal income](https://taxsummaries.pwc.com/pakistan/individual/taxes-on-personal-income).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **TX-5.** Section 7E (tax on deemed income from immovable property):
  - The Federal Constitutional Court declared it ultra vires **the Constitution** (not "beyond the
    government's power") and void ab initio. KPMG gives the order date as 6 May 2026 in one brief and 7 May
    2026 in a tax alert (C.P.L.A. 1442-K/2022). The press reports the short order on 7 May 2026
    ([Dawn 1998420](https://www.dawn.com/news/1998420), [ProPakistani](https://propakistani.pk/2026/05/07/constitutional-court-declares-section-7e-null-and-void-in-major-relief-for-property-sector/),
    [Tribune 2606812](https://tribune.com.pk/story/2606812/fcc-dismisses-fbr-appeals-declares-section-7e-unconstitutional))
    and the detailed judgment in June 2026 ([Dawn 2008456](https://www.dawn.com/news/2008456)). Checked
    2026-11-07 by WebSearch; the judgment itself was not read.
  - The **Finance Act 2026 omitted s.7E** and, with it, the rate provision in Division VIIIC.
  - FBR Circular No. 02 of 2026-27 explains the amendments.
  - Sources: [FBR Circular 02 of 2026-27](https://download1.fbr.gov.pk/Docs/202698139527880CircularNo.2of2026-27.pdf),
    [Finance Act 2026, Gazette 26 June 2026](https://download1.fbr.gov.pk/Docs/20266291261044366FinanceAct2026.pdf),
    [KPMG brief of the Finance Act 2026](https://assets.kpmg.com/content/dam/kpmgsites/pk/pdf/2026/07/A%20Brief%20of%20Finance%20Act%202026.pdf.coredownload.inline.pdf),
    [KPMG tax alert](https://kpmg.com/us/en/taxnewsflash/news/2026/07/tnf-pakistan-section-7e-on-deemed-immovable-property-income-held-unconstitutional.html).
  - Accessed 2026-11-05. Confidence: **High** for the omission; **Medium** for the court date.
- **TX-6.** **Do not state** a "minimum deemed rent of 4% of FBR value for commercial property". Sources
  conflict:
  - PwC describes it as current;
  - KPMG says the Finance Bill 2025 proposal was **withdrawn** in the enacted Finance Act 2025.
  - Sources: [PwC, income determination](https://taxsummaries.pwc.com/pakistan/individual/income-determination),
    [KPMG brief of the Finance Act 2025](https://assets.kpmg.com/content/dam/kpmgsites/pk/pdf/2025/07/A-Brief-on-Finance-Act-2025.pdf.coredownload.inline.pdf).
  - Accessed 2026-11-05. Confidence: **Low**.

### 3.2 Section 15A deductions

- **TX-7.** The **repairs allowance** is "an allowance equal to **one-fifth** of the rent chargeable to tax in
  respect of the building for the year, computed before any deduction allowed under this section". It
  applies to buildings; one guide says it does not apply to open plots.
  - Sources: [pkrevenue, s.15A text](https://pkrevenue.com/tax-on-income-from-property-under-updated-ordinance/),
    [FBR ITO 2001 as amended to 30 June 2019](https://download1.fbr.gov.pk/Docs/20199191692232848IncomeTaxOrdinance,2001amendedupto30-06-2019.pdf),
    [PwC](https://taxsummaries.pwc.com/pakistan/individual/income-determination).
  - Accessed 2026-11-05. Confidence: **High** for 1/5; **Low** for the open-plot exclusion.
- **TX-8.** Other s.15A deductions:
  - the premium to insure the building against damage or destruction;
  - profit or interest on a mortgage or other capital charge on the property;
  - expenditure for deriving rent, including **administration and collection charges, capped at 4%** of
    the rent chargeable. PwC says 4%; an older reproduction says 6%.
  - Sources: [pkrevenue](https://pkrevenue.com/tax-on-income-from-property-under-updated-ordinance/) (text excerpt),
    [PwC](https://taxsummaries.pwc.com/pakistan/individual/income-determination).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **TX-9.** Legal expenses of defending title, irrecoverable rent (subject to conditions), property tax and
  ground rent appear in secondary guides only.
  - Sources: [theproreaders](https://theproreaders.com/income-from-property-income-tax-ordinance-2001/),
    [mindmapai](https://mindmapai.app/mind-mapping/income-from-property-sec.-15).
  - Accessed 2026-11-05. Confidence: **Low**.

### 3.3 Section 155: who must withhold

- **TX-10.** Every **prescribed person** making a payment of rent of immovable property (in full or part,
  **including an advance**) must deduct tax from the **gross amount of rent** when paying. Rent includes rent
  of furniture and fixtures, and amounts for services relating to the property. The rate is the one in
  **Division V of Part III of the First Schedule**. The FBR's rate card says the Ordinance prevails over the
  card if they conflict.
  - Sources: [FBR brochure on deduction at source](https://download1.fbr.gov.pk/Docs/20186291463931170Brochure_Collectionanddeductionoftaxatsource.pdf),
    [FBR TY2027 rate card](https://download1.fbr.gov.pk/Docs/202681113864992WithholdingTaxRatesCard2027.pdf),
    [pkrevenue TY2027](https://pkrevenue.com/fbr-rental-property-tax-rates-tax-year-2027/).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **TX-11.** The prescribed persons are:
  - the Federal Government, a Provincial Government and a Local Government;
  - a company;
  - a non-profit organisation or charitable institution;
  - a diplomatic mission of a foreign state;
  - a private educational institution, a boutique, a beauty parlour, a hospital, a clinic or a maternity
    home;
  - **individuals or AOPs paying gross rent of Rs 1.5 million or more in a year**.

  Consequence for the site: an individual tenant paying less than Rs 1.5 million a year is not a
  withholding agent under s.155.
  - Sources: [FBR brochure 2018](https://download1.fbr.gov.pk/Docs/20186291463931170Brochure_Collectionanddeductionoftaxatsource.pdf),
    [FBR Circular 06 of 2013](https://download1.fbr.gov.pk/Docs/201372214742171992013CIRCULAR06.pdf).
  - Accessed 2026-11-05. Confidence: **Medium**: no later amendment was found, but the 2026 consolidated
    text was not seen.

### 3.4 Section 155 rates for TY2027 (these figures drive the calculator)

The Finance Act 2026 made **no change to the s.155 rent rates** that I could find. The FBR TY2027 card
("updated up to 30-06-2026 as per Finance Act 2026") shows the same bands as the TY2026 card. Neither FBR
Circular 02 of 2026-27 nor the KPMG brief of the Finance Act 2026 lists a s.155 change.

**Payee is an individual or AOP.** Rates are on the gross annual rent, in rupees.

| Gross annual rent | Payee on the ATL | Payee not on the ATL |
|---|---|---|
| does not exceed 300,000 | nil | nil |
| over 300,000, up to 600,000 | 5% of the amount over 300,000 | 10% of the amount over 300,000 |
| over 600,000, up to 2,000,000 | 15,000 + 10% of the amount over 600,000 | 30,000 + 20% of the amount over 600,000 |
| over 2,000,000 | 155,000 + 25% of the amount over 2,000,000 | 310,000 + 50% of the amount over 2,000,000 |

**Payee is a company.** 15% of the gross rent if the company is on the ATL; **30%** if it is not.

- **TX-12.** Individual and AOP bands for payees on the ATL.
  - Sources: [FBR TY2027 card](https://download1.fbr.gov.pk/Docs/202681113864992WithholdingTaxRatesCard2027.pdf) (excerpt shows the four bands,
    citing "Division-V of Part-III of First Schedule read with R.1 of Tenth Schedule"),
    [FBR TY2026 card](https://download1.fbr.gov.pk/Docs/20258181281745641WHT-RateCard.pdf) (all four bands),
    [KPMG TY2027 card](https://assets.kpmg.com/content/dam/kpmgsites/pk/pdf/2026/07/Withholding_Tax_Collection_Deduction_TY-2027.pdf.coredownload.inline.pdf) (same structure, "Adjustable"),
    [FBR Circular 02 of 2026-27](https://download1.fbr.gov.pk/Docs/202698139527880CircularNo.2of2026-27.pdf) (no s.155 change).
  - Accessed 2026-11-05. Confidence: **High**.
- **TX-13.** Company 15% (on the ATL) and 30% (not on the ATL).
  - Sources: [FBR TY2026 card](https://download1.fbr.gov.pk/Docs/20258181281745641WHT-RateCard.pdf) ("Company 15.00% 30.00%"),
    [KPMG TY2027 card](https://assets.kpmg.com/content/dam/kpmgsites/pk/pdf/2026/07/Withholding_Tax_Collection_Deduction_TY-2027.pdf.coredownload.inline.pdf) ("15/30").
  - The TY2027 FBR excerpt did not show the company row.
  - Accessed 2026-11-05. Confidence: **High**.
- **TX-14.** The individual and AOP "not on the ATL" column applies Tenth Schedule rule 1, which increases
  the rate by **100%**. Doubling every rate and fixed amount is the same as doubling the tax at every band;
  the nil band stays nil.
  - Supporting sources:
    - the [FBR TY2027 card](https://download1.fbr.gov.pk/Docs/202681113864992WithholdingTaxRatesCard2027.pdf)
      and [TY2026 card](https://download1.fbr.gov.pk/Docs/20258181281745641WHT-RateCard.pdf) cite R.1 of the Tenth Schedule;
    - the [FBR 2023 card](https://download1.fbr.gov.pk/Docs/20238215830342WithholdingRatesCards.pdf) marks non-ATL as "Increased";
    - [PwC](https://taxsummaries.pwc.com/pakistan/individual/income-determination): "these WHT rates shall increase by 100% in case the recipient … is not an active taxpayer";
    - [pkrevenue TY2023-24](https://pkrevenue.com/fbr-notifies-tax-rates-on-immovable-property-rental-income-for-2023-24/).
  - Conflict: the [FBR 2020 card](https://download1.fbr.gov.pk/Docs/2020728147649624WHTRateCard-Amended.pdf) and
    [FBR 2021 card](https://download1.fbr.gov.pk/Docs/20218151182834653202189138454560UPDATEDWHTRateCardupto30thJune2021.pdf)
    carry the footnote "As per Finance Act, 2019, the provisions of newly inserted 10th schedule … shall
    not apply on tax deducted under section 155". The later cards drop it and cite R.1, but I did not find
    the amending Act.
  - Accessed 2026-11-05. Confidence: **Medium**.
- **TX-15.** Tax deducted under s.155 is **adjustable** against the payee's final liability, for individuals
  and AOPs and for companies. It is not a final tax. (Before 2021 some rent withholding was final; that is
  history, not current law.)
  - Sources: [KPMG TY2027 card](https://assets.kpmg.com/content/dam/kpmgsites/pk/pdf/2026/07/Withholding_Tax_Collection_Deduction_TY-2027.pdf.coredownload.inline.pdf),
    [KPMG TY2026 card](https://assets.kpmg.com/content/dam/kpmgsites/pk/pdf/2025/07/Withholding%20Tax-Collection-Deduction%20Rate-Card-TY-2026.pdf.coredownload.inline.pdf),
    [FBR Circular 06 of 2013](https://download1.fbr.gov.pk/Docs/201372214742171992013CIRCULAR06.pdf).
  - Accessed 2026-11-05. Confidence: **High**.
- **TX-16.** How to check ATL status:
  - For an individual, send "ATL", a space and the 13-digit CNIC to **9966**. For an AOP or company, use
    the 7-digit NTN instead.
  - Or search the ATL on IRIS by CNIC, NTN or passport number.
  - The income-tax ATL download page shows "Updated on 26 Oct 2026". An older FBR notice says the ATL is
    published each year on 1 March.
  - Sources: [FBR ATL page](https://www.fbr.gov.pk/categ/active-taxpayer-list-income-tax/51147/30859/71169),
    [ATL search](https://e.fbr.gov.pk/ATLSearchUtilityIT.aspx), [ATL download](https://www.fbr.gov.pk/download-atl/132041),
    [FBR notice](https://fbr.gov.pk/atl-for-tax-year-2020-to-be-published-on-1st-march-2021/152857).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **TX-17.** Timing and part years:
  - Tax is deducted **when the rent is paid**.
  - The bands are written on **gross annual rent**.
  - **No official source found** says how a withholding agent spreads the annual band tax across monthly
    payments, or handles a part-year or mid-year rent change.
  - Sources: [FBR TY2026 card](https://download1.fbr.gov.pk/Docs/20258181281745641WHT-RateCard.pdf),
    [pkrevenue](https://pkrevenue.com/fbr-issues-new-tax-rates-on-rental-income-for-2025-26/).
  - Accessed 2026-11-05. Confidence: **Low** (method absent).

### 3.5 Calculator specification (WEB-01, s.155)

**Inputs**

- Gross rent, as an annual figure, or monthly × 12, in whole rupees. Gross includes furniture, fixtures and
  property services (TX-10).
- Payee (landlord) type: individual or AOP, or company.
- Payee ATL status: on the ATL, or not.
- Who the tenant is: prescribed person or not (TX-11). If the tenant is not a prescribed person, show "no
  s.155 deduction is required by this tenant", and still offer the figure for information.

**Output**

- The **annual** withholding from the table in §3.4, and the effective rate (withholding ÷ gross rent).
- If a monthly figure is shown, label it "annual ÷ 12, an even-spread assumption; the law states annual
  bands" (TX-17).

**Fixed copy**

- "TY2027 (1 July 2026 – 30 June 2027) rates from the FBR Withholding Tax Rate Card for Tax Year 2027."
- "Tax withheld is adjustable against your final tax; it is not your final tax."
- "Not tax advice."
- "Last reviewed 2026-11-05."
- Link the FBR card and the ATL check.

**Do not** compute final tax, s.15A net income or Division I slabs (D-10).

**Arithmetic**

- Band edges are inclusive: "does not exceed" → `<=`.
- Use exact integer or decimal arithmetic.
- No rounding: the calculator shows the exact figure, with paisa where the result is not a whole number of
  rupees (for example Rs 0.05 at a gross rent of Rs 300,001). The FBR states no rounding rule. (Changed
  2026-11-07 from "round only for display, to the nearest rupee", to match what the calculator does and
  what the page says.)

### 3.6 Worked examples (computed by `s155_vectors.py`)

Continuity at the band edges, from the script output:

```
edge   300,000: at=      0.00 at+1=      0.05
edge   600,000: at= 15,000.00 at+1= 15,000.10
edge 2,000,000: at=155,000.00 at+1=155,000.25
```

| Annual gross rent | Individual or AOP, on the ATL | Individual or AOP, not on the ATL | Company, on the ATL | Company, not on the ATL | Effective rate (individual or AOP, ATL) |
|---:|---:|---:|---:|---:|---:|
| 240,000 | 0 | 0 | 36,000 | 72,000 | 0.00% |
| 300,000 | 0 | 0 | 45,000 | 90,000 | 0.00% |
| 360,000 | 3,000 | 6,000 | 54,000 | 108,000 | 0.83% |
| 600,000 | 15,000 | 30,000 | 90,000 | 180,000 | 2.50% |
| 1,200,000 | 75,000 | 150,000 | 180,000 | 360,000 | 6.25% |
| 1,500,000 | 105,000 | 210,000 | 225,000 | 450,000 | 7.00% |
| 2,000,000 | 155,000 | 310,000 | 300,000 | 600,000 | 7.75% |
| 3,000,000 | 405,000 | 810,000 | 450,000 | 900,000 | 13.50% |
| 6,000,000 | 1,155,000 | 2,310,000 | 900,000 | 1,800,000 | 19.25% |

These rows can become the calculator's unit-test vectors.

---

## 4. Utilities

- **UT-1.** NEPRA's legal page lists a "Revised/updated Consumer Service Manual (CSM) – November 26, 2025";
  a "CSM Revised 2025" PDF is published. Clause numbers in older summaries may have changed.
  - Sources: [NEPRA legal page](https://nepra.org.pk/Legal.php),
    [CSM Revised 2025 PDF](https://nepra.org.pk/Legislation/7-Manuals/2025/CONSUMER%20SERVICE%20MANUAL%20%28CSM%29%20REVISED%202025.pdf).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **UT-2.** **The tenant's own connection.** Where the owner supports a tenant's application, "the
  Landlord/Owner will also affirm on a non-judicial stamp paper worth Rs.50/- … that he/she would be
  **responsible for payment of the default amount of his/her tenant** (if any)".
  - Sources: [CSM Revised 2025](https://nepra.org.pk/Legislation/7-Manuals/2025/CONSUMER%20SERVICE%20MANUAL%20%28CSM%29%20REVISED%202025.pdf),
    [CSM 2020](https://nepra.org.pk/Legislation/7-Manuals/7.1.1%20Consumer%20Service%20Manual%202020/TCD-10%20REVISED%20CONSUMER%20SERVICE%2008-07-20%2017081-32.pdf) (text excerpts).
  - Accessed 2026-11-05. Confidence: **High**.
- **UT-3.** "The connection can be disconnected on request of the owner/landlord of the premises if the
  **tenant is defaulter of electricity bills consecutively for three months**."
  - Sources: [CSM Revised 2025](https://nepra.org.pk/Legislation/7-Manuals/2025/CONSUMER%20SERVICE%20MANUAL%20%28CSM%29%20REVISED%202025.pdf),
    [CSM 2020](https://nepra.org.pk/Legislation/7-Manuals/7.1.1%20Consumer%20Service%20Manual%202020/TCD-10%20REVISED%20CONSUMER%20SERVICE%2008-07-20%2017081-32.pdf).
  - Accessed 2026-11-05. Confidence: **High**.
- **UT-4.** **Change of name.** When premises are sold, the new owner must apply to the DISCO for a change
  of name. The application needs the last paid bill, "subject to the condition that **no
  arrears/deferred amount/instalments are pending**".
  - Source: [CSM Revised 2025](https://nepra.org.pk/Legislation/7-Manuals/2025/CONSUMER%20SERVICE%20MANUAL%20%28CSM%29%20REVISED%202025.pdf) (text excerpt).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **UT-5.** **New connections.** A new connection requires that "**no arrears of electricity bills are
  outstanding against the occupier or owner of the premises**" (NEPRA Consumer Eligibility Criteria
  (Distribution Licensee) Regulations 2021).
  - Source: [NEPRA regulations](https://nepra.org.pk/Admission%20Notices/2021/12%20Dec/NEPRA%20Consumer%20Eligibility%20Criteria%20%28Distribution%20Licensee%29%20Regulations%202021.pdf).
  - Accessed 2026-11-05. Confidence: **Medium**: the excerpt is from the admission-notice copy.
- **UT-6.** Under CSM clause 8.1, a premises is liable to be disconnected if the consumer is a defaulter
  (cited by NEPRA in a March 2026 K-Electric decision).
  - Source: [NEPRA decision TCD-09 K-Electric, 12 March 2026](https://nepra.org.pk/consumer%20affairs/cad/Authority%20Decisions/K-Electric/2026/03%20March/TCD-09%20K-ELECTRIC%2012-03-2026%201029.PDF).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **UT-7.** **NEPRA decision, LESCO, 18 February 2026** (case-specific, not a general rule):
  - LESCO neither disconnected a defaulting tenant nor took security, so the arrears **before** the tenant
    left were to be recovered from the tenant.
  - Bills **after** the tenant left were the owner's.
  - The Rs 200,000 security deposit the owner held for the tenant was to be recovered **from the owner**
    against the pre-vacation dues.
  - Source: [NEPRA TCD-05 LESCO](https://nepra.org.pk/consumer%20affairs/cad/Authority%20Decisions/LESCO/2026/02%20Feb/TCD-05%20740%2018-02-2026%20LESCO.PDF).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **UT-8.** A 2023 proposed CSM amendment would have the owner undertake to pay dues of any previous
  connection at the premises "if noticed later on". It is a **proposal only**; I did not confirm it in the
  2025 text.
  - Source: [NEPRA proposed amendments](https://nepra.org.pk/Admission%20Notices/2023/11%20Nov/Proposed%20Amenedment%20in%20Consumer%20Service%20Manual%202021.pdf).
  - Accessed 2026-11-05. Confidence: **Low**.
- **UT-9.** **Gas (SNGPL) change of name.**
  - There is no fee for a change of name.
  - A tenant may transfer an existing connection into the tenant's own name with a **landlord's NOC**.
  - The previous tenant's security deposit is not transferable.
  - The new owner's affidavit (on Rs 100 stamp paper) says the owner will be "responsible of all payments
    concerning gas connection at the above premises".
  - Sources: [SNGPL change-of-name FAQ](https://www.sngpl.com.pk/page.jsp?pgids=1786&pgname=PAGES_NAME_a&secs=ss7xa852op845&cats=ct456712337&artcl=artuyh709123465),
    [SNGPL affidavit](https://sngpl.com.pk/download/EXECUTEDONRS.pdf).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **UT-10.** **Gas reconnection** (SSGC contract filed with OGRA, and the SNGPL domestic contract):
  - A disconnected supply is reconnected only after the consumer pays the reconnection charges **and clears
    the arrears in full** (or as mutually agreed).
  - The company may discontinue supply unless the new owner or occupier signs a fresh contract.
  - SSGC's new-connection form asks whether there are "outstanding dues / claims at the said premises".
  - Sources: [SSGC contract via OGRA](https://www.ogra.org.pk/download/2720?lang=en),
    [SNGPL domestic contract](https://www.sngpl.com.pk/download/contractdocs/domrlngcontract.pdf),
    [SSGC form](https://www.ssgc.com.pk/web/wp-content/uploads/2025/09/new_rlng_domestic_form.pdf).
  - Accessed 2026-11-05. Confidence: **Medium**.
- **UT-11.** **Protected domestic consumers.**
  - A protected consumer is a non-ToU residential consumer using **up to 200 kWh a month (200 or fewer)
    consistently for the past six months**. One month over 200 units means unprotected rates for the next
    six months. (Corrected 2026-11-07: "under 200" was wrong; NEPRA's wording is "<=200".)
  - NEPRA's own documents: the [Ministry of Energy policy guidelines, admission notice July 2021](https://www.nepra.org.pk/Admission%20Notices/2021/07%20July/Policy%20guidelines%20of%20MoE.PDF)
    and the [TRF-100 determination for the ex-WAPDA DISCOs, 23 September 2021](https://www.nepra.org.pk/tariff/Tariff/Ex-WAPDA%20DISCOS/2021/TRF-100%20Determination%20XWDISCOs%2023-09-2021%2037543-45.PDF).
    Seen 2026-11-07 through WebSearch excerpts only; the PDFs could not be fetched (proxy 403).
  - The threshold is under review: [ARY News](https://arynews.tv/pakistan-govt-may-shift-non-protected-electricity-tariff-to-301-units)
    reported a proposal to move it to 301 units, and [ARY News](https://arynews.tv/protected-consumers-pakistan-to-abolish-electricity-subsidies)
    a proposal to abolish the category. No final decision was found. The site says to check the DISCO's
    current notification.
  - NEPRA kept 2026 end-consumer tariffs unchanged. The Power Division added fixed monthly charges.
  - Do not publish prices; they change.
  - Sources: [Business Recorder (KE proposal)](https://www.brecorder.com/news/40318041),
    [Tribune](https://tribune.com.pk/story/2586812/nepra-leaves-end-consumer-tariff-unchanged),
    [Business Recorder (fixed charges)](https://www.brecorder.com/news/40407658/domestic-consumers-pd-notifies-fixed-monthly-charges),
    [Dawn](https://www.dawn.com/news/1971568).
  - Accessed 2026-11-05. Confidence: **Medium**.

**Practical tips for the site.** Each tip derives from the facts above.

- A meter in the landlord's name protects the connection's continuity, but **the landlord carries the
  default risk** (UT-4, UT-5, UT-6). Ask for a photo of each paid bill and check the arrears line every
  month.
- Before signing an affidavit for a tenant's own connection, know that it makes you liable for the tenant's
  default (UT-2). If the tenant defaults three months in a row, you can ask the DISCO to disconnect (UT-3).
- At move-in and move-out, record meter readings with photos. Get the final bills paid **before** returning
  the deposit; NEPRA has looked at a deposit the owner held (UT-7).
- For gas, a tenant who wants the connection in their own name needs your NOC. The supply is reconnected
  only after arrears are cleared (UT-9, UT-10).
- Watch the 200-unit protected threshold on shared or sub-metered portions (UT-11).

---

## 5. Rent increments and proration

### 5.1 Increments: what the law says

| Jurisdiction | Statutory default | Source |
|---|---|---|
| ICT | **+10% automatically at the end of every year of tenancy**, unless agreed otherwise in writing | ICT-R1 (**High**) |
| Punjab | **none found**; the agreement should state the rate of enhancement (s.6) | PRA-4, PRA-7 (**Medium**) |
| Sindh | none; agreed increases bind. Where the Controller has fixed fair rent: frozen for 3 years, then at most 10% a year | SRPO-3 (**High**) |
| KP (urban) | none; a fair-rent increase under the 1959 Ordinance is capped at 25% of the current rent | KPR-2 (**Medium**) |
| Balochistan | 1959 Ordinance applied by the BHC; text not retrieved | BLR-1 (**Low**) |
| Cantonments | no unilateral increase within 3 years (s.7(5), 1963 Act); agreed periodic increases are rent | REG-2 (**Medium**) |

- **IN-1.** A **10% annual increase** is the common market assumption in written agreements. This is
  practice, not law, outside ICT. Its only support is the market brief's non-official sources.
  Confidence: **Low** as a "norm"; present it as "commonly agreed", never as "the law".
- **IN-2.** The app suggests an increment rounded to Rs 100 (LEASE-06). No law requires rounding; it is an
  app convention.

### 5.2 Proration: no legal rule found

- **PRO-1.** I found **no statute, court ruling or official guidance** prescribing how to prorate rent for a
  part month. Two conventions exist:
  - **actual days in the month** (used by the app);
  - a 30-day month.

  The website should present proration as a convention, and say which one the calculator uses.
  Confidence: **Low** (absence of evidence).
- **PRO-2.** The app's rule (`app.prorated_rent`, mirrored by `contracts/rent_math_vectors.json`) is:
  first-month rent = rent × (days from the start date to the month end, inclusive) ÷ days in that month,
  rounded half-up to whole rupees. The website calculator should use the same rule.

### 5.3 Worked examples (computed with Python, same rule as `app.prorated_rent`)

```
rent 45,000 start 2026-11-15: 16/30 days -> 24,000
rent 45,000 start 2027-02-15: 14/28 days -> 22,500
rent 50,000 start 2026-12-20: 12/31 days -> 19,355
10% increment on 45,000 -> 49,500 ; rounded to Rs 100 -> 49,500
10% on 37,350 -> 41085.0 ; nearest Rs 100 -> 41100
```

The first row matches the contract vector (45,000, November 2026, starting the 15th → 24,000).

---

## 6. Official links for the site

These links are as the search index listed them on 2026-11-05. I did not open them from this session.

- **Punjab police registration:**
  - [Punjab Police TRS](https://punjabpolice.gov.pk/trs)
  - [Lahore Police tenants registration](https://lahorepolice.punjab.gov.pk/tenants-registration)
  - [Police Khidmat Markaz services](https://pkm.punjab.gov.pk/public/app/our_services?id=i)
  - [Punjab Act 2015](http://punjablaws.gov.pk/laws/2591.html)
- **Sindh police registration:**
  - [TRUST portal](https://tenantregister.sindhpolice.gov.pk/)
  - [Karachi Police how-to](https://karachipolice.gov.pk/services/how-to-apply-for-tenant-registration-process/)
  - [Sindh Act XXI of 2015](https://www.pas.gov.pk/uploads/acts/Sindh%20Act%20No.XXI%20of%202015.pdf)
- **KP police registration:**
  - [KP Act 2014 (KP Code)](https://kpcode.kp.gov.pk/uploads/2014_14_THE_KHYBER_PAKHTUNKHWA_RENTED_BUILDINGS_SECURITY_ACT_2014.pdf)
  - [KP Police TIF form](https://www.kppolice.gov.pk/photos/cba.pdf)
  - [Peshawar Police tenants](https://www.peshawarpolice.gov.pk/tenant.php)
- **Balochistan police registration:** [Act 2015 (Balochistan Code)](http://balochistancode.gob.pk/lawdir/404fb117-5e1b-4040-a6a6-2b88c2369f3a.pdf)
- **ICT police registration:** [ICT Police tenant registration](https://islamabadpolice.gov.pk/srv-tr.php)
- **Tenancy law:**
  - [Punjab Rented Premises Act 2009](http://punjablaws.gov.pk/laws/498.html)
  - [Sindh Rented Premises Ordinance 1979](https://www.sindhlaws.gov.pk/setup/publications_SindhCode/PUB-15-000484.pdf)
  - [Islamabad Rent Restriction Ordinance 2001](https://pakistancode.gov.pk/pdffiles/administratorf55c8364472e13dc098d52c71def1f58.pdf)
  - [West Pakistan Urban Rent Restriction Ordinance 1959 (KP Code)](https://kpcode.kp.gov.pk/uploads/1959_06_THE_WEST_PAKISTAN_URBAN_RENT_RESTRICTION_ORDINANCE_1959.pdf)
  - [Registration Act 1908](https://pakistancode.gov.pk/pdffiles/administrator0f29bc9f1e3dfed37c0034eed1e29d53.pdf)
- **E-stamp:**
  - [PITB e-Stamping](https://pitb.gov.pk/estamping)
  - [Board of Revenue Punjab e-stamping](https://bor.punjab.gov.pk/node/135)
- **Tax:**
  - [FBR WHT Rate Card TY2027](https://download1.fbr.gov.pk/Docs/202681113864992WithholdingTaxRatesCard2027.pdf)
  - [FBR rate-card index](https://fbr.gov.pk/withholding-taxes-rate-card/174298/174301)
  - [Income Tax Ordinance 2001 (FBR, 2026)](https://download1.fbr.gov.pk/Docs/2026724177725705IncomeTaxOrdinanace2001.pdf)
  - [Finance Act 2026](https://download1.fbr.gov.pk/Docs/20266291261044366FinanceAct2026.pdf)
  - [FBR Circular 02 of 2026-27](https://download1.fbr.gov.pk/Docs/202698139527880CircularNo.2of2026-27.pdf)
  - [ATL search](https://e.fbr.gov.pk/ATLSearchUtilityIT.aspx)
  - [FBR ATL page](https://www.fbr.gov.pk/categ/active-taxpayer-list-income-tax/51147/30859/71169)
- **Utilities:**
  - [NEPRA CSM Revised 2025](https://nepra.org.pk/Legislation/7-Manuals/2025/CONSUMER%20SERVICE%20MANUAL%20%28CSM%29%20REVISED%202025.pdf)
  - [SNGPL change of name](https://www.sngpl.com.pk/page.jsp?pgids=1786&pgname=PAGES_NAME_a&secs=ss7xa852op845&cats=ct456712337&artcl=artuyh709123465)
  - [SSGC consumer service manual page](https://www.ssgc.com.pk/web/?page_id=4470)

---

## 7. Corrections to `legal-tax-formats.md`

Each item names the section, what it said, and what it should say.

1. **§2 table and implications, KP deadline.**
   - It said "tenant 24 hours (enacted text) vs landlord 3 days (2014 ordinance), conflicting".
   - **Correction:** under s.4(1) of the enacted Act, the landlord, lessee or manager (and any property
     dealer) reports within **7 days, excluding public holidays, of signing the agreement**. The 24 hours
     is the **tenant's** duty under s.6 to produce documents when police ask (KP-2, KP-4).
2. **§2 table, KP penalty.**
   - It said "UNVERIFIED".
   - **Correction:** under s.10, imprisonment up to **1 year, or a fine, or both**; there is an abetment
     limb; under s.12 the offence is cognizable, non-bailable and tried by a JMFC (KP-5). Dawn's 2014
     "6 months / Rs 10,000–100,000" conflicts with the text.
3. **§2 table, Balochistan deadline and penalty.**
   - It said both were "UNVERIFIED".
   - **Correction:** within **3 days of signing the agreement**, on Form-I, to the SHO of the police
     station or Levies thana; up to 1 year, or a fine, or both (BL-2, BL-4). A LUMS paper says 15 days
     (conflict noted).
4. **§2 table, Balochistan "registration made mandatory April 2026".**
   - **Correction:** the Act has required it since 2015. In April 2026 the government announced
     province-wide enforcement (BL-5).
5. **§2 table, Sindh penalty.**
   - It said "Rs 10,000–45,000 (verify)".
   - **Correction:** verified as s.11, imprisonment up to 6 months **and** a fine of Rs 10,000–45,000;
     s.12 cognizable and non-bailable. Added: guests within 3 hours (SD-2, SD-5).
6. **§2 table, Sindh TRUST "mobile OTP sign-up".**
   - **Correction:** the portal's login offers **email or CNIC**; OTP was not confirmed (SD-6).
7. **§2 table, Punjab penalty.**
   - **Refinement:** the offence requires a *knowing* breach. Compounding (minimum Rs 10,000) is barred
     for repeat offenders (PB-3, PB-4).
8. **§2 table, Punjab "free, about 15–20 min".**
   - **Correction:** "free" and "15–20 min" describe **in-person, on-the-spot** registration on the Lahore
     Police page. No fee is stated for the online route (PB-7).
9. **§2 table, ICT.**
   - It said "s.144 orders renewed about every 2 months; Rs 500, 1 working day".
   - **Correction:** I found one past two-month tenant order (Dawn, about 2022) and **no 2026
     tenant-specific order**. Rs 500 appears in one excerpt of the ICT Police page; "1 working day" is
     secondary only (ICT-1, ICT-4).
10. **§2 implications, deadlines.**
    - It said "KP, Balochistan and ICT +24 hours, labelled as an app default".
    - **Correction:** the law gives **KP 7 days** and **Balochistan 3 days**, both from **signing**. Punjab
      and Sindh run from **delivery of possession**. ICT has no statutory deadline.
    - `app.police_registration_deadline_days` returns 1 day for KP, Balochistan and ICT. That is stricter
      than the law; the website must state the law.
11. **§2 "What is collected", KP.**
    - **Addition:** an attested copy of the tenant's CNIC is also required, and the "male occupants" are
      **male members over 14** (KP-3).
12. **§1 Punjab s.9.**
    - It said "5% of annual rent (tenant)… landlord's fine is 10% (verify)".
    - **Correction:** verified: tenant **5%**, landlord **10%** of the annual value of rent (PRA-5).
13. **§1 Punjab s.15.**
    - It said "30 days (UNVERIFIED)"; "personal need UNVERIFIED".
    - **Correction:** the ground is rent unpaid **30 days after the period in s.7**. "Personal need" is
      **not** a ground (PRA-6).
14. **§1 Punjab increases and the task brief's "Punjab Act's 10% a year default".**
    - **Correction:** no statutory default was found in the Punjab Act. The statutory **10%-a-year
      default is ICT's** (PRA-7, ICT-R1). §7's "the statutes point to about 10%" is overbroad.
15. **§1 Sindh.**
    - It said "I found no registration requirement".
    - **Correction:** s.5 requires the agreement **in writing**, and attested by the Controller, a Civil
      Judge or a First Class Magistrate if it is not registered (SRPO-1). The 10%-a-year increase after 3
      years is confirmed from the statute, and applies **only after fair rent is fixed** (SRPO-3).
16. **§1 ICT amendment.**
    - It said "passed by the National Assembly; whether finally enacted is UNVERIFIED".
    - **Correction:** enacted as the **Islamabad Rent Restriction (Amendment) Act 2021 (XLVII of 2021)**.
      The new s.10 gives an automatic 10% a year unless agreed otherwise in writing. PIDE's "25% in 3
      years or 10% in a year" mixes the original 2001 text with the amendment (ICT-R1). The 30-day filing
      with the Controller is from the bill text (ICT-R2, Medium).
17. **§1 KP and Balochistan rent law.**
    - It said "found no KP Rented Premises Act 2019 … appear to still use 1959 (UNVERIFIED, blog)".
    - **Correction:** now supported by the KP Code and PHC judgments from 2019 and 2025. Under the 1959
      Ordinance a fair-rent increase is capped at **25%** of the current rent; "cannot change for 3 years"
      was not confirmed for KP (KPR-1, KPR-2). Balochistan remains Low (BLR-1).
18. **§3 s.155 rates.**
    - It said "unchanged in TY2027", from secondary sources.
    - **Correction:** now confirmed from the **FBR TY2027 rate card** excerpt and the KPMG TY2027 card.
      FBR Circular 02 of 2026-27 shows no s.155 change (TX-12, TX-13).
19. **§3 non-filers.**
    - It said "Non-filers pay double (Tenth Schedule)".
    - **Refinement:** company 30% is confirmed. For individuals and AOPs the 100% increase is supported by
      the current FBR cards and PwC, but the 2020 and 2021 FBR cards excluded s.155 from the Tenth
      Schedule (Finance Act 2019). The amending Act was not found (TX-14, Medium).
20. **§3 prescribed persons.**
    - It said "2013 list".
    - **Refinement:** the 2018 FBR brochure lists the same categories, including provincial and local
      governments and charitable institutions. The 2026 text was still not seen (TX-11).
21. **§3 s.15A.**
    - It said "insurance, property tax and ground rent (from memory; verify)".
    - **Correction:** the insurance premium and mortgage interest are confirmed in a text excerpt. The 4%
      cap is confirmed by PwC (an older reproduction says 6%). Property tax, ground rent, legal costs and
      irrecoverable rent appear in secondary sources only (TX-7 to TX-9).
22. **§3 s.7E.**
    - It said "Finance Act 2026 … s.7E deemed income was abolished".
    - **Refinement:** the Federal Constitutional Court declared it ultra vires (6 or 7 May 2026; sources
      differ). The **Finance Act 2026 omitted s.7E** and Division VIIIC (FBR Circular 02 of 2026-27) (TX-5).
23. **§3 implications, "expected withholding = slab tax × period share".**
    - **Correction:** no official source prescribes this proration. Label it an assumption (TX-17).
24. **§3 Division I rates and surcharge.**
    - **Refinement:** PwC confirms the first three non-salaried bands for TY2027. The salaried surcharge is
      abolished by the Finance Act 2026; the 10% non-salaried surcharge above Rs 10 million continues. The
      upper bands are unconfirmed (TX-4). Not for publication (D-10).
25. **§6 NEPRA clause citations.**
    - It cited "clause 8.5a(iii)", "8.2.8" and "7 days' notice".
    - **Correction:** not found in today's excerpts, and the CSM was revised on 26 November 2025. Replace
      them with the verified points: the landlord's stamp-paper liability for a tenant's default;
      disconnection on the owner's request after 3 months' default; change of name only with no arrears;
      the 2021 eligibility rule; clause 8.1 (UT-1 to UT-6).
26. **§7 stamp duty.**
    - **Refinement:** lease duty is still UNVERIFIED. The 2026 Punjab ordinance's 1% applies to
      immovable-property transactions, not shown to cover leases. The official route is PITB e-Stamping
      (PRA-8).
27. **§7 "11 months vs 1 year".**
    - It relied on an Indian source.
    - **Correction:** there are now Pakistani sources: the Pakistan Code text of the Registration Act 1908
      and SHC rulings applying s.17(1)(d) (REG-1, Medium).

---

## 8. Uncertainties

1. **The s.155 individual and AOP non-ATL rule (TX-14).** The FBR 2020 and 2021 cards excluded s.155 from
   the Tenth Schedule; the 2023, 2025 and 2027 cards cite rule 1. Read the TY2027 card's non-ATL column and
   the current Tenth Schedule in full before launch. The calculator's non-ATL column depends on it.
2. **The full FBR TY2027 card was never read.** Only search excerpts were seen. The upper individual bands
   and the company row rest on the TY2026 FBR card plus KPMG's TY2027 card.
3. **The current s.155 prescribed-person list** (2026 consolidated Ordinance) was not seen.
4. **How s.155 applies to monthly payments, part years and mid-year rent changes**: no official method was
   found.
5. **The KP 7-day wording**: seen in the legislation.pk copy only. Confirm against the KP Code PDF.
6. **The Balochistan deadline**: 3 days (Act excerpt) against 15 days (LUMS).
7. **ICT:**
   - the Rs 500 fee;
   - whether any tenant-specific s.144 order is in force;
   - the enacted wording of the 30-day filing with the Controller;
   - the Pakistan Code "Lapse Date: July 29 2022" field;
   - whether ICT-R4 survives the 2021 amendment.
8. **The Punjab Rent Registrar**: any deadline or fee, and who holds the post in each district.
9. **Lease stamp duty** in Punjab, Sindh, KP and ICT after the 2024–2026 changes.
10. **s.15A**: property tax, ground rent, legal costs and irrecoverable rent; 4% against 6% (PwC says 4%).
11. **The 4% deemed commercial rent**: PwC says it is in force, KPMG says it was withdrawn.
12. **NEPRA CSM 2025**: whether a new owner or occupier must, in general, clear a predecessor's arrears; the
    current clause numbers.
13. **Balochistan rent-law text** (applicability of the 1959 Ordinance).
14. **The Supreme Court citation** for agreed periodic increases (REG-2).
15. **TY2027 non-salaried slabs above Rs 1.6 million** (not needed for the site under D-10).
16. **Carried over, not re-verified today:**
    - Sindh s.3(3), one report covering everyone;
    - Punjab s.5, the CNIC check and copy to police;
    - the steps of the Punjab online form;
    - the 2026 enforcement figures (Karachi arrests, ICT registrations);
    - the list of 12 DISCOs.
17. **Closing these.** Allow these hosts in the session's network settings, then re-read the primary texts
    with WebFetch:
    - `punjablaws.gov.pk`, `punjabcode.punjab.gov.pk`
    - `www.fbr.gov.pk`, `download1.fbr.gov.pk`, `e.fbr.gov.pk`
    - `pakistancode.gov.pk`, `kpcode.kp.gov.pk`, `balochistancode.gob.pk`, `pas.gov.pk`, `sindhlaws.gov.pk`
    - `islamabadpolice.gov.pk`, `punjabpolice.gov.pk`, `tenantregister.sindhpolice.gov.pk`
    - `nepra.org.pk`, `sngpl.com.pk`, `ssgc.com.pk`
