"""Static soundness checks of the Bend proofs.

usage: check_soundness.py <dir with SPEC.bend, LAWS.bend, PROOF.bend> <PROOF.bendtt>

PROOF.bendtt is `bend PROOF.bend -o PROOF.bendtt`: the BendTT program that
`--verdict` hands to the kernel. The checks:

1. No source file uses @unsafe, a partial def (`def f?`), a foreign import,
   a `?hole` or `?TODO`.
2. PROOF.bend has exactly one `def Laws.<name>` per law of LAWS.bend, and
   no other `Laws.` def; it defines nothing under the `Spec.` alias.
3. The kernel program states every law exactly as LAWS.bend does: each law
   statement is translated to BendTT's notation and compared, text for
   text, with the type of `LAWS.<name>` in PROOF.bendtt. So no proof proves
   a weaker statement than the one written down, and no law is missing or
   extra. The comparison ignores only BendTT's usage marks (+, -) and the
   erased quantity arguments (&2 / -.Q2), which do not change a statement.
"""

import re
import sys
from pathlib import Path

TOKEN = re.compile(r"\s*(&2|==|\d+n|[A-Za-z_][A-Za-z0-9_.]*|[{}()<>,:&])")


def tokenize(text):
    pos, out = 0, []
    text = text.strip()
    while pos < len(text):
        match = TOKEN.match(text, pos)
        if not match:
            raise SystemExit(f"cannot read {text[pos:pos + 30]!r}")
        out.append(match.group(1))
        pos = match.end()
    return out


class Parser:
    """Reads the expression subset LAWS.bend uses and writes it as BendTT."""

    def __init__(self, tokens, names):
        self.tokens, self.pos, self.names = tokens, 0, names

    def peek(self):
        return self.tokens[self.pos] if self.pos < len(self.tokens) else None

    def take(self, expected=None):
        token = self.peek()
        if token is None or (expected is not None and token != expected):
            raise SystemExit(f"expected {expected!r}, found {token!r} in {' '.join(self.tokens)}")
        self.pos += 1
        return token

    def args(self, close):
        items = []
        while self.peek() != close:
            if self.peek() == "&2":
                self.take()
            else:
                items.append(self.expr())
            if self.peek() == ",":
                self.take()
        self.take(close)
        return items

    def expr(self):
        left = self.atom()
        if self.peek() == "&":  # a pair type A & B
            self.take()
            return f"({left} & {self.expr()})"
        return left

    def atom(self):
        item = self.take()
        if item == "{":
            lhs = self.expr()
            self.take("==")
            rhs = self.expr()
            self.take(":")
            kind = self.expr()
            self.take("}")
            return f"{{{lhs} == {rhs} : {kind}}}"
        if item == "(":
            first = self.expr()
            self.take(",")
            second = self.expr()
            self.take(")")
            return f"({first}, {second})"
        if re.fullmatch(r"\d+n", item):
            return "N" + item[:-1]
        name = item
        if self.peek() == "(":
            self.take()
            parts = [rename(name), *self.args(")")]
            return "(" + " ".join(parts) + ")"
        if self.peek() == "<":
            self.take()
            parts = [name, *self.args(">")]
            return "(" + " ".join(parts) + ")"
        if self.peek() == "{":
            self.take()
            fields = self.args("}")
            inner = "()"
            for field in reversed(fields):
                inner = f"({field}, {inner})"
            return f"(.{name}, {inner})"
        return self.names.get(name, name)


def rename(name):
    if name.startswith("Spec."):
        return "SPEC." + name[len("Spec.") :]
    if name.startswith("Laws."):
        return "LAWS." + name[len("Laws.") :]
    return name


def read_laws(text):
    laws = {}
    lines = text.split("\n")
    i = 0
    while i < len(lines):
        match = re.match(r"law ([A-Za-z0-9_]+):\s*$", lines[i])
        if not match:
            i += 1
            continue
        name = match.group(1)
        i += 1
        body = []
        while i < len(lines) and lines[i].startswith("  "):
            body.append(lines[i].strip())
            i += 1
        laws[name] = body
    return laws


