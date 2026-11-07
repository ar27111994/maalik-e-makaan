# Maalik-e-Makaan: the proofs of LAWS.bend.
#
# Bend has no tactics: a proof is a def whose type is the law. A match is a
# case analysis, a recursive call is the induction hypothesis, and `%e : P`
# rewrites the goal with the equation e: P is the goal with _ marking where
# the right side of e stands, and the goal becomes P with e's left side
# there. Each law is proven by the def of the same name, `def Laws.<name>`.
#
# All arithmetic is Base's own (Nat.add, Nat.mul, Nat.sub, Nat.min,
# Nat.divmod). Base proves nothing about division, so Euclid's lemma for
# Nat.divmod, the uniqueness of the quotient and the monotonicity of
# division are proven here, under "Division". No def uses @unsafe, a
# partial def or a foreign import.

import Base
import ./SPEC.bend as Spec
import ./LAWS.bend as Laws

# Equality helpers
# ----------------

def pred(n: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+p:
      p

def succ_inj(-a: Nat, -b: Nat, e: {1n+a == 1n+b : Nat}) -> {a == b : Nat}:
  Equal.cong(Nat, Nat, pred, 1n+a, 1n+b, e)

# a type picked by a Bool: a rewrite through it refutes True{} == False{}
def BD(b: Bool, t: Type, f: Type) -> Type:
  match b:
    case True{}:
      t
    case False{}:
      f

# Addition
# --------

def add_zero(a: Nat) -> {a == Nat.add(a, 0n) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_zero(p) : {1n+p == 1n+_ : Nat}
      {==}

def add_succ(a: Nat, -b: Nat) -> {1n+Nat.add(a, b) == Nat.add(a, 1n+b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_succ(p, b) : {2n+Nat.add(p, b) == 1n+_ : Nat}
      {==}

def add_comm(a: Nat, +b: Nat) -> {Nat.add(a, b) == Nat.add(b, a) : Nat}:
  match a:
    case 0n:
      add_zero(b)
    case 1n+p:
      %add_succ(b, p) : {1n+Nat.add(p, b) == _ : Nat}
      %add_comm(p, b) : {1n+Nat.add(p, b) == 1n+_ : Nat}
      {==}

# a + (b + c) == (a + b) + c
def add_assoc(a: Nat, -b: Nat, -c: Nat) -> {Nat.add(a, Nat.add(b, c)) == Nat.add(Nat.add(a, b), c) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_assoc(p, b, c) : {1n+Nat.add(p, Nat.add(b, c)) == 1n+_ : Nat}
      {==}

# x + (y + z) == y + (x + z)
def add_swap(x: Nat, +y: Nat, +z: Nat) -> {Nat.add(x, Nat.add(y, z)) == Nat.add(y, Nat.add(x, z)) : Nat}:
  match x:
    case 0n:
      {==}
    case 1n+q:
      %add_succ(y, Nat.add(q, z)) : {1n+Nat.add(q, Nat.add(y, z)) == _ : Nat}
      %add_swap(q, y, z) : {1n+Nat.add(q, Nat.add(y, z)) == 1n+_ : Nat}
      {==}

# c + a == c + b gives a == b
def add_cancel(c: Nat, -a: Nat, -b: Nat, e: {Nat.add(c, a) == Nat.add(c, b) : Nat}) -> {a == b : Nat}:
  match c:
    case 0n:
      e
    case 1n+p:
      add_cancel(p, a, b, succ_inj(Nat.add(p, a), Nat.add(p, b), e))

def add_one(a: Nat) -> {1n+a == Nat.add(a, 1n) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %add_one(p) : {2n+p == 1n+_ : Nat}
      {==}

# (x + y) + z == (x + z) + y
def add_right_comm(+x: Nat, +y: Nat, +z: Nat) -> {Nat.add(Nat.add(x, y), z) == Nat.add(Nat.add(x, z), y) : Nat}:
  %add_assoc(x, z, y) : {Nat.add(Nat.add(x, y), z) == _ : Nat}
  %add_assoc(x, y, z) : {_ == Nat.add(x, Nat.add(z, y)) : Nat}
  %add_comm(y, z) : {Nat.add(x, Nat.add(y, z)) == Nat.add(x, _) : Nat}
  {==}

# Multiplication
# --------------

def mul_zero(a: Nat) -> {Nat.mul(a, 0n) == 0n : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      mul_zero(p)

# a + a * b == a * (1 + b)
def mul_succ(+a: Nat, +b: Nat) -> {Nat.add(a, Nat.mul(a, b)) == Nat.mul(a, 1n+b) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n++p:
      %mul_succ(p, b) : {1n+Nat.add(p, Nat.add(b, Nat.mul(p, b))) == 1n+Nat.add(b, _) : Nat}
      %add_swap(p, b, Nat.mul(p, b)) : {1n+Nat.add(p, Nat.add(b, Nat.mul(p, b))) == 1n+_ : Nat}
      {==}

def mul_comm(+a: Nat, +b: Nat) -> {Nat.mul(a, b) == Nat.mul(b, a) : Nat}:
  match a:
    case 0n:
      %mul_zero(b) : {_ == Nat.mul(b, 0n) : Nat}
      {==}
    case 1n++p:
      %mul_succ(b, p) : {Nat.add(b, Nat.mul(p, b)) == _ : Nat}
      %mul_comm(p, b) : {Nat.add(b, Nat.mul(p, b)) == Nat.add(b, _) : Nat}
      {==}

# a * c + b * c == (a + b) * c
def mul_dist(a: Nat, -b: Nat, +c: Nat) -> {Nat.add(Nat.mul(a, c), Nat.mul(b, c)) == Nat.mul(Nat.add(a, b), c) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %mul_dist(p, b, c) : {Nat.add(Nat.add(c, Nat.mul(p, c)), Nat.mul(b, c)) == Nat.add(c, _) : Nat}
      %add_assoc(c, Nat.mul(p, c), Nat.mul(b, c)) : {_ == Nat.add(c, Nat.add(Nat.mul(p, c), Nat.mul(b, c))) : Nat}
      {==}

# a * b + a * c == a * (b + c)
def mul_dist_l(+a: Nat, +b: Nat, +c: Nat) -> {Nat.add(Nat.mul(a, b), Nat.mul(a, c)) == Nat.mul(a, Nat.add(b, c)) : Nat}:
  %mul_comm(Nat.add(b, c), a) : {Nat.add(Nat.mul(a, b), Nat.mul(a, c)) == _ : Nat}
  %mul_dist(b, c, a) : {Nat.add(Nat.mul(a, b), Nat.mul(a, c)) == _ : Nat}
  %mul_comm(b, a) : {Nat.add(_, Nat.mul(a, c)) == Nat.add(Nat.mul(b, a), Nat.mul(c, a)) : Nat}
  %mul_comm(c, a) : {Nat.add(Nat.mul(b, a), _) == Nat.add(Nat.mul(b, a), Nat.mul(c, a)) : Nat}
  {==}

# a * (b * c) == (a * b) * c
def mul_assoc(a: Nat, +b: Nat, +c: Nat) -> {Nat.mul(a, Nat.mul(b, c)) == Nat.mul(Nat.mul(a, b), c) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      %mul_dist(b, Nat.mul(p, b), c) : {Nat.add(Nat.mul(b, c), Nat.mul(p, Nat.mul(b, c))) == _ : Nat}
      %mul_assoc(p, b, c) : {Nat.add(Nat.mul(b, c), Nat.mul(p, Nat.mul(b, c))) == Nat.add(Nat.mul(b, c), _) : Nat}
      {==}

# a * (b * c) == b * (a * c)
def mul_left_comm(+a: Nat, +b: Nat, +c: Nat) -> {Nat.mul(a, Nat.mul(b, c)) == Nat.mul(b, Nat.mul(a, c)) : Nat}:
  %Equal.sym(Nat, Nat.mul(b, Nat.mul(a, c)), Nat.mul(Nat.mul(b, a), c), mul_assoc(b, a, c)) : {Nat.mul(a, Nat.mul(b, c)) == _ : Nat}
  %mul_comm(a, b) : {Nat.mul(a, Nat.mul(b, c)) == Nat.mul(_, c) : Nat}
  mul_assoc(a, b, c)

# x == 1 * x
def one_mul(x: Nat) -> {x == Nat.mul(1n, x) : Nat}:
  add_zero(x)

# x + x == 2 * x
def two_mul(+x: Nat) -> {Nat.add(x, x) == Nat.mul(2n, x) : Nat}:
  %add_zero(x) : {Nat.add(x, x) == Nat.add(x, _) : Nat}
  {==}

# Order
# -----

def le_refl(a: Nat) -> Spec.LE(a, a):
  match a:
    case 0n:
      Unit{}
    case 1n+p:
      le_refl(p)

def le_trans(a: Nat, b: Nat, c: Nat, ab: Spec.LE(a, b), bc: Spec.LE(b, c)) -> Spec.LE(a, c):
  match a b c:
    case 0n _ _:
      Unit{}
    case 1n+a1 0n _:
      match ab:
    case 1n+a1 1n+b1 0n:
      match bc:
    case 1n+a1 1n+b1 1n+c1:
      le_trans(a1, b1, c1, ab, bc)

def le_succ(a: Nat, b: Nat, h: Spec.LE(a, b)) -> Spec.LE(a, 1n+b):
  match a b:
    case 0n _:
      Unit{}
    case 1n+a1 0n:
      match h:
    case 1n+a1 1n+b1:
      le_succ(a1, b1, h)

def lt_le(a: Nat, b: Nat, h: Spec.LT(a, b)) -> Spec.LE(a, b):
  match a b:
    case 0n _:
      Unit{}
    case 1n+a1 0n:
      match h:
    case 1n+a1 1n+b1:
      lt_le(a1, b1, h)

def lt_irrefl(a: Nat, h: Spec.LT(a, a)) -> Empty:
  match a:
    case 0n:
      match h:
    case 1n+p:
      lt_irrefl(p, h)

# b <= a + b
def le_add_l(a: Nat, +b: Nat) -> Spec.LE(b, Nat.add(a, b)):
  match a:
    case 0n:
      le_refl(b)
    case 1n++p:
      le_succ(b, Nat.add(p, b), le_add_l(p, b))

# a <= a + b
def le_add_r(a: Nat, -b: Nat) -> Spec.LE(a, Nat.add(a, b)):
  match a:
    case 0n:
      Unit{}
    case 1n+p:
      le_add_r(p, b)

# a <= b and c <= d give a + c <= b + d
def le_add_mono(a: Nat, +b: Nat, +c: Nat, +d: Nat, ab: Spec.LE(a, b), cd: Spec.LE(c, d)) -> Spec.LE(Nat.add(a, c), Nat.add(b, d)):
  match a b:
    case 0n _:
      le_trans(c, d, Nat.add(b, d), cd, le_add_l(b, d))
    case 1n+a1 0n:
      match ab:
    case 1n+a1 1n+b1:
      le_add_mono(a1, b1, c, d, ab, cd)

# the verdict of a comparison, with its evidence
def le_or_gt(a: Nat, b: Nat) -> Or(Spec.LE(a, b), Spec.LT(b, a)):
  match a b:
    case 0n _:
      Inl{Unit{}}
    case 1n+a1 0n:
      Inr{Unit{}}
    case 1n+a1 1n+b1:
      le_or_gt(a1, b1)

# a <= b gives a * c <= b * c
def le_mul_l(a: Nat, b: Nat, +c: Nat, h: Spec.LE(a, b)) -> Spec.LE(Nat.mul(a, c), Nat.mul(b, c)):
  match a b:
    case 0n _:
      Unit{}
    case 1n+a1 0n:
      match h:
    case 1n++a1 1n++b1:
      le_add_mono(c, c, Nat.mul(a1, c), Nat.mul(b1, c), le_refl(c), le_mul_l(a1, b1, c, h))

# b <= c gives a * b <= a * c
def le_mul_r(a: Nat, +b: Nat, +c: Nat, +h: Spec.LE(b, c)) -> Spec.LE(Nat.mul(a, b), Nat.mul(a, c)):
  match a:
    case 0n:
      Unit{}
    case 1n++p:
      le_add_mono(b, c, Nat.mul(p, b), Nat.mul(p, c), h, le_mul_r(p, b, c, h))

# a <= b and b == c give a <= c
def le_rw_r(-a: Nat, -b: Nat, -c: Nat, h: Spec.LE(a, b), e: {b == c : Nat}) -> Spec.LE(a, c):
  %e : Spec.LE(a, _)
  h

# a == b and a <= c give b <= c
def le_rw_l(-a: Nat, -b: Nat, -c: Nat, h: Spec.LE(a, c), e: {a == b : Nat}) -> Spec.LE(b, c):
  %e : Spec.LE(_, c)
  h

# a == b and a < c give b < c
def lt_rw_l(-a: Nat, -b: Nat, -c: Nat, h: Spec.LT(a, c), e: {a == b : Nat}) -> Spec.LT(b, c):
  %e : Spec.LT(_, c)
  h

# k * a <= k * b with k > 0 gives a <= b
def le_mul_cancel.go(+kp: Nat, +a: Nat, +b: Nat, h: Spec.LE(Nat.mul(1n+kp, a), Nat.mul(1n+kp, b)), c: Or(Spec.LE(a, b), Spec.LT(b, a))) -> Spec.LE(a, b):
  match c:
    case Inl{e}:
      e
    case Inr{e}:
      +m = Nat.mul(1n+kp, b)
      step = le_rw_l(Nat.mul(1n+kp, 1n+b), Nat.add(1n+kp, m), Nat.mul(1n+kp, a), le_mul_r(1n+kp, 1n+b, a, e), Equal.sym(Nat, Nat.add(1n+kp, m), Nat.mul(1n+kp, 1n+b), mul_succ(1n+kp, b)))
      Empty.absurd(Spec.LE(a, b), lt_irrefl(m, le_trans(1n+m, Nat.add(1n+kp, m), m, le_add_l(kp, m), le_trans(Nat.add(1n+kp, m), Nat.mul(1n+kp, a), m, step, h))))

def le_mul_cancel(+kp: Nat, +a: Nat, +b: Nat, h: Spec.LE(Nat.mul(1n+kp, a), Nat.mul(1n+kp, b))) -> Spec.LE(a, b):
  le_mul_cancel.go(kp, a, b, h, le_or_gt(a, b))

# Comparisons as evidence
# -----------------------
# Base compares with Bool-valued Nat.is_le / is_ge / is_eq; these turn a
# verdict into a proof of the order it reports, and back.

def is_le_true(a: Nat, b: Nat, e: {Nat.is_le(a, b) == True{} : Bool}) -> Spec.LE(a, b):
  match a b:
    case 0n _:
      Unit{}
    case 1n+a1 0n:
      %e : BD(_, Empty, Unit)
      Unit{}
    case 1n+a1 1n+b1:
      is_le_true(a1, b1, e)

def is_le_false(a: Nat, b: Nat, e: {Nat.is_le(a, b) == False{} : Bool}) -> Spec.LT(b, a):
  match a b:
    case 0n 0n:
      %e : BD(_, Unit, Empty)
      Unit{}
    case 0n 1n+b1:
      %e : BD(_, Unit, Empty)
      Unit{}
    case 1n+a1 0n:
      Unit{}
    case 1n+a1 1n+b1:
      is_le_false(a1, b1, e)

def is_ge_true(a: Nat, b: Nat, e: {Nat.is_ge(a, b) == True{} : Bool}) -> Spec.LE(b, a):
  match a b:
    case 0n 0n:
      Unit{}
    case 0n 1n+b1:
      %e : BD(_, Empty, Unit)
      Unit{}
    case 1n+a1 0n:
      Unit{}
    case 1n+a1 1n+b1:
      is_ge_true(a1, b1, e)

def is_ge_false(a: Nat, b: Nat, e: {Nat.is_ge(a, b) == False{} : Bool}) -> Spec.LT(a, b):
  match a b:
    case 0n 0n:
      %e : BD(_, Unit, Empty)
      Unit{}
    case 0n 1n+b1:
      Unit{}
    case 1n+a1 0n:
      %e : BD(_, Unit, Empty)
      Unit{}
    case 1n+a1 1n+b1:
      is_ge_false(a1, b1, e)

def is_eq_refl(a: Nat) -> {True{} == Nat.is_eq(a, a) : Bool}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      is_eq_refl(p)

def is_eq_lt(a: Nat, b: Nat, h: Spec.LT(a, b)) -> {False{} == Nat.is_eq(a, b) : Bool}:
  match a b:
    case 0n 0n:
      match h:
    case 0n 1n+b1:
      {==}
    case 1n+a1 0n:
      match h:
    case 1n+a1 1n+b1:
      is_eq_lt(a1, b1, h)

def is_le_of_le(a: Nat, b: Nat, h: Spec.LE(a, b)) -> {True{} == Nat.is_le(a, b) : Bool}:
  match a b:
    case 0n 0n:
      {==}
    case 0n 1n+b1:
      {==}
    case 1n+a1 0n:
      match h:
    case 1n+a1 1n+b1:
      is_le_of_le(a1, b1, h)

# Subtraction and min
# -------------------

def sub_zero(a: Nat) -> {a == Nat.sub(a, 0n) : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      {==}

def sub_le(a: Nat, b: Nat) -> Spec.LE(Nat.sub(a, b), a):
  match a b:
    case 0n _:
      Unit{}
    case 1n+ap 0n:
      le_refl(1n+ap)
    case 1n++ap 1n++bp:
      le_succ(Nat.sub(ap, bp), ap, sub_le(ap, bp))

# (x + r) - x == r
def sub_add_cancel(x: Nat, +r: Nat) -> {r == Nat.sub(Nat.add(x, r), x) : Nat}:
  match x:
    case 0n:
      sub_zero(r)
    case 1n+p:
      sub_add_cancel(p, r)

# x <= z gives x + (z - x) == z
def add_sub(x: Nat, z: Nat, h: Spec.LE(x, z)) -> {Nat.add(x, Nat.sub(z, x)) == z : Nat}:
  match x z:
    case 0n _:
      Equal.sym(Nat, z, Nat.sub(z, 0n), sub_zero(z))
    case 1n+x1 0n:
      match h:
    case 1n+x1 1n+z1:
      %add_sub(x1, z1, h) : {1n+Nat.add(x1, Nat.sub(z1, x1)) == 1n+_ : Nat}
      {==}

# x <= z and y <= z - x give x + y <= z
def le_add_sub(x: Nat, y: Nat, z: Nat, hx: Spec.LE(x, z), hy: Spec.LE(y, Nat.sub(z, x))) -> Spec.LE(Nat.add(x, y), z):
  match x z:
    case 0n _:
      le_rw_r(y, Nat.sub(z, 0n), z, hy, Equal.sym(Nat, z, Nat.sub(z, 0n), sub_zero(z)))
    case 1n+x1 0n:
      match hx:
    case 1n+x1 1n+z1:
      le_add_sub(x1, y, z1, hx, hy)

def min_le_r(+a: Nat, +b: Nat) -> Spec.LE(Nat.min(a, b), b):
  match a b:
    case 0n _:
      Unit{}
    case 1n+ap 0n:
      Unit{}
    case 1n+ap 1n+bp:
      min_le_r(ap, bp)

# min(a, h) + (a - min(a, h)) == a
def min_sub(+a: Nat, +h: Nat) -> {Nat.add(Nat.min(a, h), Nat.sub(a, Nat.min(a, h))) == a : Nat}:
  match a h:
    case 0n _:
      {==}
    case 1n+ap 0n:
      {==}
    case 1n+ap 1n+hp:
      %min_sub(ap, hp) : {1n+Nat.add(Nat.min(ap, hp), Nat.sub(ap, Nat.min(ap, hp))) == 1n+_ : Nat}
      {==}

# when something of a is left after taking min(a, h), the min was h
def min_full(+a: Nat, +h: Nat, pos: Spec.LT(0n, Nat.sub(a, Nat.min(a, h)))) -> {Nat.min(a, h) == h : Nat}:
  match a h:
    case 0n _:
      match pos:
    case 1n+ap 0n:
      {==}
    case 1n+ap 1n+hp:
      %min_full(ap, hp, pos) : {1n+Nat.min(ap, hp) == 1n+_ : Nat}
      {==}

# min(a, h) is positive when a and h are
def min_pos(+a: Nat, +h: Nat, pa: Spec.LT(0n, a), ph: Spec.LT(0n, h)) -> Spec.LT(0n, Nat.min(a, h)):
  match a h:
    case 0n _:
      match pa:
    case 1n+ap 0n:
      match ph:
    case 1n+ap 1n+hp:
      Unit{}

def min_mono(x: Nat, y: Nat, c: Nat, h: Spec.LE(x, y)) -> Spec.LE(Nat.min(x, c), Nat.min(y, c)):
  match x y c:
    case 0n _ _:
      Unit{}
    case 1n+x1 0n _:
      match h:
    case 1n+x1 1n+y1 0n:
      Unit{}
    case 1n+x1 1n+y1 1n+c1:
      min_mono(x1, y1, c1, h)

def min_le_l(+a: Nat, +b: Nat) -> Spec.LE(Nat.min(a, b), a):
  match a b:
    case 0n _:
      Unit{}
    case 1n+ap 0n:
      Unit{}
    case 1n+ap 1n+bp:
      min_le_l(ap, bp)

# a <= b gives min(a, b) == a
def min_l_of_le(a: Nat, b: Nat, h: Spec.LE(a, b)) -> {Nat.min(a, b) == a : Nat}:
  match a b:
    case 0n _:
      {==}
    case 1n+ap 0n:
      match h:
    case 1n+ap 1n+bp:
      %min_l_of_le(ap, bp, h) : {1n+Nat.min(ap, bp) == 1n+_ : Nat}
      {==}

# b <= a gives min(a, b) == b
def min_r_of_le(a: Nat, b: Nat, h: Spec.LE(b, a)) -> {Nat.min(a, b) == b : Nat}:
  match a b:
    case 0n 0n:
      {==}
    case 0n 1n+bp:
      match h:
    case 1n+ap 0n:
      {==}
    case 1n+ap 1n+bp:
      %min_r_of_le(ap, bp, h) : {1n+Nat.min(ap, bp) == 1n+_ : Nat}
      {==}

def min_zero_r(a: Nat) -> {Nat.min(a, 0n) == 0n : Nat}:
  match a:
    case 0n:
      {==}
    case 1n+p:
      {==}

# min(min(a, b), b) == min(a, b)
def min_idem(a: Nat, b: Nat) -> {Nat.min(Nat.min(a, b), b) == Nat.min(a, b) : Nat}:
  match a b:
    case 0n _:
      {==}
    case 1n+ap 0n:
      {==}
    case 1n+ap 1n+bp:
      %min_idem(ap, bp) : {1n+Nat.min(Nat.min(ap, bp), bp) == 1n+_ : Nat}
      {==}

# t <= a gives min(min(a, c), t) == min(min(t, c), t)
def min_absorb(t: Nat, a: Nat, c: Nat, h: Spec.LE(t, a)) -> {Nat.min(Nat.min(a, c), t) == Nat.min(Nat.min(t, c), t) : Nat}:
  match t:
    case 0n:
      min_zero_r(Nat.min(a, c))
    case 1n+tp:
      match a:
        case 0n:
          match h:
        case 1n+ap:
          match c:
            case 0n:
              {==}
            case 1n+cp:
              %min_absorb(tp, ap, cp, h) : {1n+Nat.min(Nat.min(ap, cp), tp) == 1n+_ : Nat}
              {==}

# Division
# --------
# Nat.divmod(a, 1n+bp) runs Nat.divmod.go(a, bp, 0n, 0n): n steps left, m
# steps before the remainder r wraps around, quotient d; m + r == bp holds
# throughout. A divisor is written 1n+bp so that it is visibly positive.

def go_eq(n: Nat, m: Nat, +d: Nat, +r: Nat, -bp: Nat, inv: {Nat.add(m, r) == bp : Nat})
  -> {Nat.add(n, Nat.add(r, Nat.mul(d, 1n+bp))) == Nat.add(Pair.snd(Nat, Nat, Nat.divmod.go(n, m, d, r)), Nat.mul(Pair.fst(Nat, Nat, Nat.divmod.go(n, m, d, r)), 1n+bp)) : Nat}:
  match n:
    case 0n:
      {==}
    case 1n++np:
      match m:
        case 0n:
          %inv : {1n+Nat.add(np, Nat.add(r, Nat.mul(d, 1n+_))) == Nat.add(Pair.snd(Nat, Nat, Nat.divmod.go(np, r, 1n+d, 0n)), Nat.mul(Pair.fst(Nat, Nat, Nat.divmod.go(np, r, 1n+d, 0n)), 1n+_)) : Nat}
          %go_eq(np, r, 1n+d, 0n, r, Equal.sym(Nat, r, Nat.add(r, 0n), add_zero(r))) : {1n+Nat.add(np, Nat.add(r, Nat.mul(d, 1n+r))) == _ : Nat}
          add_succ(np, Nat.add(r, Nat.mul(d, 1n+r)))
        case 1n++mp:
          inv2 = Equal.trans(Nat, Nat.add(mp, 1n+r), 1n+Nat.add(mp, r), bp, Equal.sym(Nat, 1n+Nat.add(mp, r), Nat.add(mp, 1n+r), add_succ(mp, r)), inv)
          %go_eq(np, mp, d, 1n+r, bp, inv2) : {1n+Nat.add(np, Nat.add(r, Nat.mul(d, 1n+bp))) == _ : Nat}
          add_succ(np, Nat.add(r, Nat.mul(d, 1n+bp)))

def go_le(n: Nat, m: Nat, +d: Nat, +r: Nat, -bp: Nat, inv: {Nat.add(m, r) == bp : Nat})
  -> Spec.LE(Pair.snd(Nat, Nat, Nat.divmod.go(n, m, d, r)), bp):
  match n:
    case 0n:
      %inv : Spec.LE(r, _)
      le_add_l(m, r)
    case 1n+np:
      match m:
        case 0n:
          go_le(np, r, 1n+d, 0n, bp, Equal.trans(Nat, Nat.add(r, 0n), r, bp, Equal.sym(Nat, r, Nat.add(r, 0n), add_zero(r)), inv))
        case 1n++mp:
          go_le(np, mp, d, 1n+r, bp, Equal.trans(Nat, Nat.add(mp, 1n+r), 1n+Nat.add(mp, r), bp, Equal.sym(Nat, 1n+Nat.add(mp, r), Nat.add(mp, 1n+r), add_succ(mp, r)), inv))

# a == a mod b + (a div b) * b, for b = 1n+bp
def euclid(+a: Nat, +bp: Nat) -> {a == Nat.add(Nat.mod(a, 1n+bp), Nat.mul(Nat.div(a, 1n+bp), 1n+bp)) : Nat}:
  %go_eq(a, bp, 0n, 0n, bp, Equal.sym(Nat, bp, Nat.add(bp, 0n), add_zero(bp))) : {a == _ : Nat}
  add_zero(a)

# a mod b < b, for b = 1n+bp
def mod_lt(a: Nat, +bp: Nat) -> Spec.LT(Nat.mod(a, 1n+bp), 1n+bp):
  go_le(a, bp, 0n, 0n, bp, Equal.sym(Nat, bp, Nat.add(bp, 0n), add_zero(bp)))

# r == s + (b + x) with b == 1n+bp cannot hold for r <= bp
def wrap_absurd(+r: Nat, +s: Nat, +x: Nat, +bp: Nat, h: Spec.LE(r, bp), e: {r == Nat.add(s, Nat.add(1n+bp, x)) : Nat}) -> Empty:
  big = le_trans(1n+bp, Nat.add(1n+bp, x), Nat.add(s, Nat.add(1n+bp, x)), le_add_r(1n+bp, x), le_add_l(s, Nat.add(1n+bp, x)))
  lt_irrefl(bp, le_trans(1n+bp, r, bp, le_rw_r(1n+bp, Nat.add(s, Nat.add(1n+bp, x)), r, big, Equal.sym(Nat, r, Nat.add(s, Nat.add(1n+bp, x)), e)), h))

# the quotient of a division is unique: r1 + q1 * b == r2 + q2 * b with
# r1, r2 < b gives q1 == q2
def qr_unique(q1: Nat, +r1: Nat, q2: Nat, +r2: Nat, +bp: Nat, h1: Spec.LE(r1, bp), h2: Spec.LE(r2, bp),
  e: {Nat.add(r1, Nat.mul(q1, 1n+bp)) == Nat.add(r2, Nat.mul(q2, 1n+bp)) : Nat}) -> {q1 == q2 : Nat}:
  match q1 q2:
    case 0n 0n:
      {==}
    case 0n 1n++k2:
      Empty.absurd({0n == 1n+k2 : Nat}, wrap_absurd(r1, r2, Nat.mul(k2, 1n+bp), bp, h1, Equal.trans(Nat, r1, Nat.add(r1, 0n), Nat.add(r2, Nat.add(1n+bp, Nat.mul(k2, 1n+bp))), add_zero(r1), e)))
    case 1n++k1 0n:
      Empty.absurd({1n+k1 == 0n : Nat}, wrap_absurd(r2, r1, Nat.mul(k1, 1n+bp), bp, h2, Equal.trans(Nat, r2, Nat.add(r2, 0n), Nat.add(r1, Nat.add(1n+bp, Nat.mul(k1, 1n+bp))), add_zero(r2), Equal.sym(Nat, Nat.add(r1, Nat.add(1n+bp, Nat.mul(k1, 1n+bp))), Nat.add(r2, 0n), e))))
    case 1n++k1 1n++k2:
      s1 = add_swap(r1, 1n+bp, Nat.mul(k1, 1n+bp))
      s2 = add_swap(r2, 1n+bp, Nat.mul(k2, 1n+bp))
      e1 = Equal.trans(Nat, Nat.add(1n+bp, Nat.add(r1, Nat.mul(k1, 1n+bp))), Nat.add(r1, Nat.add(1n+bp, Nat.mul(k1, 1n+bp))), Nat.add(1n+bp, Nat.add(r2, Nat.mul(k2, 1n+bp))), Equal.sym(Nat, Nat.add(r1, Nat.add(1n+bp, Nat.mul(k1, 1n+bp))), Nat.add(1n+bp, Nat.add(r1, Nat.mul(k1, 1n+bp))), s1), Equal.trans(Nat, Nat.add(r1, Nat.add(1n+bp, Nat.mul(k1, 1n+bp))), Nat.add(r2, Nat.add(1n+bp, Nat.mul(k2, 1n+bp))), Nat.add(1n+bp, Nat.add(r2, Nat.mul(k2, 1n+bp))), e, s2))
      %qr_unique(k1, r1, k2, r2, bp, h1, h2, add_cancel(1n+bp, Nat.add(r1, Nat.mul(k1, 1n+bp)), Nat.add(r2, Nat.mul(k2, 1n+bp)), e1)) : {1n+k1 == 1n+_ : Nat}
      {==}

# r + q * b divided by b is q, when r < b (b == 1n+bp)
def div_unique(+q: Nat, +r: Nat, +bp: Nat, h: Spec.LE(r, bp)) -> {Nat.div(Nat.add(r, Nat.mul(q, 1n+bp)), 1n+bp) == q : Nat}:
  +n = Nat.add(r, Nat.mul(q, 1n+bp))
  qr_unique(Nat.div(n, 1n+bp), Nat.mod(n, 1n+bp), q, r, bp, mod_lt(n, bp), h, Equal.sym(Nat, n, Nat.add(Nat.mod(n, 1n+bp), Nat.mul(Nat.div(n, 1n+bp), 1n+bp)), euclid(n, bp)))

# division is monotone in the dividend
def div_mono.go(+x: Nat, +y: Nat, +bp: Nat, xy: Spec.LE(x, y),
  c: Or(Spec.LE(Nat.div(x, 1n+bp), Nat.div(y, 1n+bp)), Spec.LT(Nat.div(y, 1n+bp), Nat.div(x, 1n+bp))))
  -> Spec.LE(Nat.div(x, 1n+bp), Nat.div(y, 1n+bp)):
  match c:
    case Inl{e}:
      e
    case Inr{e}:
      +qx = Nat.div(x, 1n+bp)
      +qy = Nat.div(y, 1n+bp)
      +ry = Nat.mod(y, 1n+bp)
      +rx = Nat.mod(x, 1n+bp)
      # y < (1 + qy) * b
      y_lt = lt_rw_l(Nat.add(ry, Nat.mul(qy, 1n+bp)), y, Nat.add(1n+bp, Nat.mul(qy, 1n+bp)), le_add_mono(1n+ry, 1n+bp, Nat.mul(qy, 1n+bp), Nat.mul(qy, 1n+bp), mod_lt(y, bp), le_refl(Nat.mul(qy, 1n+bp))), Equal.sym(Nat, y, Nat.add(ry, Nat.mul(qy, 1n+bp)), euclid(y, bp)))
      # (1 + qy) * b <= qx * b <= x
      hi = le_mul_l(1n+qy, qx, 1n+bp, e)
      x_ge = le_rw_r(Nat.mul(qx, 1n+bp), Nat.add(rx, Nat.mul(qx, 1n+bp)), x, le_add_l(rx, Nat.mul(qx, 1n+bp)), Equal.sym(Nat, x, Nat.add(rx, Nat.mul(qx, 1n+bp)), euclid(x, bp)))
      y_lt_x = le_trans(1n+y, Nat.mul(qx, 1n+bp), x, le_trans(1n+y, Nat.mul(1n+qy, 1n+bp), Nat.mul(qx, 1n+bp), y_lt, hi), x_ge)
      Empty.absurd(Spec.LE(qx, qy), lt_irrefl(y, le_trans(1n+y, x, y, y_lt_x, xy)))

def div_mono(+x: Nat, +y: Nat, +bp: Nat, xy: Spec.LE(x, y)) -> Spec.LE(Nat.div(x, 1n+bp), Nat.div(y, 1n+bp)):
  div_mono.go(x, y, bp, xy, le_or_gt(Nat.div(x, 1n+bp), Nat.div(y, 1n+bp)))

# N0 + q * D divided by D is (N0 div D) + q, for D == 1n+xp
def div_shift(+n0: Nat, +q: Nat, +xp: Nat) -> {Nat.add(Nat.div(n0, 1n+xp), q) == Nat.div(Nat.add(n0, Nat.mul(q, 1n+xp)), 1n+xp) : Nat}:
  +q0 = Nat.div(n0, 1n+xp)
  +r0 = Nat.mod(n0, 1n+xp)
  %Equal.sym(Nat, n0, Nat.add(r0, Nat.mul(q0, 1n+xp)), euclid(n0, xp)) : {Nat.add(q0, q) == Nat.div(Nat.add(_, Nat.mul(q, 1n+xp)), 1n+xp) : Nat}
  %add_assoc(r0, Nat.mul(q0, 1n+xp), Nat.mul(q, 1n+xp)) : {Nat.add(q0, q) == Nat.div(_, 1n+xp) : Nat}
  %Equal.sym(Nat, Nat.add(Nat.mul(q0, 1n+xp), Nat.mul(q, 1n+xp)), Nat.mul(Nat.add(q0, q), 1n+xp), mul_dist(q0, q, 1n+xp)) : {Nat.add(q0, q) == Nat.div(Nat.add(r0, _), 1n+xp) : Nat}
  Equal.sym(Nat, Nat.div(Nat.add(r0, Nat.mul(Nat.add(q0, q), 1n+xp)), 1n+xp), Nat.add(q0, q), div_unique(Nat.add(q0, q), r0, xp, mod_lt(n0, xp)))

# N0 < D gives N0 div D == 0
def div_small(+n0: Nat, +xp: Nat, h: Spec.LE(n0, xp)) -> {0n == Nat.div(n0, 1n+xp) : Nat}:
  %Equal.sym(Nat, n0, Nat.add(n0, 0n), add_zero(n0)) : {0n == Nat.div(_, 1n+xp) : Nat}
  Equal.sym(Nat, Nat.div(Nat.add(n0, 0n), 1n+xp), 0n, div_unique(0n, n0, xp, h))

# (k * a) div (k * b) == a div b, for k == 1n+kp and b == 1n+bp
def div_scale(+kp: Nat, +a: Nat, +bp: Nat) -> {Nat.div(Nat.mul(1n+kp, a), Nat.mul(1n+kp, 1n+bp)) == Nat.div(a, 1n+bp) : Nat}:
  +q = Nat.div(a, 1n+bp)
  +r = Nat.mod(a, 1n+bp)
  +k = {1n+kp : Nat}
  +xp = Nat.add(bp, Nat.mul(kp, 1n+bp))
  %Equal.sym(Nat, a, Nat.add(r, Nat.mul(q, 1n+bp)), euclid(a, bp)) : {Nat.div(Nat.mul(k, _), Nat.mul(k, 1n+bp)) == q : Nat}
  %mul_dist_l(k, r, Nat.mul(q, 1n+bp)) : {Nat.div(_, Nat.mul(k, 1n+bp)) == q : Nat}
  %mul_left_comm(q, k, 1n+bp) : {Nat.div(Nat.add(Nat.mul(k, r), _), Nat.mul(k, 1n+bp)) == q : Nat}
  kr = le_trans(1n+Nat.mul(k, r), Nat.add(k, Nat.mul(k, r)), Nat.mul(k, 1n+bp), le_add_l(kp, Nat.mul(k, r)), le_rw_l(Nat.mul(k, 1n+r), Nat.add(k, Nat.mul(k, r)), Nat.mul(k, 1n+bp), le_mul_r(k, 1n+r, 1n+bp, mod_lt(a, bp)), Equal.sym(Nat, Nat.add(k, Nat.mul(k, r)), Nat.mul(k, 1n+r), mul_succ(k, r))))
  div_unique(q, Nat.mul(k, r), xp, kr)

# Vocabulary laws
# ---------------

def Laws.le_is_base_le(a, b, h):
  Equal.sym(Bool, True{}, Nat.is_le(a, b), is_le_of_le(a, b, h))

def Laws.base_le_is_le(a, b, e):
  is_le_true(a, b, e)

# 1. FIFO payment allocation
# --------------------------

def Laws.fifo_conserves(xs, p):
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      match p:
        case 0n:
          {==}
        case 1n+r:
          +a = Nat.min(1n+r, h)
          +s = Nat.sub(1n+r, Nat.min(1n+r, h))
          %add_assoc(a, Spec.sum(Spec.alloc(t, s)), Spec.unallocated(t, s)) : {_ == 1n+r : Nat}
          %min_sub(1n+r, h) : {Nat.add(a, Nat.add(Spec.sum(Spec.alloc(t, s)), Spec.unallocated(t, s))) == _ : Nat}
          %Laws.fifo_conserves(t, s) : {Nat.add(a, Nat.add(Spec.sum(Spec.alloc(t, s)), Spec.unallocated(t, s))) == Nat.add(a, _) : Nat}
          {==}

def Laws.fifo_allocated_le_payment(xs, p):
  le_rw_r(Spec.sum(Spec.alloc(xs, p)), Nat.add(Spec.sum(Spec.alloc(xs, p)), Spec.unallocated(xs, p)), p, le_add_r(Spec.sum(Spec.alloc(xs, p)), Spec.unallocated(xs, p)), Laws.fifo_conserves(xs, p))

def Laws.fifo_bounded(xs, p, i):
  match xs:
    case Nil{}:
      Unit{}
    case h <> t:
      match p:
        case 0n:
          Unit{}
        case 1n+r:
          match i:
            case 0n:
              min_le_r(1n+r, h)
            case 1n+j:
              Laws.fifo_bounded(t, Nat.sub(1n+r, Nat.min(1n+r, h)), j)

# what is left unallocated is at most the payment
def unallocated_le(+xs: List<&2, Nat>, +p: Nat) -> Spec.LE(Spec.unallocated(xs, p), p):
  le_rw_r(Spec.unallocated(xs, p), Nat.add(Spec.sum(Spec.alloc(xs, p)), Spec.unallocated(xs, p)), p, le_add_l(Spec.sum(Spec.alloc(xs, p)), Spec.unallocated(xs, p)), Laws.fifo_conserves(xs, p))

def Laws.fifo_leftover_settles_all(xs, p, rest):
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      match p:
        case 0n:
          match rest:
        case 1n+r:
          +s = Nat.sub(1n+r, Nat.min(1n+r, h))
          %Laws.fifo_leftover_settles_all(t, s, rest) : {Nat.min(1n+r, h) <> Spec.alloc(t, s) == h <> _ : List<&2, Nat>}
          %min_full(1n+r, h, le_trans(1n, Spec.unallocated(t, s), s, rest, unallocated_le(t, s))) : {Nat.min(1n+r, h) <> Spec.alloc(t, s) == _ <> Spec.alloc(t, s) : List<&2, Nat>}
          {==}

# a payment that pays anything had something left to pay
def alloc_pos(xs: List<&2, Nat>, s: Nat, i: Nat, paid: Spec.LT(0n, Spec.at(Spec.alloc(xs, s), i))) -> Spec.LT(0n, s):
  match xs:
    case Nil{}:
      match paid:
    case h <> t:
      match s:
        case 0n:
          match paid:
        case 1n+k:
          Unit{}

def Laws.fifo_order(xs, p, i, j, before, paid):
  match xs:
    case Nil{}:
      match paid:
    case h <> t:
      match p:
        case 0n:
          match paid:
        case 1n+r:
          match i:
            case 0n:
              match before:
            case 1n+i1:
              match j:
                case 0n:
                  min_full(1n+r, h, alloc_pos(t, Nat.sub(1n+r, Nat.min(1n+r, h)), i1, paid))
                case 1n+j1:
                  Laws.fifo_order(t, Nat.sub(1n+r, Nat.min(1n+r, h)), i1, j1, before, paid)

def Laws.fifo_rows_positive(xs, p, i, row, open):
  match xs:
    case Nil{}:
      match row:
    case h <> t:
      match p:
        case 0n:
          match row:
        case 1n+r:
          match i:
            case 0n:
              min_pos(1n+r, h, Unit{}, open)
            case 1n+j:
              Laws.fifo_rows_positive(t, Nat.sub(1n+r, Nat.min(1n+r, h)), j, row, open)

# the outstanding amount of charge i after booking ys
def at_settle(xs: List<&2, Nat>, ys: List<&2, Nat>, +i: Nat) -> {Spec.at(Spec.settle(xs, ys), i) == Nat.sub(Spec.at(xs, i), Spec.at(ys, i)) : Nat}:
  match xs ys:
    case Nil{} _:
      {==}
    case x <> xt Nil{}:
      sub_zero(Spec.at(x <> xt, i))
    case x <> xt y <> yt:
      match i:
        case 0n:
          {==}
        case 1n+k:
          at_settle(xt, yt, k)

def Laws.fifo_two_payments(xs, p1, p2, i):
  +a1 = Spec.alloc(xs, p1)
  +r1 = Spec.settle(xs, a1)
  b2 = le_rw_r(Spec.at(Spec.alloc(r1, p2), i), Spec.at(r1, i), Nat.sub(Spec.at(xs, i), Spec.at(a1, i)), Laws.fifo_bounded(r1, p2, i), at_settle(xs, a1, i))
  le_add_sub(Spec.at(a1, i), Spec.at(Spec.alloc(r1, p2), i), Spec.at(xs, i), Laws.fifo_bounded(xs, p1, i), b2)

def Laws.fifo_payments_conserve(ps, xs, i):
  match ps:
    case Nil{}:
      {==}
    case p <> pt:
      +a = Spec.alloc(xs, p)
      +r = Spec.settle(xs, a)
      %add_assoc(Spec.at(a, i), Spec.paid_to(pt, r, i), Spec.at(Spec.outstanding(pt, r), i)) : {_ == Spec.at(xs, i) : Nat}
      %Equal.sym(Nat, Nat.add(Spec.paid_to(pt, r, i), Spec.at(Spec.outstanding(pt, r), i)), Spec.at(r, i), Laws.fifo_payments_conserve(pt, r, i)) : {Nat.add(Spec.at(a, i), _) == Spec.at(xs, i) : Nat}
      %Equal.sym(Nat, Spec.at(r, i), Nat.sub(Spec.at(xs, i), Spec.at(a, i)), at_settle(xs, a, i)) : {Nat.add(Spec.at(a, i), _) == Spec.at(xs, i) : Nat}
      add_sub(Spec.at(a, i), Spec.at(xs, i), Laws.fifo_bounded(xs, p, i))

def Laws.fifo_payments_never_overpay(ps, xs, i):
  le_rw_r(Spec.paid_to(ps, xs, i), Nat.add(Spec.paid_to(ps, xs, i), Spec.at(Spec.outstanding(ps, xs), i)), Spec.at(xs, i), le_add_r(Spec.paid_to(ps, xs, i), Spec.at(Spec.outstanding(ps, xs), i)), Laws.fifo_payments_conserve(ps, xs, i))

# 2. Even split
# -------------

def len_rep(n: Nat, +q: Nat) -> {List.length(&2, Nat, List.replicate(Nat, n, q)) == n : Nat}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      %len_rep(p, q) : {1n+List.length(&2, Nat, List.replicate(Nat, p, q)) == 1n+_ : Nat}
      {==}

def len_bump(xs: List<&2, Nat>, l: Nat) -> {List.length(&2, Nat, Spec.split.bump(xs, l)) == List.length(&2, Nat, xs) : Nat}:
  match xs:
    case Nil{}:
      {==}
    case h <> t:
      match l:
        case 0n:
          {==}
        case 1n+k:
          %len_bump(t, k) : {1n+List.length(&2, Nat, Spec.split.bump(t, k)) == 1n+_ : Nat}
          {==}

def sum_rep(n: Nat, +q: Nat) -> {Spec.sum(List.replicate(Nat, n, q)) == Nat.mul(n, q) : Nat}:
  match n:
    case 0n:
      {==}
    case 1n+p:
      %sum_rep(p, q) : {Nat.add(q, Spec.sum(List.replicate(Nat, p, q))) == Nat.add(q, _) : Nat}
      {==}

# bumping l <= length(xs) slots adds l to the sum
def sum_bump(xs: List<&2, Nat>, l: Nat, hl: Spec.LE(l, List.length(&2, Nat, xs))) -> {Spec.sum(Spec.split.bump(xs, l)) == Nat.add(Spec.sum(xs), l) : Nat}:
  match xs:
    case Nil{}:
      match l:
        case 0n:
          {==}
        case 1n+k:
          match hl:
    case +h <> +t:
      match l:
        case 0n:
          add_zero(Nat.add(h, Spec.sum(t)))
        case 1n+k:
          %Equal.sym(Nat, Spec.sum(Spec.split.bump(t, k)), Nat.add(Spec.sum(t), k), sum_bump(t, k, hl)) : {1n+Nat.add(h, _) == Nat.add(Nat.add(h, Spec.sum(t)), 1n+k) : Nat}
          %add_succ(Nat.add(h, Spec.sum(t)), k) : {1n+Nat.add(h, Nat.add(Spec.sum(t), k)) == _ : Nat}
          %add_assoc(h, Spec.sum(t), k) : {1n+Nat.add(h, Nat.add(Spec.sum(t), k)) == 1n+_ : Nat}
          {==}

def Laws.split_count(m, n):
  +q = Nat.div(m, n)
  +rep = List.replicate(Nat, n, q)
  Equal.trans(Nat, List.length(&2, Nat, Spec.split.bump(rep, Nat.sub(m, Spec.sum(rep)))), List.length(&2, Nat, rep), n, len_bump(rep, Nat.sub(m, Spec.sum(rep))), len_rep(n, q))

# the parts before the leftover loop add up to (m div n) * n
def split_base(+m: Nat, +np: Nat) -> {Nat.mul(Nat.div(m, 1n+np), 1n+np) == Spec.sum(List.replicate(Nat, 1n+np, Nat.div(m, 1n+np))) : Nat}:
  +q = Nat.div(m, 1n+np)
  Equal.sym(Nat, Spec.sum(List.replicate(Nat, 1n+np, q)), Nat.mul(q, 1n+np), Equal.trans(Nat, Spec.sum(List.replicate(Nat, 1n+np, q)), Nat.mul(1n+np, q), Nat.mul(q, 1n+np), sum_rep(1n+np, q), mul_comm(1n+np, q)))

# the leftover is m mod n
def split_leftover(+m: Nat, +np: Nat) -> {Nat.mod(m, 1n+np) == Nat.sub(m, Spec.sum(List.replicate(Nat, 1n+np, Nat.div(m, 1n+np)))) : Nat}:
  +q = Nat.div(m, 1n+np)
  +r = Nat.mod(m, 1n+np)
  %split_base(m, np) : {r == Nat.sub(m, _) : Nat}
  %Equal.sym(Nat, m, Nat.add(r, Nat.mul(q, 1n+np)), euclid(m, np)) : {r == Nat.sub(_, Nat.mul(q, 1n+np)) : Nat}
  %add_comm(Nat.mul(q, 1n+np), r) : {r == Nat.sub(_, Nat.mul(q, 1n+np)) : Nat}
  sub_add_cancel(Nat.mul(q, 1n+np), r)

def Laws.split_sum(m, n, pos):
  match n:
    case 0n:
      match pos:
    case 1n++np:
      +q = Nat.div(m, 1n+np)
      +rep = List.replicate(Nat, 1n+np, q)
      +r = Nat.mod(m, 1n+np)
      # the leftover fits the slots
      fits = le_rw_r(Nat.sub(m, Spec.sum(rep)), 1n+np, List.length(&2, Nat, rep), le_rw_l(r, Nat.sub(m, Spec.sum(rep)), 1n+np, lt_le(r, 1n+np, mod_lt(m, np)), split_leftover(m, np)), Equal.sym(Nat, List.length(&2, Nat, rep), 1n+np, len_rep(1n+np, q)))
      # the base parts do not exceed m
      base = le_rw_l(Nat.mul(q, 1n+np), Spec.sum(rep), m, le_rw_r(Nat.mul(q, 1n+np), Nat.add(r, Nat.mul(q, 1n+np)), m, le_add_l(r, Nat.mul(q, 1n+np)), Equal.sym(Nat, m, Nat.add(r, Nat.mul(q, 1n+np)), euclid(m, np))), split_base(m, np))
      Equal.trans(Nat, Spec.sum(Spec.split.bump(rep, Nat.sub(m, Spec.sum(rep)))), Nat.add(Spec.sum(rep), Nat.sub(m, Spec.sum(rep))), m, sum_bump(rep, Nat.sub(m, Spec.sum(rep)), fits), add_sub(Spec.sum(rep), m, base))

# every part is q or q + 1
def Band(q: Nat, xs: List<&2, Nat>) -> Type:
  match xs:
    case Nil{}:
      Unit
    case h <> t:
      (Spec.LE(q, h) & Spec.LE(h, 1n+q)) & Band(q, t)

def band_rep(n: Nat, +q: Nat) -> Band(q, List.replicate(Nat, n, q)):
  match n:
    case 0n:
      Unit{}
    case 1n+p:
      ((le_refl(q), le_succ(q, q, le_refl(q))), band_rep(p, q))

def band_bump(n: Nat, +q: Nat, l: Nat) -> Band(q, Spec.split.bump(List.replicate(Nat, n, q), l)):
  match n:
    case 0n:
      Unit{}
    case 1n+p:
      match l:
        case 0n:
          ((le_refl(q), le_succ(q, q, le_refl(q))), band_rep(p, q))
        case 1n+k:
          ((le_succ(q, q, le_refl(q)), le_refl(q)), band_bump(p, q, k))

def band_hi(-q: Nat, xs: List<&2, Nat>, i: Nat, b: Band(q, xs)) -> Spec.LE(Spec.at(xs, i), 1n+q):
  match xs:
    case Nil{}:
      Unit{}
    case h <> t:
      match i:
        case 0n:
          (lohi, rest) = b
          (lo, hi) = lohi
          hi
        case 1n+k:
          (lohi, rest) = b
          band_hi(q, t, k, rest)

def band_lo(-q: Nat, xs: List<&2, Nat>, i: Nat, b: Band(q, xs), hi: Spec.LT(i, List.length(&2, Nat, xs))) -> Spec.LE(q, Spec.at(xs, i)):
  match xs:
    case Nil{}:
      match hi:
    case h <> t:
      match i:
        case 0n:
          (lohi, rest) = b
          (lo, up) = lohi
          lo
        case 1n+k:
          (lohi, rest) = b
          band_lo(q, t, k, rest, hi)

def Laws.split_fair(m, n, i, j, hj):
  +q = Nat.div(m, n)
  +rep = List.replicate(Nat, n, q)
  +l = Nat.sub(m, Spec.sum(rep))
  +parts = Spec.split.bump(rep, l)
  hj2 = le_rw_r(1n+j, n, List.length(&2, Nat, parts), hj, Equal.sym(Nat, List.length(&2, Nat, parts), n, Laws.split_count(m, n)))
  top = band_hi(q, parts, i, band_bump(n, q, l))
  low = band_lo(q, parts, j, band_bump(n, q, l), hj2)
  le_rw_r(Spec.at(parts, i), 1n+Spec.at(parts, j), Nat.add(Spec.at(parts, j), 1n), le_trans(Spec.at(parts, i), 1n+q, 1n+Spec.at(parts, j), top, low), add_one(Spec.at(parts, j)))

# 3. Half-up division
# -------------------
# Dart rounds with the quotient q and remainder r of n by d (up when
# 2r >= d); SQL rounds (2n + d) div 2d. half_up_agree shows they agree:
# 2n + d == (2r + d) + q * 2d, and (2r + d) div 2d is 1 exactly when 2r >= d.

# 2 * (r + q * b) + b == (2 * r + b) + q * (2 * b)
def n2_split(+r: Nat, +q: Nat, +b: Nat) -> {Nat.add(Nat.add(Nat.mul(2n, r), b), Nat.mul(q, Nat.mul(2n, b))) == Nat.add(Nat.mul(2n, Nat.add(r, Nat.mul(q, b))), b) : Nat}:
  %mul_dist_l(2n, r, Nat.mul(q, b)) : {Nat.add(Nat.add(Nat.mul(2n, r), b), Nat.mul(q, Nat.mul(2n, b))) == Nat.add(_, b) : Nat}
  %mul_left_comm(q, 2n, b) : {Nat.add(Nat.add(Nat.mul(2n, r), b), Nat.mul(q, Nat.mul(2n, b))) == Nat.add(Nat.add(Nat.mul(2n, r), _), b) : Nat}
  add_right_comm(Nat.mul(2n, r), b, Nat.mul(q, Nat.mul(2n, b)))

# s + 1 * (2 * b) == (b + s) + b
def lin2(+s: Nat, +b: Nat) -> {Nat.add(s, Nat.mul(1n, Nat.mul(2n, b))) == Nat.add(Nat.add(b, s), b) : Nat}:
  %one_mul(Nat.mul(2n, b)) : {Nat.add(s, _) == Nat.add(Nat.add(b, s), b) : Nat}
  %two_mul(b) : {Nat.add(s, _) == Nat.add(Nat.add(b, s), b) : Nat}
  %add_assoc(b, s, b) : {Nat.add(s, Nat.add(b, b)) == _ : Nat}
  add_swap(s, b, b)

# t < 2b and b <= t give (t + b) div (2b) == 1
def round_up_case(+t: Nat, +bp: Nat, ge: Spec.LE(1n+bp, t), lt: Spec.LT(t, Nat.mul(2n, 1n+bp))) -> {1n == Nat.div(Nat.add(t, 1n+bp), Nat.mul(2n, 1n+bp)) : Nat}:
  +s = Nat.sub(t, 1n+bp)
  -xp = Nat.add(bp, Nat.mul(1n, 1n+bp))
  %add_sub(1n+bp, t, ge) : {1n == Nat.div(Nat.add(_, 1n+bp), Nat.mul(2n, 1n+bp)) : Nat}
  %lin2(s, 1n+bp) : {1n == Nat.div(_, Nat.mul(2n, 1n+bp)) : Nat}
  Equal.sym(Nat, Nat.div(Nat.add(s, Nat.mul(1n, Nat.mul(2n, 1n+bp))), Nat.mul(2n, 1n+bp)), 1n, div_unique(1n, s, Nat.add(bp, Nat.mul(1n, 1n+bp)), le_trans(1n+s, 1n+t, Nat.mul(2n, 1n+bp), sub_le(t, 1n+bp), lt)))

# 2 * (1 + k) < 2 * b, for 1 + k < b
def two_lt(+k: Nat, +b: Nat, h: Spec.LT(1n+k, b)) -> Spec.LT(Nat.mul(2n, 1n+k), Nat.mul(2n, b)):
  +t = Nat.mul(2n, 1n+k)
  le_trans(1n+t, 2n+t, Nat.mul(2n, b), le_succ(1n+t, 1n+t, le_refl(1n+t)), le_rw_l(Nat.mul(2n, 2n+k), 2n+t, Nat.mul(2n, b), le_mul_r(2n, 2n+k, b, h), Equal.sym(Nat, Nat.add(2n, t), Nat.mul(2n, 2n+k), mul_succ(2n, 1n+k))))

# the half-up step, decided on the verdict b of 2r >= d
def agree_away(+q: Nat, +k: Nat, +bp: Nat, h: Spec.LT(1n+k, 1n+bp), b: Bool, e: {b == Nat.is_ge(Nat.mul(1n+k, 2n), 1n+bp) : Bool})
  -> {Spec.half_up.away(q, b) == Nat.add(Nat.div(Nat.add(Nat.mul(2n, 1n+k), 1n+bp), Nat.mul(2n, 1n+bp)), q) : Nat}:
  match b:
    case True{}:
      +t = Nat.mul(2n, 1n+k)
      ge = le_rw_r(1n+bp, Nat.mul(1n+k, 2n), t, is_ge_true(Nat.mul(1n+k, 2n), 1n+bp, Equal.sym(Bool, True{}, Nat.is_ge(Nat.mul(1n+k, 2n), 1n+bp), e)), mul_comm(1n+k, 2n))
      %round_up_case(t, bp, ge, two_lt(k, 1n+bp, h)) : {1n+q == Nat.add(_, q) : Nat}
      {==}
    case False{}:
      +t = Nat.mul(2n, 1n+k)
      lt0 = lt_rw_l(Nat.mul(1n+k, 2n), t, 1n+bp, is_ge_false(Nat.mul(1n+k, 2n), 1n+bp, Equal.sym(Bool, False{}, Nat.is_ge(Nat.mul(1n+k, 2n), 1n+bp), e)), mul_comm(1n+k, 2n))
      small = le_rw_r(1n+Nat.add(t, 1n+bp), Nat.add(1n+bp, 1n+bp), Nat.mul(2n, 1n+bp), le_add_mono(1n+t, 1n+bp, 1n+bp, 1n+bp, lt0, le_refl(1n+bp)), two_mul(1n+bp))
      %div_small(Nat.add(t, 1n+bp), Nat.add(bp, Nat.mul(1n, 1n+bp)), small) : {q == Nat.add(_, q) : Nat}
      {==}

# Dart's half-up step on the quotient q and remainder r of n by d agrees
# with (2r + d) div 2d added to q
def agree_rem(+q: Nat, r: Nat, +bp: Nat, h: Spec.LT(r, 1n+bp)) -> {Spec.half_up.rem(q, r, 1n+bp) == Nat.add(Nat.div(Nat.add(Nat.mul(2n, r), 1n+bp), Nat.mul(2n, 1n+bp)), q) : Nat}:
  match r:
    case 0n:
      lt = le_trans(1n+bp, Nat.mul(1n, 1n+bp), Nat.add(bp, Nat.mul(1n, 1n+bp)), le_add_r(1n+bp, 0n), le_add_l(bp, Nat.mul(1n, 1n+bp)))
      %div_small(1n+bp, Nat.add(bp, Nat.mul(1n, 1n+bp)), lt) : {q == Nat.add(_, q) : Nat}
      {==}
    case 1n++k:
      agree_away(q, k, bp, h, Nat.is_ge(Nat.mul(1n+k, 2n), 1n+bp), {==})

# Dart's divideRounded(n, d, halfUp) == SQL round(n / d, 0), for d == 1n+bp
def half_up_agree(+n: Nat, +bp: Nat) -> {Spec.half_up(n, 1n+bp) == Spec.round_half(n, 1n+bp) : Nat}:
  +q = Nat.div(n, 1n+bp)
  +r = Nat.mod(n, 1n+bp)
  -xp = Nat.add(bp, Nat.mul(1n, 1n+bp))
  %Equal.sym(Nat, n, Nat.add(r, Nat.mul(q, 1n+bp)), euclid(n, bp)) : {Spec.half_up.rem(q, r, 1n+bp) == Nat.div(Nat.add(Nat.mul(2n, _), 1n+bp), Nat.mul(2n, 1n+bp)) : Nat}
  %n2_split(r, q, 1n+bp) : {Spec.half_up.rem(q, r, 1n+bp) == Nat.div(_, Nat.mul(2n, 1n+bp)) : Nat}
  %div_shift(Nat.add(Nat.mul(2n, r), 1n+bp), q, Nat.add(bp, Nat.mul(1n, 1n+bp))) : {Spec.half_up.rem(q, r, 1n+bp) == _ : Nat}
  agree_rem(q, r, bp, mod_lt(n, bp))

def Laws.half_up_agrees(n, d, pos):
  match d:
    case 0n:
      match pos:
    case 1n+bp:
      half_up_agree(n, bp)

def Laws.round_half_lower(a, b):
  match b:
    case 0n:
      Unit{}
    case 1n++bp:
      +nn = Nat.add(Nat.mul(2n, a), 1n+bp)
      +dd = Nat.mul(2n, 1n+bp)
      +xp = Nat.add(bp, Nat.mul(1n, 1n+bp))
      +q = Nat.div(nn, dd)
      +r = Nat.mod(nn, dd)
      le_rw_l(Nat.mul(q, dd), Nat.mul(dd, q), nn, le_rw_r(Nat.mul(q, dd), Nat.add(r, Nat.mul(q, dd)), nn, le_add_l(r, Nat.mul(q, dd)), Equal.sym(Nat, nn, Nat.add(r, Nat.mul(q, dd)), euclid(nn, xp))), mul_comm(q, dd))

def Laws.round_half_upper(a, b, pos):
  match b:
    case 0n:
      match pos:
    case 1n++bp:
      +nn = Nat.add(Nat.mul(2n, a), 1n+bp)
      +dd = Nat.mul(2n, 1n+bp)
      +xp = Nat.add(bp, Nat.mul(1n, 1n+bp))
      +q = Nat.div(nn, dd)
      +r = Nat.mod(nn, dd)
      below = le_add_mono(1n+r, dd, Nat.mul(q, dd), Nat.mul(q, dd), mod_lt(nn, xp), le_refl(Nat.mul(q, dd)))
      lt1 = lt_rw_l(Nat.add(r, Nat.mul(q, dd)), nn, Nat.mul(1n+q, dd), below, Equal.sym(Nat, nn, Nat.add(r, Nat.mul(q, dd)), euclid(nn, xp)))
      lt2 = le_rw_r(1n+nn, Nat.mul(1n+q, dd), Nat.mul(dd, 1n+q), lt1, mul_comm(1n+q, dd))
      %add_one(q) : Spec.LT(nn, Nat.mul(dd, _))
      lt2

# half-up division is monotone in the dividend
def half_up_mono(+x: Nat, +y: Nat, +bp: Nat, h: Spec.LE(x, y)) -> Spec.LE(Spec.half_up(x, 1n+bp), Spec.half_up(y, 1n+bp)):
  +xp = Nat.add(bp, Nat.mul(1n, 1n+bp))
  core = div_mono(Nat.add(Nat.mul(2n, x), 1n+bp), Nat.add(Nat.mul(2n, y), 1n+bp), xp, le_add_mono(Nat.mul(2n, x), Nat.mul(2n, y), 1n+bp, 1n+bp, le_mul_r(2n, x, y, h), le_refl(1n+bp)))
  le_rw_l(Spec.round_half(x, 1n+bp), Spec.half_up(x, 1n+bp), Spec.half_up(y, 1n+bp), le_rw_r(Spec.round_half(x, 1n+bp), Spec.round_half(y, 1n+bp), Spec.half_up(y, 1n+bp), core, Equal.sym(Nat, Spec.half_up(y, 1n+bp), Spec.round_half(y, 1n+bp), half_up_agree(y, bp))), Equal.sym(Nat, Spec.half_up(x, 1n+bp), Spec.round_half(x, 1n+bp), half_up_agree(x, bp)))


# Rounding to whole rupees
# ------------------------

# a whole number of rupees rounds to itself
def round_whole(+c: Nat) -> {Nat.mul(c, 100n) == Spec.round_to_rupee(Nat.mul(c, 100n)) : Nat}:
  %Equal.sym(Nat, Spec.half_up(Nat.mul(c, 100n), 100n), Spec.round_half(Nat.mul(c, 100n), 100n), half_up_agree(Nat.mul(c, 100n), 99n)) : {Nat.mul(c, 100n) == Nat.mul(_, 100n) : Nat}
  %mul_left_comm(c, 2n, 100n) : {Nat.mul(c, 100n) == Nat.mul(Nat.div(Nat.add(_, 100n), Nat.mul(2n, 100n)), 100n) : Nat}
  %add_comm(100n, Nat.mul(c, Nat.mul(2n, 100n))) : {Nat.mul(c, 100n) == Nat.mul(Nat.div(_, Nat.mul(2n, 100n)), 100n) : Nat}
  %Equal.sym(Nat, Nat.div(Nat.add(100n, Nat.mul(c, 200n)), 200n), c, div_unique(c, 100n, 199n, Unit{})) : {Nat.mul(c, 100n) == Nat.mul(_, 100n) : Nat}
  {==}

# rounding to whole rupees is monotone
def round_mono(+x: Nat, +y: Nat, h: Spec.LE(x, y)) -> Spec.LE(Spec.round_to_rupee(x), Spec.round_to_rupee(y)):
  le_mul_l(Spec.half_up(x, 100n), Spec.half_up(y, 100n), 100n, half_up_mono(x, y, 99n, h))

# Proration
# ---------
# A partial month bills min(rent, B), B = half_up(rent * days, len * 100)
# * 100 paisa. With b = len * 100 and q = (2a + b) div 2b for a = rent *
# days, round_half_lower and round_half_upper put a within b / 2 of b * q,
# which is len * B. Multiplying out by 2 and cancelling gives the bounds.

def Laws.prorate_full_month(rent, len):
  %is_eq_refl(len) : {Spec.prorated_rent.full(rent, len, len, _) == rent : Nat}
  {==}

def Laws.prorate_no_days(rent, len, pos):
  match len:
    case 0n:
      match pos:
    case 1n+lp:
      {==}

# the partial-month branch never exceeds the rent
def some_le_rent(+rent: Nat, days: Nat, +len: Nat) -> Spec.LE(Spec.prorated_rent.some(rent, days, len), rent):
  match days:
    case 0n:
      Unit{}
    case 1n+k:
      min_le_l(rent, Spec.multiply_to_rupee(rent, 1n+k, len))

def prorate_le.go(+rent: Nat, +days: Nat, +len: Nat, b: Bool) -> Spec.LE(Spec.prorated_rent.full(rent, days, len, b), rent):
  match b:
    case True{}:
      le_refl(rent)
    case False{}:
      some_le_rent(rent, days, len)

def Laws.prorate_le_rent(rent, days, len):
  prorate_le.go(rent, days, len, Nat.is_eq(days, len))

def false_true(e: {False{} == True{} : Bool}) -> Empty:
  %e : BD(_, Empty, Unit)
  Unit{}

def is_eq_true(a: Nat, b: Nat, e: {Nat.is_eq(a, b) == True{} : Bool}) -> {a == b : Nat}:
  match a b:
    case 0n 0n:
      {==}
    case 0n 1n+b1:
      Empty.absurd({0n == 1n+b1 : Nat}, false_true(e))
    case 1n+a1 0n:
      Empty.absurd({1n+a1 == 0n : Nat}, false_true(e))
    case 1n+a1 1n+b1:
      %is_eq_true(a1, b1, e) : {1n+a1 == 1n+_ : Nat}
      {==}

# 2b * q == 2 * (l * (q * 100)), for b = l * 100
def two_bq(+l: Nat, +q: Nat) -> {Nat.mul(Nat.mul(2n, Nat.mul(l, 100n)), q) == Nat.mul(2n, Nat.mul(l, Nat.mul(q, 100n))) : Nat}:
  +b = Nat.mul(l, 100n)
  bq = Equal.trans(Nat, Nat.mul(b, q), Nat.mul(l, Nat.mul(100n, q)), Nat.mul(l, Nat.mul(q, 100n)), Equal.sym(Nat, Nat.mul(l, Nat.mul(100n, q)), Nat.mul(b, q), mul_assoc(l, 100n, q)), Equal.cong(Nat, Nat, x => Nat.mul(l, x), Nat.mul(100n, q), Nat.mul(q, 100n), mul_comm(100n, q)))
  Equal.trans(Nat, Nat.mul(Nat.mul(2n, b), q), Nat.mul(2n, Nat.mul(b, q)), Nat.mul(2n, Nat.mul(l, Nat.mul(q, 100n))), Equal.sym(Nat, Nat.mul(2n, Nat.mul(b, q)), Nat.mul(Nat.mul(2n, b), q), mul_assoc(2n, b, q)), Equal.cong(Nat, Nat, x => Nat.mul(2n, x), Nat.mul(b, q), Nat.mul(l, Nat.mul(q, 100n)), bq))

# l * 100 == 2 * (50 * l)
def b_half(+l: Nat) -> {Nat.mul(l, 100n) == Nat.mul(2n, Nat.mul(50n, l)) : Nat}:
  Equal.sym(Nat, Nat.mul(2n, Nat.mul(50n, l)), Nat.mul(l, 100n), Equal.trans(Nat, Nat.mul(2n, Nat.mul(50n, l)), Nat.mul(100n, l), Nat.mul(l, 100n), mul_assoc(2n, 50n, l), mul_comm(100n, l)))

# l * B <= a + 50 * l, for B = half_up(a, l * 100) * 100 and l = 1n+lp
def mtr_upper(+a: Nat, +lp: Nat) -> Spec.LE(Nat.mul(1n+lp, Nat.mul(Spec.half_up(a, Nat.mul(1n+lp, 100n)), 100n)), Nat.add(a, Nat.mul(50n, 1n+lp))):
  +l = {1n+lp : Nat}
  +b = Nat.mul(l, 100n)
  +q = Spec.round_half(a, b)
  +x = Nat.mul(l, Nat.mul(q, 100n))
  +y = Nat.add(a, Nat.mul(50n, l))
  h1 = Laws.round_half_lower(a, b)
  er = Equal.trans(Nat, Nat.add(Nat.mul(2n, a), b), Nat.add(Nat.mul(2n, a), Nat.mul(2n, Nat.mul(50n, l))), Nat.mul(2n, y), Equal.cong(Nat, Nat, z => Nat.add(Nat.mul(2n, a), z), b, Nat.mul(2n, Nat.mul(50n, l)), b_half(l)), mul_dist_l(2n, a, Nat.mul(50n, l)))
  h2 = le_rw_r(Nat.mul(2n, x), Nat.add(Nat.mul(2n, a), b), Nat.mul(2n, y), le_rw_l(Nat.mul(Nat.mul(2n, b), q), Nat.mul(2n, x), Nat.add(Nat.mul(2n, a), b), h1, two_bq(l, q)), er)
  %Equal.sym(Nat, Spec.half_up(a, b), q, half_up_agree(a, Nat.add(99n, Nat.mul(lp, 100n)))) : Spec.LE(Nat.mul(l, Nat.mul(_, 100n)), y)
  le_mul_cancel(1n, x, y, h2)

def upper_some(+rent: Nat, days: Nat, +len: Nat) -> Spec.LE(Nat.mul(len, Spec.prorated_rent.some(rent, days, len)), Nat.add(Nat.mul(rent, days), Nat.mul(50n, len))):
  match days:
    case 0n:
      le_rw_l(0n, Nat.mul(len, 0n), Nat.add(Nat.mul(rent, 0n), Nat.mul(50n, len)), Unit{}, Equal.sym(Nat, Nat.mul(len, 0n), 0n, mul_zero(len)))
    case 1n++k:
      match len:
        case 0n:
          Unit{}
        case 1n+lp:
          +a = Nat.mul(rent, 1n+k)
          +bb = Spec.multiply_to_rupee(rent, 1n+k, 1n+lp)
          le_trans(Nat.mul(1n+lp, Nat.min(rent, bb)), Nat.mul(1n+lp, bb), Nat.add(a, Nat.mul(50n, 1n+lp)), le_mul_r(1n+lp, Nat.min(rent, bb), bb, min_le_r(rent, bb)), mtr_upper(a, lp))

def prorate_upper.go(+rent: Nat, +days: Nat, +len: Nat, b: Bool, e: {b == Nat.is_eq(days, len) : Bool})
  -> Spec.LE(Nat.mul(len, Spec.prorated_rent.full(rent, days, len, b)), Nat.add(Nat.mul(rent, days), Nat.mul(50n, len))):
  match b:
    case True{}:
      dl = is_eq_true(days, len, Equal.sym(Bool, True{}, Nat.is_eq(days, len), e))
      eq = Equal.trans(Nat, Nat.mul(len, rent), Nat.mul(rent, len), Nat.mul(rent, days), mul_comm(len, rent), Equal.cong(Nat, Nat, z => Nat.mul(rent, z), len, days, Equal.sym(Nat, days, len, dl)))
      le_rw_l(Nat.mul(rent, days), Nat.mul(len, rent), Nat.add(Nat.mul(rent, days), Nat.mul(50n, len)), le_add_r(Nat.mul(rent, days), Nat.mul(50n, len)), Equal.sym(Nat, Nat.mul(len, rent), Nat.mul(rent, days), eq))
    case False{}:
      upper_some(rent, days, len)

def Laws.prorate_near_exact_upper(rent, days, len):
  prorate_upper.go(rent, days, len, Nat.is_eq(days, len), {==})

# c + a <= c + b gives a <= b
def le_add_cancel(c: Nat, -a: Nat, -b: Nat, h: Spec.LE(Nat.add(c, a), Nat.add(c, b))) -> Spec.LE(a, b):
  match c:
    case 0n:
      h
    case 1n+p:
      le_add_cancel(p, a, b, h)

# 2a + b < 2b * (q + 1) gives 2a <= 2b * q + b
def lower_core(+a: Nat, +b: Nat, +q: Nat, h: Spec.LT(Nat.add(Nat.mul(2n, a), b), Nat.mul(Nat.mul(2n, b), Nat.add(q, 1n)))) -> Spec.LE(Nat.mul(2n, a), Nat.add(Nat.mul(Nat.mul(2n, b), q), b)):
  +m = Nat.mul(Nat.mul(2n, b), q)
  +ta = Nat.mul(2n, a)
  # 2b * (q + 1) == b + (m + b)
  e1 = Equal.trans(Nat, Nat.mul(Nat.mul(2n, b), Nat.add(q, 1n)), Nat.mul(Nat.mul(2n, b), 1n+q), Nat.add(Nat.mul(2n, b), m), Equal.cong(Nat, Nat, z => Nat.mul(Nat.mul(2n, b), z), Nat.add(q, 1n), 1n+q, Equal.sym(Nat, 1n+q, Nat.add(q, 1n), add_one(q))), Equal.sym(Nat, Nat.add(Nat.mul(2n, b), m), Nat.mul(Nat.mul(2n, b), 1n+q), mul_succ(Nat.mul(2n, b), q)))
  e2 = Equal.trans(Nat, Nat.add(Nat.mul(2n, b), m), Nat.add(Nat.add(b, b), m), Nat.add(b, Nat.add(b, m)), Equal.cong(Nat, Nat, z => Nat.add(z, m), Nat.mul(2n, b), Nat.add(b, b), Equal.sym(Nat, Nat.add(b, b), Nat.mul(2n, b), two_mul(b))), Equal.sym(Nat, Nat.add(b, Nat.add(b, m)), Nat.add(Nat.add(b, b), m), add_assoc(b, b, m)))
  e3 = Equal.cong(Nat, Nat, z => Nat.add(b, z), Nat.add(b, m), Nat.add(m, b), add_comm(b, m))
  hr = le_rw_r(1n+Nat.add(ta, b), Nat.mul(Nat.mul(2n, b), Nat.add(q, 1n)), Nat.add(b, Nat.add(m, b)), h, Equal.trans(Nat, Nat.mul(Nat.mul(2n, b), Nat.add(q, 1n)), Nat.add(b, Nat.add(b, m)), Nat.add(b, Nat.add(m, b)), Equal.trans(Nat, Nat.mul(Nat.mul(2n, b), Nat.add(q, 1n)), Nat.add(Nat.mul(2n, b), m), Nat.add(b, Nat.add(b, m)), e1, e2), e3))
  hl = le_rw_l(Nat.add(ta, b), Nat.add(b, ta), Nat.add(b, Nat.add(m, b)), lt_le(Nat.add(ta, b), Nat.add(b, Nat.add(m, b)), hr), add_comm(ta, b))
  le_add_cancel(b, ta, Nat.add(m, b), hl)

# a <= l * (B + 50), for B = half_up(a, l * 100) * 100 and l = 1n+lp
def mtr_lower(+a: Nat, +lp: Nat) -> Spec.LE(a, Nat.mul(1n+lp, Nat.add(Nat.mul(Spec.half_up(a, Nat.mul(1n+lp, 100n)), 100n), 50n))):
  +l = {1n+lp : Nat}
  +b = Nat.mul(l, 100n)
  +q = Spec.round_half(a, b)
  +x = Nat.mul(l, Nat.mul(q, 100n))
  +y = Nat.mul(l, Nat.add(Nat.mul(q, 100n), 50n))
  h1 = lower_core(a, b, q, Laws.round_half_upper(a, b, Unit{}))
  # 2 * y == 2b * q + b
  ey1 = Equal.cong(Nat, Nat, z => Nat.mul(2n, z), y, Nat.add(x, Nat.mul(l, 50n)), Equal.sym(Nat, Nat.add(x, Nat.mul(l, 50n)), y, mul_dist_l(l, Nat.mul(q, 100n), 50n)))
  ey2 = Equal.sym(Nat, Nat.add(Nat.mul(2n, x), Nat.mul(2n, Nat.mul(l, 50n))), Nat.mul(2n, Nat.add(x, Nat.mul(l, 50n))), mul_dist_l(2n, x, Nat.mul(l, 50n)))
  ey3 = Equal.cong(Nat, Nat, z => Nat.add(z, Nat.mul(2n, Nat.mul(l, 50n))), Nat.mul(2n, x), Nat.mul(Nat.mul(2n, b), q), Equal.sym(Nat, Nat.mul(Nat.mul(2n, b), q), Nat.mul(2n, x), two_bq(l, q)))
  ey4 = Equal.cong(Nat, Nat, z => Nat.add(Nat.mul(Nat.mul(2n, b), q), z), Nat.mul(2n, Nat.mul(l, 50n)), b, mul_left_comm(2n, l, 50n))
  ey = Equal.trans(Nat, Nat.mul(2n, y), Nat.add(Nat.mul(2n, x), Nat.mul(2n, Nat.mul(l, 50n))), Nat.add(Nat.mul(Nat.mul(2n, b), q), b), Equal.trans(Nat, Nat.mul(2n, y), Nat.mul(2n, Nat.add(x, Nat.mul(l, 50n))), Nat.add(Nat.mul(2n, x), Nat.mul(2n, Nat.mul(l, 50n))), ey1, ey2), Equal.trans(Nat, Nat.add(Nat.mul(2n, x), Nat.mul(2n, Nat.mul(l, 50n))), Nat.add(Nat.mul(Nat.mul(2n, b), q), Nat.mul(2n, Nat.mul(l, 50n))), Nat.add(Nat.mul(Nat.mul(2n, b), q), b), ey3, ey4))
  h2 = le_rw_r(Nat.mul(2n, a), Nat.add(Nat.mul(Nat.mul(2n, b), q), b), Nat.mul(2n, y), h1, Equal.sym(Nat, Nat.mul(2n, y), Nat.add(Nat.mul(Nat.mul(2n, b), q), b), ey))
  %Equal.sym(Nat, Spec.half_up(a, b), q, half_up_agree(a, Nat.add(99n, Nat.mul(lp, 100n)))) : Spec.LE(a, Nat.mul(l, Nat.add(Nat.mul(_, 100n), 50n)))
  le_mul_cancel(1n, a, y, h2)

# rent * days <= len * (rent + 50), for days <= len
def rent_lower(+rent: Nat, +days: Nat, +len: Nat, part: Spec.LE(days, len)) -> Spec.LE(Nat.mul(rent, days), Nat.mul(len, Nat.add(rent, 50n))):
  full = le_rw_r(Nat.mul(rent, days), Nat.mul(rent, len), Nat.mul(len, rent), le_mul_r(rent, days, len, part), mul_comm(rent, len))
  le_trans(Nat.mul(rent, days), Nat.mul(len, rent), Nat.mul(len, Nat.add(rent, 50n)), full, le_mul_r(len, rent, Nat.add(rent, 50n), le_add_r(rent, 50n)))

# a bound on both sides of a min is a bound on the min
def le_min_case(-x: Nat, -l: Nat, +a: Nat, +b: Nat, ha: Spec.LE(x, Nat.mul(l, Nat.add(a, 50n))), hb: Spec.LE(x, Nat.mul(l, Nat.add(b, 50n))), c: Or(Spec.LE(a, b), Spec.LT(b, a)))
  -> Spec.LE(x, Nat.mul(l, Nat.add(Nat.min(a, b), 50n))):
  match c:
    case Inl{e}:
      %Equal.sym(Nat, Nat.min(a, b), a, min_l_of_le(a, b, e)) : Spec.LE(x, Nat.mul(l, Nat.add(_, 50n)))
      ha
    case Inr{e}:
      %Equal.sym(Nat, Nat.min(a, b), b, min_r_of_le(a, b, lt_le(b, a, e))) : Spec.LE(x, Nat.mul(l, Nat.add(_, 50n)))
      hb

def lower_some(+rent: Nat, days: Nat, +len: Nat, part: Spec.LE(days, len)) -> Spec.LE(Nat.mul(rent, days), Nat.mul(len, Nat.add(Spec.prorated_rent.some(rent, days, len), 50n))):
  match days:
    case 0n:
      le_rw_l(0n, Nat.mul(rent, 0n), Nat.mul(len, Nat.add(0n, 50n)), Unit{}, Equal.sym(Nat, Nat.mul(rent, 0n), 0n, mul_zero(rent)))
    case 1n++k:
      match len:
        case 0n:
          match part:
        case 1n+lp:
          +a = Nat.mul(rent, 1n+k)
          +bb = Spec.multiply_to_rupee(rent, 1n+k, 1n+lp)
          le_min_case(a, 1n+lp, rent, bb, rent_lower(rent, 1n+k, 1n+lp, part), mtr_lower(a, lp), le_or_gt(rent, bb))

def prorate_lower.go(+rent: Nat, +days: Nat, +len: Nat, +part: Spec.LE(days, len), b: Bool)
  -> Spec.LE(Nat.mul(rent, days), Nat.mul(len, Nat.add(Spec.prorated_rent.full(rent, days, len, b), 50n))):
  match b:
    case True{}:
      rent_lower(rent, days, len, part)
    case False{}:
      lower_some(rent, days, len, part)

def Laws.prorate_near_exact_lower(rent, days, len, part):
  prorate_lower.go(rent, days, len, part, Nat.is_eq(days, len))

def Laws.prorate_paisa_rent_capped():
  {==}

def Laws.prorate_sql_matches_dart(rent, start, dim, from, upto):
  match start:
    case 0n:
      match from:
    case 1n+s:
      match s:
        case 0n:
          match dim:
            case 0n:
              match upto:
            case 1n++dp:
              %sub_zero(dp) : {rent == Spec.prorated_rent(rent, Nat.add(_, 1n), 1n+dp) : Nat}
              %add_one(dp) : {rent == Spec.prorated_rent(rent, _, 1n+dp) : Nat}
              Equal.sym(Nat, Spec.prorated_rent(rent, 1n+dp, 1n+dp), rent, Laws.prorate_full_month(rent, 1n+dp))
        case 1n++s2:
          match dim:
            case 0n:
              match upto:
            case 1n+d1:
              match d1:
                case 0n:
                  match upto:
                case 1n++dp:
                  +x = Nat.sub(dp, s2)
                  +n = Nat.mul(rent, 1n+x)
                  %add_one(x) : {Nat.min(rent, Nat.mul(Spec.round_half(Nat.mul(rent, _), Nat.mul(2n+dp, 100n)), 100n)) == Spec.prorated_rent(rent, _, 2n+dp) : Nat}
                  %is_eq_lt(1n+x, 2n+dp, sub_le(dp, s2)) : {Nat.min(rent, Nat.mul(Spec.round_half(n, Nat.mul(2n+dp, 100n)), 100n)) == Spec.prorated_rent.full(rent, 1n+x, 2n+dp, _) : Nat}
                  %half_up_agree(n, Nat.add(99n, Nat.mul(1n+dp, 100n))) : {Nat.min(rent, Nat.mul(_, 100n)) == Nat.min(rent, Nat.mul(Spec.half_up(n, Nat.mul(2n+dp, 100n)), 100n)) : Nat}
                  {==}

# Billing
# -------

def Laws.billed_rent_matches_ledger(rent, prorate, first, start, dim, from, upto):
  match prorate:
    case False{}:
      match first:
        case True{}:
          {==}
        case False{}:
          {==}
    case True{}:
      match first:
        case True{}:
          Equal.sym(Nat, Spec.prorated_rent_sql(rent, True{}, start, dim), Spec.prorated_rent(rent, Nat.add(Nat.sub(dim, start), 1n), dim), Laws.prorate_sql_matches_dart(rent, start, dim, from, upto))
        case False{}:
          {==}

def Laws.billed_rent_before_start(rent, prorate, first, start, dim):
  {==}

# with prorate_first_month set, sync_lease_billing's case is app.prorated_rent
def Laws.billed_first_month_matches_dart(rent, start, dim, from, upto):
  Laws.prorate_sql_matches_dart(rent, start, dim, from, upto)

def Laws.billed_later_month_full(rent, prorate, start, dim):
  match prorate:
    case True{}:
      {==}
    case False{}:
      {==}

# 4. Daily late fee
# -----------------

def Laws.late_fee_nothing_overdue(rate, cap, days, grace, top):
  {==}

def Laws.late_fee_in_grace(rate, cap, overdue, days, grace, top, within):
  match overdue:
    case 0n:
      {==}
    case 1n+o:
      %is_le_of_le(days, grace, within) : {Spec.daily_late_fee.late(rate, cap, days, top, _) == 0n : Nat}
      {==}

# capFee is monotone
def cap_mono(cap: Maybe<&2, Nat>, +x: Nat, +y: Nat, h: Spec.LE(x, y)) -> Spec.LE(Spec.cap_fee(cap, x), Spec.cap_fee(cap, y)):
  match cap:
    case None{}:
      h
    case Some{c}:
      min_mono(x, y, c, h)

# past the grace period, the fee is monotone in the days late
def late_fee_mono(+rate: Nat, +cap: Maybe<&2, Nat>, +d1: Nat, +d2: Nat, +top: Nat, h: Spec.LE(d1, d2))
  -> Spec.LE(Nat.min(Spec.cap_fee(cap, Spec.round_to_rupee(Spec.daily_fee(rate, d1, top))), top), Nat.min(Spec.cap_fee(cap, Spec.round_to_rupee(Spec.daily_fee(rate, d2, top))), top)):
  +f1 = Spec.daily_fee(rate, d1, top)
  +f2 = Spec.daily_fee(rate, d2, top)
  m2 = min_mono(Nat.mul(rate, d1), Nat.mul(rate, d2), top, le_mul_r(rate, d1, d2, h))
  m3 = round_mono(f1, f2, m2)
  m4 = cap_mono(cap, Spec.round_to_rupee(f1), Spec.round_to_rupee(f2), m3)
  min_mono(Spec.cap_fee(cap, Spec.round_to_rupee(f1)), Spec.cap_fee(cap, Spec.round_to_rupee(f2)), top, m4)

# both verdicts of daysLate <= graceDays, with their evidence
def late_mono.go(+rate: Nat, +cap: Maybe<&2, Nat>, +d1: Nat, +d2: Nat, +grace: Nat, +top: Nat, later: Spec.LE(d1, d2),
  b1: Bool, e1: {b1 == Nat.is_le(d1, grace) : Bool}, b2: Bool, e2: {b2 == Nat.is_le(d2, grace) : Bool})
  -> Spec.LE(Spec.daily_late_fee.late(rate, cap, d1, top, b1), Spec.daily_late_fee.late(rate, cap, d2, top, b2)):
  match b1 b2:
    case True{} _:
      Unit{}
    case False{} True{}:
      past = is_le_false(d1, grace, Equal.sym(Bool, False{}, Nat.is_le(d1, grace), e1))
      inside = is_le_true(d2, grace, Equal.sym(Bool, True{}, Nat.is_le(d2, grace), e2))
      Empty.absurd(Spec.LE(Nat.min(Spec.cap_fee(cap, Spec.round_to_rupee(Spec.daily_fee(rate, d1, top))), top), 0n), lt_irrefl(grace, le_trans(1n+grace, d1, grace, past, le_trans(d1, d2, grace, later, inside))))
    case False{} False{}:
      late_fee_mono(rate, cap, d1, d2, top, later)

def Laws.late_fee_monotone(rate, cap, overdue, d1, d2, grace, top, later):
  match overdue:
    case 0n:
      Unit{}
    case 1n+o:
      late_mono.go(rate, cap, d1, d2, grace, top, later, Nat.is_le(d1, grace), {==}, Nat.is_le(d2, grace), {==})

def late_cap.go(+rate: Nat, +cap: Nat, +days: Nat, +top: Nat, within: Bool) -> Spec.LE(Spec.daily_late_fee.late(rate, Some{cap}, days, top, within), cap):
  match within:
    case True{}:
      Unit{}
    case False{}:
      +r = Spec.round_to_rupee(Spec.daily_fee(rate, days, top))
      le_trans(Nat.min(Nat.min(r, cap), top), Nat.min(r, cap), cap, min_le_l(Nat.min(r, cap), top), min_le_r(r, cap))

def Laws.late_fee_le_cap(rate, cap, overdue, days, grace, top):
  match overdue:
    case 0n:
      Unit{}
    case 1n+o:
      late_cap.go(rate, cap, days, top, Nat.is_le(days, grace))

def late_max.go(+rate: Nat, cap: Maybe<&2, Nat>, +days: Nat, +top: Nat, within: Bool) -> Spec.LE(Spec.daily_late_fee.late(rate, cap, days, top, within), top):
  match within:
    case True{}:
      Unit{}
    case False{}:
      min_le_r(Spec.cap_fee(cap, Spec.round_to_rupee(Spec.daily_fee(rate, days, top))), top)

def Laws.late_fee_le_max(rate, cap, overdue, days, grace, top):
  match overdue:
    case 0n:
      Unit{}
    case 1n+o:
      late_max.go(rate, cap, days, top, Nat.is_le(days, grace))

def Laws.late_fee_paisa_cap_capped(k):
  {==}

# SQL against Dart past the grace period, for t = k * 100. When x <= t the
# clamp to maxFee does nothing; when x > t both sides come to
# min(min(t, cap), t), because a whole-rupee t rounds to itself.
def fee_agree.cap(rx: Nat, cap: Maybe<&2, Nat>, +t: Nat)
  -> {Nat.min(Nat.min(rx, Spec.daily_late_fee_sql.cap(cap, t)), t) == Nat.min(Spec.cap_fee(cap, rx), t) : Nat}:
  match cap:
    case None{}:
      min_idem(rx, t)
    case Some{c}:
      {==}

def fee_agree.big(rx: Nat, cap: Maybe<&2, Nat>, +t: Nat, h: Spec.LE(t, rx))
  -> {Nat.min(Nat.min(rx, Spec.daily_late_fee_sql.cap(cap, t)), t) == Nat.min(Spec.cap_fee(cap, t), t) : Nat}:
  match cap:
    case None{}:
      %Equal.sym(Nat, Nat.min(rx, t), t, min_r_of_le(rx, t, h)) : {Nat.min(_, t) == Nat.min(t, t) : Nat}
      {==}
    case Some{c}:
      min_absorb(t, rx, c, h)

def fee_agree.go(+x: Nat, +cap: Maybe<&2, Nat>, +k: Nat, c: Or(Spec.LE(x, Nat.mul(k, 100n)), Spec.LT(Nat.mul(k, 100n), x)))
  -> {Nat.min(Nat.min(Spec.round_to_rupee(x), Spec.daily_late_fee_sql.cap(cap, Nat.mul(k, 100n))), Nat.mul(k, 100n)) == Nat.min(Spec.cap_fee(cap, Spec.round_to_rupee(Nat.min(x, Nat.mul(k, 100n)))), Nat.mul(k, 100n)) : Nat}:
  match c:
    case Inl{e}:
      +t = Nat.mul(k, 100n)
      %Equal.sym(Nat, Nat.min(x, t), x, min_l_of_le(x, t, e)) : {Nat.min(Nat.min(Spec.round_to_rupee(x), Spec.daily_late_fee_sql.cap(cap, t)), t) == Nat.min(Spec.cap_fee(cap, Spec.round_to_rupee(_)), t) : Nat}
      fee_agree.cap(Spec.round_to_rupee(x), cap, t)
    case Inr{e}:
      +t = Nat.mul(k, 100n)
      +tx = lt_le(t, x, e)
      big = le_rw_l(Spec.round_to_rupee(t), t, Spec.round_to_rupee(x), round_mono(t, x, tx), Equal.sym(Nat, t, Spec.round_to_rupee(t), round_whole(k)))
      %Equal.sym(Nat, Nat.min(x, t), t, min_r_of_le(x, t, tx)) : {Nat.min(Nat.min(Spec.round_to_rupee(x), Spec.daily_late_fee_sql.cap(cap, t)), t) == Nat.min(Spec.cap_fee(cap, Spec.round_to_rupee(_)), t) : Nat}
      %round_whole(k) : {Nat.min(Nat.min(Spec.round_to_rupee(x), Spec.daily_late_fee_sql.cap(cap, t)), t) == Nat.min(Spec.cap_fee(cap, _), t) : Nat}
      fee_agree.big(Spec.round_to_rupee(x), cap, t, big)

def late_sql.go(+rate: Nat, +cap: Maybe<&2, Nat>, +days: Nat, +k: Nat, within: Bool)
  -> {Spec.daily_late_fee_sql.late(rate, cap, days, Nat.mul(k, 100n), within) == Spec.daily_late_fee.late(rate, cap, days, Nat.mul(k, 100n), within) : Nat}:
  match within:
    case True{}:
      {==}
    case False{}:
      +x = Nat.mul(rate, days)
      +t = Nat.mul(k, 100n)
      %half_up_agree(x, 99n) : {Nat.min(Nat.min(Nat.mul(_, 100n), Spec.daily_late_fee_sql.cap(cap, t)), t) == Spec.daily_late_fee.late(rate, cap, days, t, False{}) : Nat}
      fee_agree.go(x, cap, k, le_or_gt(x, t))

def Laws.late_fee_sql_matches_dart(rate, cap, overdue, days, grace, k):
  match overdue:
    case 0n:
      {==}
    case 1n+o:
      late_sql.go(rate, cap, days, k, Nat.is_le(days, grace))
