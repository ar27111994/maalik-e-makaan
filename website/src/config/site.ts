/** Facts about the product that every page shares. */
export const SITE = {
  name: "Maalik-e-Makaan",
  nameUrdu: "مالکِ مکان",
  repositoryUrl: "https://github.com/ar27111994/maalik-e-makaan",
  licenceUrl: "https://github.com/ar27111994/maalik-e-makaan/blob/main/LICENSE",
  copyrightYear: 2026,
  copyrightHolder: "Ahmed Rehan",
  copyrightHolderUrdu: "احمد ریحان",
  /**
   * Where the product stands. While it is "in-development" every page says so
   * plainly; set it to "available" when version 1.0 ships.
   */
  appStatus: "in-development" as "in-development" | "available",
} as const;
