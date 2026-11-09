# Maalik-e-Makaan: legal, tax and data-format brief (Pakistan)
Researched 2026-11-03. This is not legal advice.

**Method.** Every fact comes from a web-search excerpt of the cited page; I could not read any page in full. WebFetch was blocked by network policy (khalidzafar.com, zameen.com). The search budget ran out before I could research §8 or stamp-duty rates. Anything I could not confirm is marked **UNVERIFIED**.

## 1. Tenancy law by jurisdiction

**Punjab (Rented Premises Act 2009)**
- No letting without a tenancy agreement (s.5(1)). The **landlord** must present it to the **Rent Registrar** (s.5(2)), who records and seals it, keeps a copy and returns the original. The registered copy proves the tenancy (s.5(3),(5)). Registration Act duties still apply (s.5(4)). [punjablaws](http://punjablaws.gov.pk/laws/498.html)
- **I found no deadline or fee** for presenting the agreement. One commentary says "30 days" (**UNVERIFIED**).
- s.6 contents ("as far as possible"):
  - landlord and tenant particulars
  - description of the premises
  - period of tenancy
  - rent, **rate of enhancement**, due date and payment mode
  - advance rent, security and pagri

  s.7: the tenant pays by the mode and date agreed. I found no statutory default increase. [punjablaws](http://punjablaws.gov.pk/laws/498.html)
- s.9: if the tenancy does not conform, the Rent Tribunal will not hear the tenant until he pays a fine of **5% of annual rent**. A slide deck says the landlord's fine is 10% (verify). [punjablaws](http://punjablaws.gov.pk/laws/498.html), [slides](https://www.slideshare.net/slideshow/punjab-rent-premisesact2009/51631675)
- s.15 eviction grounds:
  - the tenancy period has expired
  - rent unpaid **30 days** after it was due (day count **UNVERIFIED**)
  - breach of the agreement or the law
  - use for a different purpose
  - subletting without written consent

  Whether personal need is a ground is **UNVERIFIED**. [punjablaws](http://punjablaws.gov.pk/laws/498.html)
- The Lahore High Court says the Registrar cannot decide whether someone is a tenant; that is for the Rent Tribunal. [LHC](https://researchcenter.lhc.gov.pk/pdf/CaseLawBulletin/Bulletinfrom16.12.2023to31.12.2023_3d1a.pdf)

**Sindh (Rented Premises Ordinance 1979)**
- The Rent Controller fixes a "fair rent" (s.8). It lasts **3 years**; after that an increase of up to **10% a year** may be allowed (s.9, as Sindh High Court case law describes it). [SJA text](https://sja.gos.pk/assets/Updated_Laws/Sindh%20Rented%20Premises%20Ordinance,1979.pdf), [SHC](https://caselaw.shc.gov.pk/caselaw/view-file/MTMxODM1Y2Ztcy1kYzgz)
- If no due date is agreed, rent is due by the **10th of the next month** (s.10). This is how Sindh High Court judgments read it.
- Eviction grounds include default (s.15(2)(ii), whose time limits are **UNVERIFIED**) and bona fide personal need (s.15(2)(vii)). I found no registration requirement.

**ICT (Rent Restriction Ordinance 2001)**
- The Rent Controller decides evictions (s.17). PIDE summarises the increase rule as "25% in 3 years or 10% in a year". [PIDE](https://file.pide.org.pk/uploads/kb-092-a-review-of-urban-rental-housing-regulations-in-pakistan-and-lessons-from-practices-in-developed-world.pdf)
- A 2020 amendment would have added:
  - an automatic **10% annual increase** unless otherwise agreed in writing
  - agreements lodged with the Rent Controller
  - payment by crossed cheque

  The National Assembly passed it; whether it was finally enacted is **UNVERIFIED**. [NA](https://www.na.gov.pk/uploads/documents/61c4711c139b9_755.pdf), [Dawn](https://www.dawn.com/news/amp/1586314)
- A tenant can reportedly be evicted if rent is unpaid **15 days** after the agreed date. [Tribune](https://tribune.com.pk/story/28596/traders-call-for-revision-of-%e2%80%98biased%e2%80%99-rent-control-ordinance?amp=1)

**KP and Balochistan**
- I **found no "KP Rented Premises Act 2019"** on the KP Assembly or KP Code sites. Both provinces appear to still use the 1959 Urban Rent Restriction Ordinances, under which a Controller fixes the rent and it cannot change for 3 years. The source is a blog (**UNVERIFIED**). [Zameen blog](https://www.zameen.com/blog/your-101-on-pakistans-rental-laws.html)
- PIDE says provincial caps are about 10%, sometimes 5%. [PIDE](https://pide.org.pk/research/a-review-of-urban-rental-housing-regulations-in-pakistan-and-lessons-from-practices-in-developed-world/)

**Implications for the app**
- Give each property a `jurisdiction` (PUNJAB / SINDH / ICT / KP / BALOCHISTAN / AJK / GB) and keep the rules as versioned data.
- Agreement fields follow Punjab s.6. Make the enhancement % and its interval **required**. Also record permitted use and subletting consent.
- Punjab: track `rent_registrar_status` (not presented / presented / registered), the date and office, and a scan of the sealed copy. Any reminder interval is an app default, not law.
- Sindh: if no due day is agreed, default to the 10th of the next month.
- Log payment dates and days overdue. Show "overdue N days"; never call a tenant legally "in default".

## 2. Police tenant registration

| Jurisdiction | Law | Deadline after possession | Penalty | Online channel |
|---|---|---|---|---|
| Punjab | Information of Temporary Residents Act 2015 | **15 days** (s.3; landlord, tenant and dealer are all liable) | up to 6 months **and** Rs 10,000–100,000; non-bailable; can be settled for at least Rs 10,000 | TRS portal, Khidmat Markaz, Lahore Police app; free, about 15–20 min |
| Sindh | Information of Temporary Residents Act 2015 | **48 hours** (s.3(1)); one person's report covers the others (s.3(3)) | up to 6 months + Rs 10,000–45,000 (verify) | **TRUST** portal, launched Dec 2025, mobile OTP sign-up |
| ICT | District Magistrate orders under s.144 CrPC, renewed about every 2 months | none fixed | under the s.144 order | TRS portal and Khidmat Markaz; **Rs 500**, 1 working day |
| KP | Restriction of Rented Buildings (Security) Act 2014 | tenant 24 hours (enacted text) vs landlord 3 days (2014 ordinance), conflicting | **UNVERIFIED** | none found |
| Balochistan | Rented Buildings (Security) Act 2015 | **UNVERIFIED** | **UNVERIFIED** | registration made mandatory April 2026 |

Sources:
- Punjab: [Act](http://punjablaws.gov.pk/laws/2591.html), [TRS](https://punjabpolice.gov.pk/trs), [Khidmat Markaz](https://pkm.punjab.gov.pk/public/home/services?id=i)
- Sindh: [Act](https://www.shrc.org.pk/downloads/laws/Sindh/The-Sindh-Information-of-Temporary-Residents-Act-2015.pdf), [TRUST](https://tenantregister.sindhpolice.gov.pk/), [Tribune](https://tribune.com.pk/story/2582788/sindh-police-launches-online-system-for-tenant-registration)
- ICT: [s.144 order](https://www.zameen.com/news/district-magistrate-prohibits-renting-out-of-property-in-capital-without-informing-police.html), [ICT Police](https://islamabadpolice.gov.pk/srv-tr.php)
- KP: [Act](https://www.pakp.gov.pk/wp-content/uploads/2024/05/The-Khyber-Pakhtunkhwa-Restriction-of-Rented-Buildings-Security-Act-2014-Act-No.-XIV-2014.pdf), [Dawn](https://www.dawn.com/news/1087603)
- Balochistan: [Act](https://balochistan.gov.pk/wp-content/uploads/2024/10/Rented-Buildings-Security-Act-2015.pdf), [ProPakistani](https://propakistani.pk/2026/04/15/balochistan-makes-tenant-registration-mandatory/)

**What is collected**
- **Punjab and Sindh in person:** owner's and tenant's CNICs (original and copy), the rent agreement, an affidavit and the tenant's photo. Sindh issues a certificate. [Lahore Police](https://lahorepolice.punjab.gov.pk/tenants-registration), [Karachi Police](https://karachipolice.gov.pk/services/how-to-apply-for-tenant-registration-process/)
- **Punjab online form:** the owner's CNIC (front and back) and a passport photo. The steps are Scan Documents → Owner → Tenant → **Adults with Tenant** → Property, and CNIC fields are mandatory. [Kiosk](https://kiosk.pkm.punjabpolice.gov.pk/tenants/create)
- **ICT:** CNIC front and back, a passport photo, the lease, a photo of a thumb impression on paper, photos of both parties, and the agreement on an affidavit. The tenant must be present. [ICT](https://islamabadpolice.gov.pk/ipwe/tenant.php)
- **KP:** an attested agreement, the male occupants over 14, and two references. [Dawn](https://www.dawn.com/news/1087603), [ecoi](https://www.ecoi.net/en/document/1424022.html)
- **Identity check:** landlords must check identity from a CNIC or passport and give police a copy (Punjab and Sindh s.5).
- **Enforcement in 2026:** arrests in Karachi in April 2026, and over 14,000 ICT registrations in March 2026. [ProPakistani](https://propakistani.pk/2026/04/25/sindh-starts-arresting-tenants-and-landlords-who-fail-to-register/), [APP](https://www.app.com.pk/?p=1185827)
- I found no route through the Pakistan Citizen Portal and no API.

**Implications for the app**
- Create a police-registration task due from `possession_date`:
  - Punjab +15 days
  - Sindh +48 hours
  - KP, Balochistan and ICT +24 hours, labelled as an app default
- Collect:
  - owner and tenant CNIC images and photos
  - adult co-occupants (name, CNIC, relation)
  - property address
  - agreement and affidavit scans
  - thumb-impression image (ICT)
  - two references (KP)
  - mobile numbers
- Make previous address and employer optional; I found them in no official list.
- Store the channel, certificate or receipt number, date, fee and receipt image. Deep-link to the portals; submission is manual.

## 3. Rental income tax
- **Tax year** (s.74(1)): the 12 months ending 30 June, named by the calendar year it ends in. TY2026 is 1 Jul 2025–30 Jun 2026. **Today falls in TY2027** (Finance Act 2026). [FBR](https://download1.fbr.gov.pk/Docs/202176137832982wpno39256of2021.pdf), [pkrevenue](https://pkrevenue.com/fbr-explains-duration-of-tax-year-in-pakistan/)
- **Rent is not taxed separately.** The Finance Act 2021 **deleted Division VIA**. Since TY2022, individuals and AOPs work out net property income (ss.15/15A) and add it to their other income at the normal Division I rates. PwC confirms the block rates are "no longer applicable". So TY2025 and TY2026 have **no Division VIA slabs**. The widely quoted 300k/600k/2M slabs are **s.155 withholding** rates. [Business Recorder](https://www.brecorder.com/news/40104544/fbr-explains-taxation-of-property-salary-income), [PwC](https://taxsummaries.pwc.com/pakistan/individual/income-determination)
- **Division I rates for non-salaried individuals and AOPs, TY2025.** [PwC](https://taxsummaries.pwc.com/pakistan/individual/taxes-on-personal-income), [rate card](https://muhasibandco.com/wp-content/uploads/2025/04/Tax_Rate_Card_for_Tax_Year_2024_25.pdf)

  | Taxable income (Rs) | Tax |
  |---|---|
  | up to 600,000 | 0 |
  | 600,001–1,200,000 | 15% of the excess over 600,000 |
  | 1,200,001–1,600,000 | 90,000 + 20% |
  | 1,600,001–3,200,000 | 170,000 + 30% |
  | 3,200,001–5,600,000 | 650,000 + 40% |
  | over 5,600,000 | 1,610,000 + 45% |

  - TY2026: I found no change by the Finance Act 2025 (**UNVERIFIED**).
  - Salaried rates apply when salary is more than 75% of taxable income.
  - Surcharge: 10% for non-salaried taxpayers above Rs 10m. The salaried surcharge was 9% in TY2026 and is abolished from TY2027.

  [ICMAP](https://www.icmap.com.pk/downloads/RP_Portal_Files/PreBudgetProposalsBooklets/TaxBriefAmendmentsmadethroughthefinanceact2025.pdf)
- **s.15A deductions apply to all taxpayers:**
  - repairs allowance of **1/5 of rent** (buildings only)
  - interest on loans to buy or build
  - administration and collection costs up to **4%** of rent
  - legal costs of defending title
  - irrecoverable rent
  - insurance, property tax and ground rent (from memory; verify)

  [pkrevenue](https://pkrevenue.com/tax-on-income-from-property-under-updated-ordinance/)
- Finance Act 2025 change: business losses can no longer be offset against property income. [FBR Circular 01/2025-26](https://download1.fbr.gov.pk/Docs/2025841183918948CircularNo01of2025-26IncomeTax.pdf)
- Finance Act 2026 change: s.7E deemed income was abolished. [PwC](https://taxsummaries.pwc.com/pakistan/individual/significant-developments)
- **s.155 withholding.** Tax is deducted from **gross** rent, including furniture and services, when it is paid.
  - "Prescribed persons" who must deduct (2013 list; the current list is **UNVERIFIED**):
    - federal, provincial and local governments
    - companies
    - non-profits
    - diplomatic missions
    - private schools, boutiques, beauty parlours, hospitals, clinics and maternity homes
    - individuals or AOPs paying **Rs 1.5m a year or more**

    [FBR 2013](https://download1.fbr.gov.pk/Docs/201372214742171992013CIRCULAR06.pdf)
  - Rates for filers (on the Active Taxpayer List, ATL), TY2026, **unchanged in TY2027**:

    | Payee | Gross annual rent (Rs) | Tax |
    |---|---|---|
    | Individual or AOP | up to 300,000 | nil |
    | Individual or AOP | 300,001–600,000 | 5% of the excess over 300,000 |
    | Individual or AOP | 600,001–2,000,000 | 15,000 + 10% of the excess over 600,000 |
    | Individual or AOP | over 2,000,000 | 155,000 + 25% of the excess over 2,000,000 |
    | Company | any | 15% |

  - Non-filers pay **double** (Tenth Schedule): a company pays 30%. The tax is **adjustable** against the final bill, not final.
  - TY2025 withholding rates were not checked separately.

  [FBR TY2026 card](https://download1.fbr.gov.pk/Docs/20258181281745641WHT-RateCard.pdf), [KPMG](https://assets.kpmg.com/content/dam/kpmg/pk/pdf/2025/07/Withholding%20Tax-Collection-Deduction%20Rate-Card-TY-2026.pdf), [pkrevenue TY2027](https://pkrevenue.com/fbr-issues-tax-rates-on-property-income-for-ty-2027/), [Trustpoint](https://www.trustpointconsultants.com/withholding-tax-card-2026-27.html)

**Implications for the app**
- `taxYear(d)` = d.year if the month is June or earlier, otherwise d.year + 1. Label years as "TY2027 (Jul 2026–Jun 2027)".
- Keep the s.155 and Division I tables as data, one version per tax year.
- Fields:
  - `tenant.withholding_agent_type`
  - `landlord.atl_status` and the date it was checked
  - the challan or CPR number for each payment
- Expected withholding = (slab tax on annual rent) × (period's share of the year).
- Tag expenses: auto 1/5 repairs, the 4% cap, interest, legal costs, property tax.
- Export a statement per tax year (gross rent, tax withheld, deductions). Any final tax figure is an **estimate**.

## 4. Property tax (brief)
- **Punjab:** the old basis was 5% of annual rental value, according to the Excise page. An extract of the Act gives 10%, so the rate is in conflict. Paying by **30 September** earned a 5% rebate; late payment adds 1% a month.
  - **From 1 Jan 2025** tax is based on **capital value (DC rates)** with self-assessment, and properties worth under **Rs 5m are exempt**. Whether the rebate survives is **UNVERIFIED**.
  - Payment is by ePay Punjab with a **17-digit PSID** through a bank, ATM or over the counter.

  [Excise](https://excise.punjab.gov.pk/property_tax), [Excise CV](https://excise.punjab.gov.pk/node/3435), [Dawn](https://www.dawn.com/news/1930358), [ePay](https://apps.apple.com/us/app/id1465068821)
- **Sindh:** 25% of annual rental value (older report). Collection through the Board of Revenue's e-stamping has been launched; details are **UNVERIFIED**. [Dawn](https://dawn.com/news/amp/1293311), [Dawn](https://www.dawn.com/news/1994274)
- **ICT:** the Islamabad High Court (Sept 2025) struck down MCI's 2024 notification, so pre-2018 rates apply. 2026-27 bills carry a 5% early-payment rebate. Pay through 1Link using **122001** + the consumer number. [ProPakistani](https://propakistani.pk/2025/09/25/ihc-strikes-down-property-tax-notification/amp/), [Minute Mirror](https://minutemirror.com.pk/mci-to-issue-2026-27-property-tax-bills-within-10-days-rebate-deadline-extended-622331/), [CDA](https://owo.cda.gov.pk/duplicatepropertybill.aspx)

**Implications for the app:** store the tax authority, property ID, basis (rental or capital value), demand, due and rebate dates, PSID or consumer number, and receipt. Send a Punjab reminder before 30 September. Feed amounts paid into s.15A.

## 5. Identity and formatting
- **CNIC**: 13 digits, written `XXXXX-XXXXXXX-X`; no checksum algorithm is published. [Wikipedia](https://en.wikipedia.org/wiki/CNIC_(Pakistan)), [Tribune](https://tribune.com.pk/story/1403682/theres-cnic-number-know?amp=1)
  - The first 5 digits are the locality; the 1st digit is the region: 1 KP, 2 FATA, 3 Punjab, 4 Sindh, 5 Balochistan, 6 ICT, 7 GB, 8 AJK.
  - The last digit is **odd for male, even for female**. Transgender people get the parity of the gender they identify with.
- **NICOP** uses the same 13-digit number. The **POC** number format is **UNVERIFIED**. [ecoi/NADRA](https://www.ecoi.net/en/document/1457387.html)
- **Mobile numbers**: `+92 3XX XXXXXXX` (11 digits in the national form 03…). [Wikipedia](https://en.wikipedia.org/wiki/Telephone_numbers_in_Pakistan), [ProPakistani](https://propakistani.pk/2009/01/06/state-of-mobile-number-portability-in-pakistan/)
  - Prefixes: 030x Jazz, 031x Zong, 032x Jazz (formerly Warid), 033x Ufone, 034x Telenor, **0355** SCO.
  - Number portability has existed since 2007, so the prefix ≠ the operator.
- **Landlines**: area codes are 2–5 digits. Karachi 021 and Lahore 042 have **8-digit** numbers (since 2009); Islamabad 051 has 7 (for example 051-9252823). [Wikipedia](https://en.wikipedia.org/wiki/Telephone_numbers_in_Pakistan), [CDA](https://owo.cda.gov.pk/duplicatepropertybill.aspx)
- **IBAN**: **24 characters** = `PK` + 2 check digits + a 4-letter bank code + a 16-character account number, checked with ISO 13616 **mod-97**. SBP mandated it in 2012, with full use from June 2013. [SBP](https://www.sbp.org.pk/press/2012/IBAN-Implementation-15-May-12.pdf), [SBP spec](https://www.sbp.org.pk/assets/documents/circulars/PSD-2014-C1-Annex.pdf), [Wise](https://wise.com/us/iban/pakistan)
- **Raast**: the Raast ID is the registered mobile number, linked to **one IBAN at a time**. P2P transfers are free. SBP dropped its own limits on 1 April 2022; banks now set limits, but each transaction must allow **at least PKR 200,000**. Merchant payments support QR codes and Request-to-Pay. [Business Recorder](https://www.brecorder.com/news/amp/40161305), [SBP](https://www.sbp.org.pk/circulars/disd-circular-no-1-of-2022), [ProPakistani](https://propakistani.pk/2022/02/03/sbp-introduces-instant-and-free-p2p-payments-under-raast/), [BOP](https://bop.com.pk/view.aspx?id=3363), [Profit](https://profit.pakistantoday.com.pk/2023/12/06/sbp-launches-raast-p2m-service-to-facilitate-digital-payment-acceptance)
- **Rupee formatting**: FBR and SBP use **Western grouping** ("Rs. 2,000,000", "PKR 200,000"). [FBR card](https://download1.fbr.gov.pk/Docs/20258181281745641WHT-RateCard.pdf)
  - A local check of CLDR data (Node 22 / ICU 78.3 / CLDR 48), for both `en-PK` and `ur-PK`:
    - grouping 1,234,567
    - symbol **"Rs"** with **0** decimal places by default
    - `ur-PK` uses Latin digits
    - Urdu compact form "1.3 کروڑ" (crore); English gives "13M"
    - date format dd/MM/yyyy
  - Lakh/crore wording is common in speech (**UNVERIFIED**).

**Implications for the app (validators)**
- **CNIC**: store the 13 digits; accept input with or without dashes. Warn, don't block, if the first digit isn't 1–8. **Never infer gender.** Mask in lists (`35202-*******-3`).
- **Mobile**: normalise to `^\+923\d{9}$`, accepting `+92`, `0092`, `92` or `0` before `3XXXXXXXXX`. Warn, don't block, if the prefix is outside 30–34x/355. Validate landlines with libphonenumber.
- **IBAN**: strip spaces, uppercase, then match `^PK\d{2}[A-Z]{4}[A-Z0-9]{16}$` and check mod-97 = 1. Display in groups of 4.
- **Money**: store integer rupees or paisa. Display "Rs 1,250,000", optionally followed by "(12.5 lakh)". Check Dart `intl` against CLDR.

## 6. Utilities
- **There are 12 electricity distribution companies (DISCOs):** FESCO, GEPCO, **HAZECO**, HESCO, IESCO, **K-Electric** (private since 2005), LESCO, MEPCO, PESCO, QESCO, SEPCO and TESCO. AJK bills also go through PITC. [Wikipedia](https://en.wikipedia.org/wiki/Electricity_distribution_companies_of_Pakistan), [PITC](https://bill.pitc.com.pk/lescobill)
- **Account numbers:**
  - Government DISCO bills carry a **14-digit reference number** (example `09269330553008`) plus a separate Customer ID, whose length is **UNVERIFIED**.
  - K-Electric uses a **13-digit account number**.
  - Gas numbers (SNGPL 11 digits, SSGC 10) come from weak sources: **UNVERIFIED**.

  [PITC example](https://bill.pitc.com.pk/pescobill/general?refno=09269330553008), [KE](https://ke.com.pk/?p=11950)
- PITC lets occupants register a CNIC and mobile number against the bill reference to get billing SMS. [PITC MNR](https://mnr.pitc.com.pk/about.html)
- **NEPRA decisions:**
  - Connections in the landlord's name mean the landlord is treated as the owner.
  - Arrears can be recovered from the occupant of the premises (Consumer Service Manual, clause 8.5a(iii)).
  - Several connections in one owner's name can all be affected by one default (clause 8.2.8).
  - Disconnection needs 7 days' notice.
  - The tenancy agreement does not bind the DISCO.
  - Sub-meter rules: none found.

  [NEPRA FESCO 2025](https://nepra.org.pk/consumer%20affairs/cad/Authority%20Decisions/FESCO/2025/11%20Nov/TCD-04%20FESCO%2013-11%202025%204983.PDF), [NEPRA KE](https://www.nepra.org.pk/consumer%20affairs/cad/Appellate%20Board/K-Electric/2019/Appeal-124%20K-electric%20VS%20Zahid%20Aziz%2021-03-2019.pdf), [SHC](https://caselaw.shc.gov.pk/caselaw/view-file/MjE0OTM1Y2Ztcy1kYzgz)

**Implications for the app**
- Per unit, store each connection:
  - provider (an enum, including SNGPL, SSGC and water)
  - reference or account number, digits only (length check warns, never blocks)
  - customer ID
  - name on the bill
  - meter number
  - sub-meter flag
- Each month, record the bill, its due date and the tenant's photo of the paid bill.
- At move-in and move-out, record meter readings with photos. Settle the final bill against the deposit.
- Warn landlords that arrears follow their connection.

## 7. Agreement and stamp-paper norms
- **11 months vs 1 year:** the Registration Act 1908 (s.17) makes registration compulsory for leases "from year to year, or for any term exceeding one year, or reserving a yearly rent". An 11-month agreement avoids that, though courts look at the substance. This comes from Indian commentary on the same Act; I found no Pakistan-specific source (**UNVERIFIED**). [Outlook Money](https://www.outlookmoney.com/invest/rent-agreements-over-11-months-must-be-registered-heres-why-it-matters)
- **Stamp duty (Punjab)** is in flux:
  - The Finance Act 2024 raised some fixed duties from Rs 1,200 to Rs 3,000; which instruments is unclear.
  - The 2026 Stamp ordinances cut transfer duty to 1% and reportedly revised the duty on residential leases.
  - Yellow e-stamp paper has been replaced by self-printed e-stamps.
  - **Current lease rates: UNVERIFIED.**

  [ProPakistani](https://propakistani.pk/2024/06/27/punjab-government-increases-court-fees-and-stamp-duties/amp/), [Tribune](https://tribune.com.pk/story/2603069/punjab-moves-to-cut-stamp-duty-on-property-transactions-from-3-to-1), [The News](https://www.thenews.pk/print/1410150-punjab-introduces-stamp-ordinance-2026), [Dawn](https://www.dawn.com/news/amp/1980696)
- **Rent increases:** the statutes point to about 10% (§1). A 10% annual increase is also the usual market assumption (**UNVERIFIED**).
- **Security deposit, advance rent and late fees:** I found no reliable source. "2–3 months' deposit + 1 month advance" is anecdotal. I found no statutory late fee, so any late fee is purely contractual.

**Implications for the app**
- Offer 11-month, 12-month or custom terms; flag anything over 1 year or with a yearly rent.
- Record the e-stamp number, amount and date as user input; don't calculate duty.
- Deposit, advance, grace days and late fee are configurable "as agreed". The annual increase defaults to 10% and is editable.

## 8. Data protection
- **UNVERIFIED (the search budget was exhausted; this is background knowledge):**
  - The Personal Data Protection Bill went through drafts from 2018 to 2023 and was reportedly revived in 2024–25. As far as I know it was **not enacted** by mid-2026.
  - PECA 2016 s.16 criminalises unauthorised obtaining or use of identity information. I recall up to 3 years or Rs 5m; this needs checking.
  - I found no NADRA rule on private parties keeping CNIC copies.
- **Sourced:** the temporary-residents laws **require** landlords to obtain the tenant's CNIC or passport copy and give it to police (Punjab and Sindh s.5). [Punjab Act](http://punjablaws.gov.pk/laws/2591.html), [Sindh Act](https://www.shrc.org.pk/downloads/laws/Sindh/The-Sindh-Information-of-Temporary-Residents-Act-2015.pdf)

**Implications for the app**
- Collect only what police registration needs, and record consent and purpose in Urdu and English.
- Keep CNIC images, photos and thumbprints in **private Supabase Storage** with row-level security, short-lived signed URLs and access logging.
- Mask CNICs; delete identity media N months after the tenancy ends; support export and delete requests.
- Choose the Supabase region with possible data-localisation rules in mind.

## Uncertainties
1. Punjab Rent Registrar **deadline and fee**, and s.15 details: the 30-day figure and personal need.
2. Whether a **KP Rented Premises Act 2019** exists. Also the KP, Balochistan and ICT police deadlines and penalties.
3. Whether the ICT 2020 amendment was enacted (10% automatic increase).
4. **TY2026 non-salaried slabs** (assumed equal to TY2025), TY2025 s.155 rates, and the current list of s.155 prescribed persons.
5. The Sindh fine range and the wording of its s.15(2)(ii) default ground.
6. Punjab capital-value tax rates and rebate; the Sindh process.
7. Punjab and Sindh **lease stamp duty** after the 2026 ordinances.
8. POC format, an official CNIC province-code list, the IBAN account-number character set, and gas account-number lengths.
9. **All of §8:** Personal Data Protection Bill status, PECA s.16, and NADRA rules on CNIC copies.
10. Access:
    - allow khalidzafar.com and zameen.com in the network settings
    - raise `CLAUDE_CODE_MAX_WEB_SEARCHES_PER_SESSION` to close items 1–9
