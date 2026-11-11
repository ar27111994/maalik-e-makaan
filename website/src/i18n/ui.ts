import type { Locale } from "./locales.ts";

/**
 * The words around the content: navigation, the language switch, the footer
 * and the shared notices. Page copy lives in src/content/. The interface makes
 * every key required in both languages, so a string can never be missing in
 * Urdu.
 *
 * English is British English. Urdu is written in Urdu script only: no Roman
 * Urdu. A Latin-script word on an Urdu page must sit in an element with
 * lang="en"; the e2e suite fails the build otherwise.
 */
export interface UiStrings {
  readonly skipLink: string;
  readonly navLabel: string;
  readonly footerNavLabel: string;
  readonly nav: {
    readonly features: string;
    readonly pricing: string;
    readonly howItWorks: string;
    readonly guides: string;
    readonly tools: string;
    readonly faq: string;
  };
  /** Read by screen readers after the site name in the header link. */
  readonly homeHint: string;
  /** Read by screen readers after the other language's name in the language switch. */
  readonly switchLanguageHint: string;
  readonly breadcrumbLabel: string;
  readonly breadcrumbHome: string;
  readonly ogImageAlt: string;
  readonly appStatus: { readonly inDevelopment: string };
  readonly footer: {
    readonly tagline: string;
    readonly privacy: string;
    readonly disclaimer: string;
    readonly sourceCode: string;
    readonly licences: string;
    readonly download: string;
    readonly privacyPage: string;
    readonly terms: string;
    readonly faq: string;
    readonly llmsTxt: string;
    readonly pricing: string;
    readonly roadmap: string;
    readonly releases: string;
    readonly company: string;
    readonly linkedIn: string;
    /** The current release: "{version}" and "{date}" are filled in from CHANGELOG.md. */
    readonly version: string;
    readonly releaseNotes: string;
    readonly licence: string;
  };
  readonly notFound: {
    readonly title: string;
    readonly description: string;
    readonly heading: string;
    readonly body: string;
    readonly homeLink: string;
    /** A short note in the other language, for a reader who cannot read this one. */
    readonly otherLanguageHeading: string;
    readonly otherLanguageBody: string;
    readonly otherLanguageLink: string;
  };
  readonly guide: {
    readonly lastReviewed: string;
    readonly notAdvice: string;
    readonly sources: string;
    readonly accessed: string;
    /** Beside a source served only over plain HTTP. */
    readonly insecure: string;
  };
  /** The guides index (/guides/). */
  readonly guides: SectionStrings & { readonly readGuide: string };
  /** The calculators index (/tools/) and the calculator pages. */
  readonly tools: SectionStrings & {
    readonly useTool: string;
    readonly notAdvice: string;
    readonly examplesCaption: string;
  };
  /** Pages of running text (privacy, terms). */
  readonly textPage: { readonly lastUpdated: string };
  /** The roadmap page (/roadmap/), built from the roadmap's GitHub milestones and issues. */
  readonly roadmap: SectionStrings & {
    /** "{date}" is filled in. */
    readonly due: string;
    /** "{done}" and "{total}" are filled in. */
    readonly progress: string;
    readonly done: string;
    readonly open: string;
    readonly milestoneDone: string;
    /** The group of roadmap issues that are in no stage yet. */
    readonly unscheduled: string;
    /** "{date}" is filled in: the day the live data was read. */
    readonly live: string;
    readonly plan: string;
    /** Shown on the Urdu page when some titles are only in English. */
    readonly englishOnly: string;
    readonly github: string;
    readonly suggest: string;
  };
  /** The release notes page (/releases/), built from CHANGELOG.md. */
  readonly releases: SectionStrings & {
    /** "{version}" is filled in. */
    readonly version: string;
    /** "{date}" is filled in. */
    readonly released: string;
    readonly latest: string;
    /** Shown on the Urdu page, whose notes are in English. */
    readonly notesLanguage: string;
    readonly github: string;
    readonly download: string;
    /**
     * Every section title release-please writes, in this language: the visible
     * sections of release-please-config.json, and "⚠ BREAKING CHANGES", which it
     * adds for a `feat!:` commit or a `BREAKING CHANGE:` footer. The heading
     * replaces the title whole, so its "⚠", which the site's fonts do not draw,
     * never reaches the page (tests/unit/release.test.ts checks every title).
     */
    readonly sections: Readonly<Record<string, string>>;
  };
  /** Words for where a feature or platform stands. */
  readonly status: { readonly available: string };
}

