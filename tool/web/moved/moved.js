// Runs on an earlier address of the web app, in the page that address answers instead of the
// app (moved.html; docs/operations.md, Domains). A browser keeps what a web app stores apart
// for each address, so after a move the earlier address still holds the session, the lists the
// app loaded (CNICs among them), the settings and an invitation not yet answered, where no app
// runs any more to remove them. This removes them and goes to the same page on the app's
// origin, which the page names in <meta name="mm-moved-to">.
//
// The response that carries the page also says Clear-Site-Data: "storage", which clears more
// (IndexedDB, service workers) in the browsers that know the header; this script is for the
// ones that do not, and for a page a browser took from its cache. It is plain ES5 with no
// inline code and no HTML or script sink, so the app's Content-Security-Policy and Trusted
// Types allow it as they are.
(function () {
  'use strict';

  // What the app keeps in localStorage (docs/architecture/app.md): its own keys (mm.*),
  // Supabase's session (sb-<project>-auth-token) and gotrue's sign-in-link verifier, which
  // shared_preferences' older interface writes under flutter.*.
  var OWN_KEYS = /^(?:mm\.|flutter\.|sb-.+-auth-token)/;
  // The paths that mean the app's first page: the root, the app's shell and this page itself.
  var FIRST_PAGE = /^\/(?:index\.html|moved\.html)?$/;

  var meta = document.querySelector('meta[name="mm-moved-to"]');
  var origin = meta ? meta.getAttribute('content') : null;
  // Without a destination there is nothing to do. On the destination itself (the page's file is
  // served there too) nothing is removed and nothing navigates, so this can never loop.
  if (!origin || !/^https:\/\/[a-z0-9.-]+$/.test(origin) || window.location.origin === origin) {
    return;
  }

  try {
    var storage = window.localStorage;
    var keys = [];
    var index;
    for (index = 0; index < storage.length; index += 1) {
      keys.push(storage.key(index));
    }
    for (index = 0; index < keys.length; index += 1) {
      if (OWN_KEYS.test(keys[index])) {
        storage.removeItem(keys[index]);
      }
    }
  } catch (error) {
    // The browser blocks storage here, so the app kept nothing in it.
  }

  var path = window.location.pathname;
  var address =
    origin + (FIRST_PAGE.test(path) ? '/' : path) + window.location.search + window.location.hash;
  // The links too, for a person who follows one before the browser has left the page.
  document.addEventListener('DOMContentLoaded', function () {
    var links = document.querySelectorAll('a[data-moved]');
    for (var link = 0; link < links.length; link += 1) {
      links[link].setAttribute('href', address);
    }
  });
  window.location.replace(address);
})();
