/**
 * Brings a calculator to life in the browser: reads the form, shows errors
 * beside the fields, and replaces the result with a new one, announcing its
 * summary through the page's live region (role="status").
 *
 * The page is rendered with a worked result for the default inputs, so it
 * reads fully without JavaScript; this script only recalculates. The DOM is
 * built with createElement and textContent, never innerHTML: the site's
 * Content-Security-Policy enforces Trusted Types.
 */
import { isLocale, type Locale } from "../i18n/locales.ts";
import { CHROME, calculatorIds } from "../tools/chrome.ts";
import type { Calculator, ResultView, Segment } from "../tools/types.ts";

function element<K extends keyof HTMLElementTagNameMap>(
  tag: K,
  className?: string,
  text?: string,
): HTMLElementTagNameMap[K] {
  const node = document.createElement(tag);
  if (className !== undefined) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function segments(parent: HTMLElement, parts: readonly Segment[]): void {
  for (const part of parts) {
    if (typeof part === "string") {
      parent.append(part);
    } else {
      const math = element("bdi", "math", part.math);
      math.dir = "ltr";
      parent.append(math);
    }
  }
}

/** The result's body, exactly as src/components/tools/ResultBody.astro renders it. */
export function renderResultBody(id: string, view: ResultView, locale: Locale): HTMLElement[] {
  const ids = calculatorIds(id);
  const nodes: HTMLElement[] = [];
  const figures = element("dl", "result__figures");
  for (const item of view.figures) {
    const row = element(
      "div",
      item.primary === true ? "result__figure result__figure--primary" : "result__figure",
    );
    row.append(element("dt", undefined, item.label), element("dd", "amount", item.value));
    figures.append(row);
  }
  nodes.push(figures);
  nodes.push(element("h3", "result__steps-heading", CHROME[locale].stepsHeading));
  const steps = element("ol", "result__steps");
  for (const step of view.steps) {
    const item = element("li");
    segments(item, step);
    steps.append(item);
  }
  nodes.push(steps);
  if (view.table !== undefined) {
    const wrap = element("div", "table-scroll");
    wrap.setAttribute("role", "region");
    wrap.setAttribute("aria-labelledby", ids.tableCaption);
    wrap.tabIndex = 0;
    const table = element("table", "data-table");
    const caption = element("caption", undefined, view.table.caption);
    caption.id = ids.tableCaption;
    const head = element("thead");
    const headRow = element("tr");
    for (const cell of view.table.head) {
      const th = element("th", undefined, cell);
      th.scope = "col";
      headRow.append(th);
    }
    head.append(headRow);
    const body = element("tbody");
    for (const row of view.table.rows) {
      const tr = element("tr");
      row.forEach((cell, index) => {
        if (index === 0) {
          const th = element("th", undefined, cell);
          th.scope = "row";
          tr.append(th);
        } else {
          tr.append(element("td", "amount", cell));
        }
      });
      body.append(tr);
    }
    table.append(caption, head, body);
    wrap.append(table);
    nodes.push(wrap);
  }
  const notes = element("ul", "result__notes");
  for (const note of view.notes) notes.append(element("li", undefined, note));
  nodes.push(notes);
  return nodes;
}

function fieldValues(form: HTMLFormElement): Record<string, string> {
  const values: Record<string, string> = {};
  for (const [name, value] of new FormData(form)) {
    if (typeof value === "string") values[name] = value;
  }
  return values;
}

/** The inputs an error belongs to: a field, or every field of a group. */
function controlsOf(form: HTMLFormElement, id: string, name: string): HTMLElement[] {
  const ids = calculatorIds(id);
  const own = document.getElementById(ids.field(name));
  if (own instanceof HTMLInputElement || own instanceof HTMLSelectElement) return [own];
  const group = form.querySelector<HTMLFieldSetElement>(`fieldset[data-group="${name}"]`);
  return group === null ? [] : [...group.querySelectorAll<HTMLElement>("input, select")];
}

function setDescribedBy(control: HTMLElement, errorId: string, on: boolean): void {
  const ids = (control.getAttribute("aria-describedby") ?? "")
    .split(/\s+/)
    .filter((value) => value !== "" && value !== errorId);
  if (on) ids.unshift(errorId);
  if (ids.length === 0) control.removeAttribute("aria-describedby");
  else control.setAttribute("aria-describedby", ids.join(" "));
}

/** Wires up the calculator whose form is on this page. */
export function mountCalculator<T>(calculator: Calculator<T>): void {
  const ids = calculatorIds(calculator.id);
  const form = document.getElementById(ids.form);
  const status = document.getElementById(ids.status);
  const body = document.getElementById(ids.body);
  if (!(form instanceof HTMLFormElement) || status === null || body === null) return;
  const lang = document.documentElement.lang;
  const locale: Locale = isLocale(lang) ? lang : lang.startsWith("ur") ? "ur" : "en";
  const errorNames = [...form.querySelectorAll<HTMLElement>("[data-error-for]")].map(
    (node) => node.dataset.errorFor ?? "",
  );

  const announce = (text: string) => {
    // Clear first, so the same sentence twice is announced twice.
    status.textContent = "";
    window.setTimeout(() => {
      status.textContent = text;
    }, 100);
  };

  form.addEventListener("submit", (event) => {
    event.preventDefault();
    for (const name of errorNames) {
      const error = document.getElementById(ids.error(name));
      if (error !== null) {
        error.textContent = "";
        error.hidden = true;
      }
      for (const control of controlsOf(form, calculator.id, name)) {
        control.removeAttribute("aria-invalid");
        setDescribedBy(control, ids.error(name), false);
      }
    }
    const parsed = calculator.parse(fieldValues(form), locale);
    if (!parsed.ok) {
      let first: HTMLElement | undefined;
      for (const [name, message] of Object.entries(parsed.errors)) {
        const error = document.getElementById(ids.error(name));
        if (error !== null) {
          error.textContent = message;
          error.hidden = false;
        }
        for (const control of controlsOf(form, calculator.id, name)) {
          control.setAttribute("aria-invalid", "true");
          setDescribedBy(control, ids.error(name), true);
          first ??= control;
        }
      }
      first?.focus();
      announce(CHROME[locale].errorSummary);
      return;
    }
    const view = calculator.view(parsed.value, locale);
    body.replaceChildren(...renderResultBody(calculator.id, view, locale));
    announce(view.summary);
  });
  // Marks the form as live, for tests and for styles that depend on the script.
  form.dataset.ready = "true";
}