/** The title, description, heading and introduction of a section's index page. */
export interface SectionStrings {
  readonly title: string;
  readonly description: string;
  readonly heading: string;
  readonly intro: string;
}

export const UI: Readonly<Record<Locale, UiStrings>> = {
  en: {
    skipLink: "Skip to main content",
    navLabel: "Main",
    footerNavLabel: "Footer",
    nav: {
      features: "Features",
      pricing: "Pricing",
      howItWorks: "How it works",
      guides: "Guides",
      tools: "Calculators",
      faq: "Questions",
    },
    homeHint: "(home page)",
    switchLanguageHint: "(read this page in Urdu)",
    breadcrumbLabel: "Breadcrumb",
    breadcrumbHome: "Home",
    ogImageAlt: "Maalik-e-Makaan: rent, receipts and records for Pakistani landlords",
    appStatus: { inDevelopment: "In development: version 1.0 has not been released yet." },
    footer: {
      tagline: "Rent, receipts and records for Pakistani landlords.",
      privacy: "This site sets no cookies and uses no analytics or trackers.",
      disclaimer: "Guides on this site are general information, not legal or tax advice.",
      sourceCode: "Source code on GitHub",
      licences: "Licences",
      download: "Get the app",
      privacyPage: "Privacy",
      terms: "Terms of use",
      faq: "Questions and answers",
      llmsTxt: "Plain-text summary for AI tools",
      pricing: "Pricing",
      roadmap: "Roadmap",
      releases: "Release notes",
      company: "Company",
      linkedIn: "AR Labs on LinkedIn",
      version: "Version {version}, released {date}.",
      releaseNotes: "What’s new",
      licence: "Released under the MIT licence.",
    },
    notFound: {
      title: "Page not found",
      description: "The page you asked for does not exist or has moved.",
      heading: "Page not found",
      body: "The page you asked for does not exist or has moved. Check the address, or start again from the home page.",
      homeLink: "Go to the home page",
      otherLanguageHeading: "صفحہ نہیں ملا",
      otherLanguageBody: "آپ جو صفحہ تلاش کر رہے ہیں وہ موجود نہیں یا کہیں اور منتقل ہو چکا ہے۔",
      otherLanguageLink: "اردو سرورق پر جائیں",
    },
    guide: {
      lastReviewed: "Last reviewed",
      notAdvice:
        "This guide is general information, not legal or tax advice. Check the official sources, or ask a lawyer or tax adviser about your situation.",
      sources: "Official sources",
      accessed: "accessed",
      insecure:
        "this site uses plain HTTP, which is not encrypted; we could not confirm a secure (HTTPS) address for it",
    },
    roadmap: {
      title: "Roadmap",
      description:
        "What is planned for Maalik-e-Makaan, stage by stage: store listings, an assistant that drafts while you confirm, tenant links and rent collection.",
      heading: "Roadmap",
      intro:
        "What we are working on next, in stages. Each item is an issue on GitHub, where you can follow it, comment or suggest something new. Dates are targets, not promises.",
      due: "Target: {date}",
      progress: "{done} of {total} done",
      done: "Done",
      open: "Planned",
      milestoneDone: "Complete",
      unscheduled: "Not yet in a stage",
      live: "Live from GitHub, as of {date}.",
      plan: "This is the plan as written in the project; GitHub has the latest state of each item.",
      englishOnly: "Items added on GitHub appear in English.",
      github: "Follow the roadmap on GitHub",
      suggest: "Suggest something",
    },
    releases: {
      title: "Release notes",
      description:
        "What changed in each version of the Maalik-e-Makaan app and website, newest first, with the date of each release and links to its files.",
      heading: "Release notes",
      intro:
        "Every version of the app, newest first. Each one lists what it added and what it fixed; the files for each version are on its GitHub page.",
      version: "Version {version}",
      released: "Released on {date}",
      latest: "Latest",
      notesLanguage: "The notes are written in English.",
      github: "Files and details on GitHub",
      download: "Get the latest version",
      sections: {
        "⚠ BREAKING CHANGES": "Changes that may affect you",
        Features: "New",
        "Bug fixes": "Fixed",
        Performance: "Faster",
        Reverts: "Undone",
        Documentation: "Documentation",
      },
    },
    guides: {
      title: "Guides for landlords in Pakistan",
      description:
        "Plain guides to police registration of tenants, rent agreements, tax on rental income and utilities in your name, each dated and citing official sources.",
      heading: "Guides",
      intro:
        "What the law in Pakistan asks of landlords, in plain English. Each guide shows when it was last reviewed and cites the official sources next to each claim. Where sources disagree or are unclear, the guide says so. They are general information, not legal or tax advice.",
      readGuide: "Read the guide",
    },
    tools: {
      title: "Rent and tax calculators",
      description:
        "Free calculators for Pakistani landlords: the yearly rent increase, the first month's rent and section 155 withholding tax, each showing its working.",
      heading: "Calculators",
      intro:
        "Each calculator shows how it reached its figure, step by step, and works inside your browser: nothing you type is sent anywhere. They accept English or Urdu digits.",
      useTool: "Open the calculator",
      notAdvice:
        "This calculator gives general information, not legal or tax advice. Check the sources below, or ask a lawyer or tax adviser about your situation.",
      examplesCaption: "Worked examples",
    },
    textPage: { lastUpdated: "Last updated" },
    status: { available: "Available" },
  },
  ur: {
    skipLink: "مرکزی مواد پر جائیں",
    navLabel: "مرکزی روابط",
    footerNavLabel: "ذیلی روابط",
    nav: {
      features: "خصوصیات",
      pricing: "قیمتیں",
      howItWorks: "طریقۂ کار",
      guides: "رہنمائی",
      tools: "کیلکولیٹر",
      faq: "سوالات",
    },
    homeHint: "(سرورق)",
    switchLanguageHint: "(یہ صفحہ انگریزی میں پڑھیں)",
    breadcrumbLabel: "آپ یہاں ہیں",
    breadcrumbHome: "سرورق",
    ogImageAlt: "مالکِ مکان: پاکستانی مالکانِ مکان کے لیے کرایہ، رسیدیں اور ریکارڈ",
    appStatus: { inDevelopment: "زیرِ تیاری: ورژن 1.0 ابھی جاری نہیں ہوا۔" },
    footer: {
      tagline: "پاکستانی مالکانِ مکان کے لیے کرایہ، رسیدیں اور ریکارڈ۔",
      privacy: "یہ سائٹ نہ کوئی کوکی استعمال کرتی ہے اور نہ ہی کوئی تجزیاتی یا ٹریکنگ ٹول۔",
      disclaimer: "اس سائٹ پر دی گئی رہنمائی عمومی معلومات ہے، قانونی یا ٹیکس مشورہ نہیں۔",
      sourceCode: "سورس کوڈ گٹ ہب پر",
      licences: "لائسنس",
      download: "ایپ حاصل کریں",
      privacyPage: "رازداری",
      terms: "شرائطِ استعمال",
      faq: "سوالات اور جوابات",
      llmsTxt: "مصنوعی ذہانت کے ٹولز کے لیے سادہ متن میں خلاصہ",
      pricing: "قیمتیں",
      roadmap: "آئندہ منصوبہ",
      releases: "ہر ورژن کی تبدیلیاں",
      company: "کمپنی",
      linkedIn: "لنکڈ اِن پر اے آر لیبز",
      version: "ورژن {version}، {date} کو جاری ہوا۔",
      releaseNotes: "نیا کیا ہے",
      licence: "ایم آئی ٹی لائسنس کے تحت جاری۔",
    },
    notFound: {
      title: "صفحہ نہیں ملا",
      description: "آپ جو صفحہ تلاش کر رہے ہیں وہ موجود نہیں یا کہیں اور منتقل ہو چکا ہے۔",
      heading: "صفحہ نہیں ملا",
      body: "آپ جو صفحہ تلاش کر رہے ہیں وہ موجود نہیں یا کہیں اور منتقل ہو چکا ہے۔ پتا دوبارہ دیکھ لیں، یا سرورق سے نئے سرے سے شروع کریں۔",
      homeLink: "سرورق پر جائیں",
      otherLanguageHeading: "Page not found",
      otherLanguageBody: "The page you asked for does not exist or has moved.",
      otherLanguageLink: "Go to the English home page",
    },
    guide: {
      lastReviewed: "آخری نظرِ ثانی",
      notAdvice:
        "یہ رہنمائی عمومی معلومات ہے، قانونی یا ٹیکس مشورہ نہیں۔ سرکاری ذرائع ضرور دیکھیں، یا اپنی صورتِ حال کے بارے میں کسی وکیل یا ٹیکس مشیر سے رجوع کریں۔",
      sources: "سرکاری ذرائع",
      accessed: "رسائی کی تاریخ",
      insecure:
        "یہ سائٹ سادہ ایچ ٹی ٹی پی استعمال کرتی ہے جو خفیہ کاری کے بغیر ہے؛ ہم اس کے محفوظ (ایچ ٹی ٹی پی ایس) پتے کی تصدیق نہیں کر سکے",
    },
    roadmap: {
      title: "آئندہ منصوبہ",
      description:
        "مالکِ مکان کے لیے آگے کیا منصوبہ ہے، مرحلہ وار: ایپ اسٹورز، ایک معاون جو مسودہ بنائے اور آپ تصدیق کریں، کرایہ داروں کے لنک اور کرایے کی وصولی۔",
      heading: "آئندہ منصوبہ",
      intro:
        "ہم آگے کس پر کام کر رہے ہیں، مرحلہ وار۔ ہر کام گٹ ہب پر ایک مسئلے کے طور پر درج ہے، جہاں آپ اس کی پیش رفت دیکھ سکتے ہیں، رائے دے سکتے ہیں یا کوئی نئی تجویز دے سکتے ہیں۔ تاریخیں ہدف ہیں، وعدے نہیں۔",
      due: "ہدف: {date}",
      progress: "{total} میں سے {done} مکمل",
      done: "مکمل",
      open: "منصوبے میں",
      milestoneDone: "مرحلہ مکمل",
      unscheduled: "ابھی کسی مرحلے میں نہیں",
      live: "گٹ ہب سے براہِ راست، {date} تک کی صورتِ حال۔",
      plan: "یہ منصوبہ پروجیکٹ میں لکھا ہوا ہے؛ ہر کام کی تازہ صورتِ حال گٹ ہب پر ہے۔",
      englishOnly: "گٹ ہب پر شامل کیے گئے کام انگریزی میں دکھائے جاتے ہیں۔",
      github: "گٹ ہب پر منصوبہ دیکھیں",
      suggest: "کوئی تجویز دیں",
    },
    releases: {
      title: "ہر ورژن کی تبدیلیاں",
      description:
        "مالکِ مکان ایپ اور ویب سائٹ کے ہر ورژن میں کیا بدلا، تازہ ترین پہلے، ہر اجرا کی تاریخ اور اس کی فائلوں کے روابط کے ساتھ۔",
      heading: "ہر ورژن کی تبدیلیاں",
      intro:
        "ایپ کا ہر ورژن، تازہ ترین پہلے۔ ہر ایک میں درج ہے کہ اس میں کیا نیا آیا اور کیا درست ہوا؛ ہر ورژن کی فائلیں اس کے گٹ ہب صفحے پر ہیں۔",
      version: "ورژن {version}",
      released: "{date} کو جاری ہوا",
      latest: "تازہ ترین",
      notesLanguage: "تبدیلیوں کی تفصیل انگریزی میں لکھی گئی ہے۔",
      github: "فائلیں اور تفصیل گٹ ہب پر",
      download: "تازہ ترین ورژن حاصل کریں",
      sections: {
        "⚠ BREAKING CHANGES": "ایسی تبدیلیاں جن کا آپ پر اثر پڑ سکتا ہے",
        Features: "نیا",
        "Bug fixes": "درستیاں",
        Performance: "رفتار میں بہتری",
        Reverts: "واپس لی گئی تبدیلیاں",
        Documentation: "دستاویزات",
      },
    },
    guides: {
      title: "پاکستانی مالکانِ مکان کے لیے رہنمائی",
      description:
        "کرایہ داروں کی پولیس رجسٹریشن، کرایہ نامے، کرایے کی آمدنی پر ٹیکس اور آپ کے نام کے بجلی گیس کنکشن پر آسان رہنمائی، ہر ایک تاریخ اور سرکاری حوالوں کے ساتھ۔",
      heading: "رہنمائی",
      intro:
        "پاکستان کا قانون مالکانِ مکان سے کیا تقاضا کرتا ہے، آسان اردو میں۔ ہر رہنمائی پر آخری نظرِ ثانی کی تاریخ درج ہے اور ہر بات کے ساتھ سرکاری ذریعے کا حوالہ ہے۔ جہاں ذرائع میں اختلاف ہو یا بات واضح نہ ہو، وہاں رہنمائی یہی بتاتی ہے۔ یہ عمومی معلومات ہے، قانونی یا ٹیکس مشورہ نہیں۔",
      readGuide: "رہنمائی پڑھیں",
    },
    tools: {
      title: "کرایے اور ٹیکس کے کیلکولیٹر",
      description:
        "پاکستانی مالکانِ مکان کے لیے مفت کیلکولیٹر: کرایے میں سالانہ اضافہ، پہلے مہینے کا کرایہ اور دفعہ 155 کے تحت ٹیکس کٹوتی، ہر ایک اپنا حساب دکھاتا ہے۔",
      heading: "کیلکولیٹر",
      intro:
        "ہر کیلکولیٹر قدم بہ قدم دکھاتا ہے کہ عدد کیسے نکلا، اور آپ کے براؤزر کے اندر ہی کام کرتا ہے: آپ جو لکھتے ہیں وہ کہیں نہیں بھیجا جاتا۔ اردو اور انگریزی دونوں ہندسے قبول ہیں۔",
      useTool: "کیلکولیٹر کھولیں",
      notAdvice:
        "یہ کیلکولیٹر عمومی معلومات دیتا ہے، قانونی یا ٹیکس مشورہ نہیں۔ نیچے دیے گئے ذرائع دیکھیں، یا اپنی صورتِ حال کے بارے میں کسی وکیل یا ٹیکس مشیر سے رجوع کریں۔",
      examplesCaption: "حل شدہ مثالیں",
    },
    textPage: { lastUpdated: "آخری تبدیلی" },
    status: { available: "دستیاب" },
  },
};

export function ui(locale: Locale): UiStrings {
  return UI[locale];
}

export { formatDate } from "./dates.ts";
