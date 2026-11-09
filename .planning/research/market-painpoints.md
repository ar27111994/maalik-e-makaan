# Maalik-e-Makaan: Market & Pain-Point Research

*Prepared 2026-11-03 for a Flutter + Supabase landlord app for Pakistan.*

**Method & caveats.** Evidence is from web search (Nov 2026). Page fetches were blocked by the network allowlist, and reddit.com by the search tool, so citations rest on search extracts and forum threads were unreadable. *(vendor)* = self-reported claim. **Evidence** = stated by the source. **Inference** = my reasoning. Re-check legal and tax figures before shipping them.

## Key takeaways
1. Renting is concentrated in the big cities and run informally: cash, 11-month agreements, ~10% yearly increases, 2–4 months' rent up front.
2. The biggest local risks are **utility arrears tied to the meter**, **police tenant registration (enforced with arrests)**, and, for overseas owners, **relatives or caretakers who misreport or occupy**.
3. No local app clearly owns the "ledger + WhatsApp + compliance" niche. India's RentOk shows the winning pattern.
4. WhatsApp Business API messages cost about 11× more in Pakistan than in India, so v1 should send messages through free wa.me links.
5. Build for low- and mid-range Android (≈91% share), in Urdu, Roman Urdu and English, and offline-first.

## 1. Landlord segments & workflows
**Evidence**
- About 7M households (13.6%) rent, per the 2023 census [Daily Times](https://dfnihf8fcqrzv.cloudfront.net/daily-times/sajid-salamat/bridging-the-home-ownership-gap-in-pakistan-/188470321). Renting is 36% of households in Karachi and Islamabad, against 20% in Lahore [Dawn](https://www.dawn.com/news/2004278).
- **Portions:** listings advertise a "separate electricity/gas meter" and terms like "2 rents security, 1 rent advance" [Zameen](https://www.zameen.com/Property/gulberg_gulberg_2_upper_portion_available_for_rent-53876497-3809-4.html), [Zameen](https://www.zameen.com/Property/lahore_wapda_town_10_marla_upper_portion_for_rent-53967738-423-4.html).
- **Up-front costs:** 2–4 months' deposit plus advance; dealers take one month's rent as commission [Tribune, Jun 2026](https://tribune.com.pk/story/2615392/the-rent-trap), about half a month in Islamabad [Zameen forum](https://www.zameen.com/forum/t/what-is-estate-agents-property-dealer-fee-for-finding-a-rental-property/10077).
- **Agreements:** usually 11 months with a 10% yearly increase [PPRA doc](https://ppra.org.pk/doc/19-7/pia197-88.pdf), [case law](https://pakcaselaw.duckdns.org/case/133291/ahmed-vs-miss-aisha-tariq-2011-clc-538). The Supreme Court enforces increases written into the agreement [SCC Online](https://www.scconline.com/blog/post/2019/03/18/pak-sc-cantonments-rent-restriction-act-does-not-prohibit-periodical-increase-in-rent-agreed-between-parties).
- **Hostels:** Punjab made HotelEye guest registration mandatory (deadline 15 Jun 2025) [ProPakistani](https://propakistani.pk/2025/05/22/punjab-makes-guest-tracking-mandatory-by-june-15/). HotelEye covers hostels and is linked to NADRA [PITB](https://pitb.gov.pk/hotel_eye). The CDA closed hostels in Islamabad residential areas [Dawn](https://www.dawn.com/news/1945947).
- **Shops:** Karachi's pagri arrangement has no legal recognition [The News](https://www.thenews.com.pk/print/389671-tenants-under-pagri-system-being-exploited-as-law-does-not-recognise-british-era-lease-mode).
- **Overseas owners, size:** 15.13M overseas-job registrations since 1971; this counts registrations, not unique people [ProPakistani](https://propakistani.pk/2026/07/08/1-5-crore-pakistanis-have-left-the-country-to-work-abroad/). The usual diaspora estimate is ~9M [ProPakistani](https://propakistani.pk/2022/01/13/graana-com-launches-overseas-property-verification-system/). Remittances hit a record $41.6B in FY26 [Tribune](https://tribune.com.pk/story/2617335/pm-shehbaz-hails-overseas-pakistanis-as-remittances-hit-416b-in-fy2025-26). The "~50% of remittances go to property" figure is unsourced [Graana](https://www.graana.com/blog/overseas-pakistanis-and-investments-in-real-estate/).
- **Overseas owners, problems:**
  - ~90% of overseas complaints concern illegal occupation, often by close relatives [Punjab govt](https://punjab.gov.pk/node/2038); the Punjab commission has 7,814 complaints, 3,579 resolved [Tribune](https://tribune.com.pk/story/2581682/expat-investors-bedeviled-by-property-fraud).
  - Typical pattern: a relative "looks after" the property with no paperwork, then later claims a gift or long possession [MAJ Legal](https://majlegal.com/blog/overseas-pakistani-property-disputes-resolution-in-karachi-pakistan/).
  - Special courts are set up or mandated in Islamabad [BR](https://www.brecorder.com/news/40353415), in 37 Punjab districts [Dawn](https://www.dawn.com/news/1954351), and in KP, where the 2026 Act also covers rent recovery [ProPakistani](https://propakistani.pk/2026/05/12/kp-assembly-passes-bill-for-special-courts-to-protect-properties-of-overseas-pakistanis/).
  - Property managers charge 5–10% of rent *(vendor)* [Chakor](https://chakorventures.com/?p=39494).
- **How rent is paid:**
  - Cash persists: currency in circulation ~Rs12tr in spring 2026, up ~28% year on year [Tribune](https://tribune.com.pk/story/2601433/currency-in-circulation-jumps-28).
  - Landlords "openly ask for cash" (anecdotal) [PakTaxCalculator](https://paktaxcalculator.pk/cash-only-businesses-to-avoid-taxes-in-pakistan/) and declare lower rents than they collect [Reanda](https://www.reanda-international.com/news/pakistan-income-from-property).
  - Raast person-to-person transfers are free and can use a mobile number as the account ID [Dawn](https://www.dawn.com/news/1673190), [SBP](https://www.sbp.org.pk/our-subsidiaries/raast/raast-person-to-person). Raast carried 1.28B such transfers in FY25 [Nukta](https://nukta.com/digital-payments-pakistan).
  - Account ownership: 35% of adults in the K-FIS 2024 survey [BR](https://www.brecorder.com/news/40371177/bridging-the-financial-gap-insights-from-karandaaz-financial-inclusion-survey-k-fisi), against ~64% bank-account coverage by the SBP's measure [Arab News](https://www.arabnews.pk/node/2591576).
- **How rent is recorded:** in registers, spreadsheets and WhatsApp chats, with one-by-one reminders *(vendor)* [Nexora](https://nexorasolution.us/blog/property-management-software-pakistan-guide/). Under Sindh law (s.10), rent is due by the 10th unless agreed otherwise, and courts accept a written acknowledgement, money-order receipt or Rent Controller receipt as proof of payment [SHC](https://caselaw.shc.gov.pk/caselaw/view-file/MTUwNjEyY2Ztcy1kYzgz).

**Inference**
- Segments: **(A)** local landlords with 1–5 units (ledger, reminders, receipts); **(B)** overseas owners with a caretaker (audit trail, statements); **(C)** hostels and PGs (per-bed billing, HotelEye); **(D)** small commercial (withholding, increments).
- Record cash first, with digital methods and proof photos alongside; do not assume online collection.

## 2. Pain points
**Evidence**
- **Late rent:** tenants pay "later and later… sometimes six months" late [Tribune](https://tribune.com.pk/story/2372372/renting-a-house-know-the-law); lateness snowballs if tolerated [Zameen](https://www.zameen.com/blog/dealing-problematic-tenants-pakistan.html). Eviction needs a Rent Controller or court order and takes a long time [GPG](https://www.globalpropertyguide.com/asia/pakistan/landlord-and-tenant). The Lahore High Court voided the decisions of Punjab's fast-track committees [Profit](https://profit.pakistantoday.com.pk/2026/02/24/lhc-voids-dispute-resolution-committees-decisions-transfers-1500-property-cases-to-tribunals).
- **Utilities:**
  - A Sindh judgment counts unpaid electricity as rent, and makes it a ground for eviction if it leads to disconnection [SHC](https://caselaw.shc.gov.pk/caselaw/view-file/MTYyMjI4Y2Ztcy1kYzgz).
  - Arrears attach to the premises: on a sold property they fall on the new occupant [NEPRA](https://www.nepra.org.pk/consumer%20affairs/cad/Authority%20Decisions/KESC/2016/TCD-09%20DECISION%20K-ELECTRCI%2003-02-2016%201711-12.pdf), and K-Electric may disconnect [NEPRA](https://www.nepra.org.pk/consumer%20affairs/cad/Appellate%20Board/K-Electric/2017/Appeal-162%20K-Electric%2019-07-2017.pdf).
  - An affidavit the landlord signs for a tenant's connection can make the landlord liable [Pakera](https://pakera.pk/electricity-tenant-landlord-unpaid-dues-nepra-pakistan/).
  - Going past 200 units/month loses the subsidised "protected" tariff for six months [ProPakistani](https://propakistani.pk/2024/07/08/huge-electricity-bills-shock-protected-customers/amp/). A second meter is allowed only for a separate unit [ProPakistani](https://propakistani.pk/2025/06/03/bad-news-for-citizens-with-more-than-one-electricity-meter/).
- **Deposits:** courts have held a deposit cannot replace monthly rent unless the agreement allows it [case](https://pakcaselaw.duckdns.org/case/19474/manzoorul-haq-vs-taj-bibi-1983-clc-1934), [case](https://pakcaselaw.duckdns.org/case/101705/siraj-khan-vs-taj-muhammad-2003-ylr-1101). In practice landlords take arrears out of it anyway [Tribune](https://tribune.com.pk/story/2615392/the-rent-trap).
- **Police registration:**
  - **Punjab:** penalty of at least Rs10,000 under the 2015 ordinance [Khalid Zafar](https://khalidzafar.com/laws-of-pakistan/punjab-information-of-temporary-residents-ordinance-2015/). Rawalpindi recorded 431 cases and 644 arrests in early 2026 [APP](https://www.app.com.pk/?p=1182808). Registration is through the online TRS [Punjab Police](https://punjabpolice.gov.pk/trs).
  - **Sindh:** TRUST portal since Dec 2025 [ProPakistani](https://propakistani.pk/2025/12/18/sindh-makes-tenant-registration-easier/); 39 cases and 54 arrests in South Karachi (Apr 2026) [ProPakistani](https://propakistani.pk/2026/04/25/sindh-starts-arresting-tenants-and-landlords-who-fail-to-register/).
  - **Islamabad:** online registration [ICT Police](https://islamabadpolice.gov.pk/tenant.php).
  - **KP:** 28 building owners were arrested in Swabi [Dawn](https://www.dawn.com/news/1155827); registration asks for two references [IRB](https://www.ecoi.net/en/document/1424022.html).
- **Punjab agreement registration:** a written agreement must be filed with the Rent Registrar, stating the rent, rate of increase, due date and payment mode [Punjab Laws](http://punjablaws.gov.pk/laws/498.html). Late filing is fined at 10% of annual rent for the landlord and 5% for the tenant [Nasir Law](http://nasirlawsite.com/laws/rent2009.htm).
- **Tax:**
  - Tax year is July–June; TY2026 returns were extended to 15 Oct 2026 [Arab News](https://www.arabnews.pk/pakistan/pakistan-extends-deadline-for-filing-income-tax-returns-till-oct-15-3002807).
  - Rent withholding (s.155) for individuals: nil up to Rs300k; 5% up to Rs600k; Rs15k + 10% up to Rs2M; Rs155k + 25% above. Companies pay 15% if they file returns, 30% if not [FBR](https://download1.fbr.gov.pk/Docs/20258181281745641WHT-RateCard.pdf).
  - The deemed-income tax on property (s.7E) was struck down [Dawn](https://www.dawn.com/news/1998420).
- **Rising rents:** urban house rent was up 6.1% year on year in Feb 2026 [INP](https://www.inp.net.pk/news-detail/inp-wealthpk/urban-housing-and-utility-costs-rise-1051-year-on-year-in-february). A 5-marla DHA house rents for 29% more than a year ago [Zameen Index](https://www.zameen.com/index/rent/houses/lahore/dha-phase-6-1448/5-marla/).
- **Screening and maintenance:** CNIC checks via NADRA plus police registration are mandatory [Dawn](https://www.dawn.com/news/971917). Upper floors run out of water first [Dawn](https://www.dawn.com/news/1186133).

**Inference**
- v1 pain ranking: rent arrears → utility arrears on landlord-named meters → proof of payment → compliance → increments → overseas visibility.
- Vacancy loss and caretaker misreporting rest on anecdote and legal sources only; validate both in interviews.

## 3. Competitors & analogues
| Product | Offer / price | Gap for Pakistan | Borrow |
|---|---|---|---|
| Esset, Lahore *(vendor)* [site](https://esset-web.pages.dev/pk/hoteleye/) | Leases, documents, billing; HotelEye sync; price unpublished | Hostel-centric, web | HotelEye sync |
| Moneypex Rental *(vendor)* [site](https://moneypex.com/Pk/rental) | EasyPaisa/JazzCash reconciliation, WhatsApp PDF receipts, FBR invoices, yield tracking | Agency ERP | WhatsApp receipts |
| Nooks Partner [iOS](https://apps.apple.com/ph/app/nooks-partner/id1530996324) | House/hostel listing and management; tenant notices and complaints | Marketplace-first | Notice flow |
| KiraayePay [Gust](https://gust.com/companies/kiraayepay-pk) / KirayaX [post](https://pk.linkedin.com/in/awais30) | Still in development / pilot paying landlords on the 1st, tenant repays in instalments | Not live | Rent-guarantee partner |
| Udhaar Book [iOS](https://apps.apple.com/us/app/udhaarbook/id1542333203) | Digital credit ledger; free SMS reminders "recover 4× faster"; raised $6M [FNME](https://fintechnews.ae/10764/pakistan/pakistans-udhaar-book-secures-us6m-for-digital-book-keeping-app/) | Not built for rent | Owed/received UX, one-tap nudges |
| Home Record [listing](https://appgoblin.info/apps/com.homerentrecord) | English/Urdu/Roman Urdu rent tracker | No traction | Trilingual UI |
| RentOk, India [site](https://rentok.com/autopay), [blog](https://wb.rentok.com/market-trends/5-best-rent-collection-apps-for-landlords/) | WhatsApp reminders with payment links, receipts, ledger per tenant, ID checks, e-signing; Autopay ₹30 per tenant per month | Indian rails | Its whole WhatsApp loop |
| NoBroker Pay [blog](https://www.nobroker.in/blog/nobroker-rent-payment) | Tenants pay rent by card for a small fee; automatic receipts; landlord need not sign up | Card rent is rare here | Works without the landlord signing up |
| MyGate / ApnaComplex [site](https://mygate.com/society-billing-software/features/) | Dues by flat or area, outstanding balance with interest; from ₹499/mo | Society-level | Dues ageing |
| Landlord Studio [SA](https://www.softwareadvice.com/property/landlord-studio-profile) / Stessa [review](https://aitoolsbakery.com/blog/stessa-review/) | Free tiers; $12/$28 plans; NOI and cash-flow dashboards | US tax forms | Cash flow per property |
| TenantCloud [Toolradar](https://toolradar.com/tools/tenantcloud/pricing) / RentRedi [pricing](https://www.rentredi.com/pricing/) | $12–60/mo; autopay, smart reminders, receipt capture | Price | Receipt capture |
| Baselane / Buildium / DoorLoop [review](https://aitoolsbakery.com/blog/buildium-vs-doorloop/) | Free banking-led tool to $55–69+/mo property-manager suites | Overkill | Expense categories |

**Inference:** none of these covers cash-first PKR ledgers, police registration, meter-level utility arrears, Urdu, or a caretaker role. Global prices of $12–28/mo are well above local willingness to pay. A freemium model with a low PKR tier fits better.

## 4. Communication norms & devices
**Evidence**
- WhatsApp has ~98M accounts in Pakistan [TechJuice](https://www.techjuice.pk/?p=204191); other estimates range from 52M to 100M.
- From 1 Oct 2026 the Business API costs $0.015 per utility message, against $0.0014 in India. Free in-window messages end [ProPakistani](https://propakistani.pk/2026/09/15/meta-charges-pakistan-11x-more-than-india-for-whatsapp-business-messages/). A wa.me link opens a chat with an editable, pre-filled message [Bird](https://bird.com/explained/whatsapp/what-is-a-whatsapp-click-to-chat-link).
- **Language:**
  - Roman Urdu is the most common texting style [UWA](https://research-repository.uwa.edu.au/en/publications/analyzing-emergent-users-text-messages-data-and-exploring-its-ben/).
  - In 2009, 37% texted in Roman Urdu, 15% in Urdu script and 17% in English; rural users favoured Urdu script [ProPakistani](https://propakistani.pk/2009/12/08/roman-urdu-is-most-used-language-for-sending-sms-survey/).
  - 75% of Codashop's support queries arrive in Urdu, though top apps are not localised [Coda](https://Codapayments.com/market-guide/pakistan).
  - Use the respectful "aap" form, not "tum" [ProZ](https://www.proz.com/doc/5138).
- **Devices:**
  - Android has 90.7% of mobile traffic and iOS 9.2% [StatCounter](https://gs.statcounter.com/os-market-share/mobile/pakistan). Android 13 is ~18% and Android 11 ~15% [StatCounter](https://gs.statcounter.com/android-version-market-share/mobile/pakistan).
  - Transsion (Infinix and Tecno) has 44% of units, and 95% of phones are sold through small shops [Profit](https://profit.pakistantoday.com.pk/2025/10/20/xiaomi-eyes-pakistans-expanding-smartphone-market-as-local-assembly-and-smart-tv-production-gain-pace/).
  - There are 155.9M 3G/4G users [PhoneWorld](https://www.phoneworld.com.pk/pakistans-mobile-subscribers-rise-to-204-7-million-in-february-2026-as-4g-usage-expands/), and data costs ~Rs27/GB [MEA](https://meatechwatch.com/2025/06/16/pakistan-offers-some-of-the-worlds-cheapest-mobile-data-with-prices-dropping-65-since-2018/).

**Inference**
- Make Urdu the default UI (right-to-left) with an English toggle, and give templates in three scripts.
- Performance targets: ≤15 MB download, <3 s cold start on 3–4 GB RAM phones, Android 7+ (API 24), offline sync, photos compressed to ≤200 KB.
- iOS matters mainly for overseas owners.
- Reminder etiquette: open with a Salam, use "aap", say "if already paid, ignore", no threats early, no late-night or Friday-prayer sends.

## 5. Analytics landlords value
**Evidence**
- Stessa shows NOI, net cash flow and P&L per property [BiggerPockets](https://www.biggerpockets.com/reviews/property-management-software/stessa-property-management-review). Moneypex sells yield tracking *(vendor)*; RentOk has ledgers per tenant; MyGate shows dues with interest.
- Economic occupancy = rent collected ÷ maximum possible rent; non-payment counts as credit loss, not vacancy [Rentana](https://www.rentana.io/glossary/what-is-vacancy-loss).
- Gross yields average 6.67% (Karachi 7.14%, Lahore 5.74%, Islamabad 7.16%) [GPG](https://www.globalpropertyguide.com/asia/pakistan/rental-yields).

**Inference:** local landlords care most about "who owes what, since when"; overseas investors care about yield; filers care about tax-year totals.

## (a) Prioritised features
**MVP**
1. **Property → unit model** (portion, annexe, flat, shop, room or bed) with meters per unit. *Matches the §1 segments.*
2. **Tenant profile** with CNIC photos, 2 references, and police-registration status, slip photo and city link. *Arrests are now happening.*
3. **Agreement record:** 11-month term, due day, deposit, increment %, scanned copy. *Mirrors Punjab s.5.*
4. **Auto monthly dues and ledger:** partial payments; method (cash, Raast, bank, wallet, cheque) with a proof photo. *Cash-first.*
5. **Numbered bilingual receipts.** *Proof of payment decides disputes.*
6. **wa.me WhatsApp reminders** on a schedule, in three languages. *The API is expensive.*
7. **Utility tracker per meter:** reference number, whose name is on it, bills, readings at move-in and move-out. *Arrears stay with the premises.*
8. **Dashboard:** due vs collected, overdue list with days late, upcoming renewals. *Late rent is the top complaint.*
9. **Basic expenses** per property. *Needed for yield and July–June tax totals.*
10. **Urdu/English UI**, offline-first, light enough for low-end Android. *~91% Android; Urdu-first users.*

**v1.x**
- **Caretaker role:** each cash entry gets a timestamp and photo; monthly owner statement as PDF; remittance log. *Overseas trust gap.*
- **Move-out photo checklist** and deposit settlement calculator. *Deposit disputes.*
- **Increment and renewal notices** 90 and 30 days ahead. *The 11-month, 10% norm.*
- **July–June tax pack** with export for an accountant. *s.155 slabs and filing deadline.*
- **Maintenance log**, and a **tenant link** to their ledger, receipts and Raast ID. *Tenants also need proof of payment.*
- **Hostel/PG mode** with a HotelEye checklist. *HotelEye is mandatory in Punjab.*
- **200-unit meter alert.** *The tariff cliff.*
- **"Dispute pack" PDF** for Rent Controllers and special courts. *Proof-of-payment rules.*

**Later:**
- Raast/wallet collection with automatic reconciliation. *Cash still dominates.*
- Paid WhatsApp API automation. *$0.015 per message.*
- Market-rent benchmarks from the Zameen Index, which needs a licence.
- Rent-guarantee partners. *The KirayaX pilot.*
- Agency plans. *Managers charge 5–10%.*

## (b) Dashboard insights
**Notation:** for each due: amount *A*, due date *D*. Outstanding *O* = *A* − payments made. Today = *T*.
1. **Collection rate (month m)** = payments against month m's dues ÷ ΣA for month m × 100.
2. **Arrears ageing:** sum *O* by age (*T* − *D*) in buckets of 0–30, 31–60, 61–90 and 90+ days, per tenant and in total.
3. **Payment score (0–100)** = 50 × on-time rate + 30 × (1 − min(average days late, 30)/30) + 20 × (1 − min(*O*_tenant ÷ rent, 3)/3).
   - On-time = paid in full within *D* + 5 days, over the trailing 12 months.
4. **Lost income (unit)** = vacant days × last rent ÷ 30.
5. **Economic occupancy** = collected ÷ (contract rent of occupied units + asking rent of vacant units) × 100.
6. **Yield (trailing 12 months):** gross = rent ÷ value × 100; net = (rent − expenses) ÷ value × 100. The owner enters the value; compare against the city benchmark.
7. **Expense ratio** = expenses by category ÷ rent collected.
8. **Tax-year summary (Jul–Jun):** gross rent *G*, withholding certificates by tenant, expenses. Estimate, labelled as such:
   - *G* ≤ 300k: 0
   - *G* ≤ 600k: 5% × (*G* − 300k)
   - *G* ≤ 2M: 15k + 10% × (*G* − 600k)
   - above 2M: 155k + 25% × (*G* − 2M)
9. **Increment schedule:** next date = last increment + term; new rent = rent × (1 + i). Loss-to-lease = market rent − contract rent.
10. **Deposit cover** = deposit ÷ (rent arrears + unpaid bills on meters in the landlord's name); flag when below 1.
11. **Caretaker cash in hand** = cash collected − amount remitted − approved expenses.
12. **Payment-method mix** = payments by method ÷ total collected; track the cash share.

## (c) WhatsApp reminder templates
The app adds "sahib/sahiba" (صاحب/صاحبہ) after the name by gender. The Urdu verbs are gender-neutral.

**1. Advance reminder (3 days before due)**
- EN: Assalam-o-Alaikum {tenant_name}, I hope you are well. A gentle reminder that the {month} rent for {property}, Rs {amount}, is due on {due_date}. Payment can be made in cash or to Raast ID {raast_id}. JazakAllah.
- UR: السلام علیکم {tenant_name}، امید ہے مزاج بخیر ہوں گے۔ یاد دہانی کے لیے عرض ہے کہ {property} کا {month} کا کرایہ {amount} روپے، {due_date} کو واجب الادا ہے۔ ادائیگی نقد یا راست آئی ڈی {raast_id} پر کی جا سکتی ہے۔ جزاک اللہ۔
- Roman Urdu: Assalam-o-Alaikum {tenant_name}, umeed hai mizaj bakhair honge. {property} ka {month} ka kiraya Rs {amount}, {due_date} ko wajib-ul-ada hai. JazakAllah.

**2. Due today**
- EN: Assalam-o-Alaikum {tenant_name}, today ({due_date}) the {month} rent for {property}, Rs {amount}, is due. Kindly pay at your convenience today and share the receipt or screenshot here. Thank you.
- UR: السلام علیکم {tenant_name}، آج ({due_date}) {property} کا {month} کا کرایہ {amount} روپے واجب الادا ہے۔ براہِ کرم آج اپنی سہولت کے مطابق ادائیگی فرما دیں اور رسید یا اسکرین شاٹ یہاں بھیج دیں۔ شکریہ۔

**3. Gentle overdue follow-up (due date + 5 days)**
- EN: Assalam-o-Alaikum {tenant_name}, I hope all is well. As per our record, the {month} rent for {property}, Rs {amount} (due {due_date}), is still pending. If it has already been paid, please ignore this and send the receipt. If there is any difficulty, kindly let us know so we can find a solution together. Thank you for your cooperation.
- UR: السلام علیکم {tenant_name}، امید ہے سب خیریت ہے۔ ہمارے ریکارڈ کے مطابق {property} کا {month} کا کرایہ {amount} روپے (مقررہ تاریخ {due_date}) ابھی تک موصول نہیں ہوا۔ اگر ادائیگی ہو چکی ہے تو براہِ کرم اس پیغام کو نظرانداز کریں اور رسید بھیج دیں۔ اگر کوئی مشکل درپیش ہو تو ضرور بتائیں تاکہ مل کر کوئی حل نکالا جا سکے۔ تعاون کا شکریہ۔

**4. Payment received (receipt)**
- EN: Assalam-o-Alaikum {tenant_name}, JazakAllah! Rs {amount} received on {paid_date} for the {month} rent of {property}. Receipt no. {receipt_no} is attached. Remaining balance: Rs {balance}.
- UR: السلام علیکم {tenant_name}، جزاک اللہ! {property} کے {month} کے کرایہ کی مد میں {amount} روپے {paid_date} کو موصول ہو گئے ہیں۔ رسید نمبر {receipt_no} منسلک ہے۔ بقایا رقم: {balance} روپے۔

**5. Utility bill (meter in the owner's name)**
- EN: Assalam-o-Alaikum {tenant_name}, a reminder that the {utility} bill for {property} for {month}, Rs {amount}, is due on {due_date}. As the meter is registered in the owner's name, kindly pay before the due date and send a photo of the paid bill. Thank you.
- UR: السلام علیکم {tenant_name}، یاد دہانی ہے کہ {property} کا {month} کا {utility} کا بل {amount} روپے {due_date} تک واجب الادا ہے۔ چونکہ میٹر مالک مکان کے نام پر ہے، اس لیے براہِ کرم مقررہ تاریخ سے پہلے ادائیگی کر کے ادا شدہ بل کی تصویر بھیج دیں۔ شکریہ۔