def law_to_bendtt(body):
    names, binders = {}, []
    statement = []
    for line in body:
        match = re.match(r"for\s+[+-]?([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.*)$", line)
        if match:
            var, kind = match.groups()
            index = len(binders)
            binders.append(f"∀x{index} : {Parser(tokenize(kind), dict(names)).expr()} -> ")
            names[var] = f"x{index}"
        else:
            statement.append(line)
    parser = Parser(tokenize(" ".join(statement)), names)
    goal = parser.expr()
    if parser.peek() is not None:
        raise SystemExit(f"unread tokens after the statement: {parser.tokens[parser.pos:]}")
    return "".join(binders) + goal


def decode_nat(text):
    text = text.replace("(.Zero, ())", "N0")
    succ = re.compile(r"\(\.Succ, \(N(\d+), \(\)\)\)")
    while True:
        new = succ.sub(lambda m: f"N{int(m.group(1)) + 1}", text)
        if new == text:
            return text
        text = new


def canonical(text):
    text = re.sub(r"\s*-\.Q2", "", text)
    text = re.sub(r"(?<![\w>])[+-](?=[\w(.{N])", "", text)
    return re.sub(r"\s+", " ", text).strip()


def strip_comments(text):
    return "\n".join(line.split("#", 1)[0] for line in text.split("\n"))


def main():
    root, bendtt = Path(sys.argv[1]), Path(sys.argv[2])
    problems = []
    sources = {name: (root / name).read_text() for name in ("SPEC.bend", "LAWS.bend", "PROOF.bend")}

    # 1. no escape hatches
    for name, text in sources.items():
        code = strip_comments(text)
        for pattern, what in (
            (r"@unsafe", "@unsafe"),
            (r"^def [A-Za-z0-9_.]+\?", "a partial def"),
            (r"\?[A-Za-z_]", "a hole"),
            (r"import \"", "a foreign import"),
        ):
            for line_no, line in enumerate(code.split("\n"), 1):
                if re.search(pattern, line):
                    problems.append(f"{name}:{line_no}: {what}: {line.strip()}")

    # 2. one proof per law, nothing else under Laws. or Spec.
    laws = read_laws(strip_comments(sources["LAWS.bend"]))
    proof_code = strip_comments(sources["PROOF.bend"])
    proofs = re.findall(r"^def Laws\.([A-Za-z0-9_]+)\(", proof_code, re.M)
    for law in laws:
        if proofs.count(law) != 1:
            problems.append(f"law {law} has {proofs.count(law)} proofs in PROOF.bend")
    for proof in proofs:
        if proof not in laws:
            problems.append(f"PROOF.bend proves Laws.{proof}, which is not a law")
    if re.search(r"^def Spec\.", proof_code, re.M):
        problems.append("PROOF.bend defines something under Spec.")

    # 3. the kernel's statements are the written ones
    kernel = {}
    for match in re.finditer(r"^LAWS\.([A-Za-z0-9_]+) : (.*) =\n(.*)\n", bendtt.read_text(), re.M):
        kernel[match.group(1)] = (decode_nat(match.group(2)), match.group(3).strip())
    for law, body in laws.items():
        if law not in kernel:
            problems.append(f"law {law} is not in the kernel program")
            continue
        written = canonical(law_to_bendtt(body))
        checked = canonical(kernel[law][0])
        if written != checked:
            problems.append(f"law {law}: written\n    {written}\n  kernel\n    {checked}")
        if not kernel[law][1]:
            problems.append(f"law {law} has no body in the kernel program")
    for law in kernel:
        if law not in laws:
            problems.append(f"the kernel program has LAWS.{law}, which LAWS.bend does not state")

    print(f"laws in LAWS.bend: {len(laws)}")
    print(f"proofs in PROOF.bend: {len(proofs)}")
    print(f"laws in the kernel program: {len(kernel)}")
    if problems:
        print("SOUNDNESS PROBLEMS:")
        for problem in problems:
            print("  " + problem)
        sys.exit(1)
    print(f"statements identical to the kernel's: {len(laws)} of {len(laws)}")
    print("no @unsafe, partial def, hole or foreign import")
    print("SOUNDNESS CHECKS PASS")


if __name__ == "__main__":
    main()
