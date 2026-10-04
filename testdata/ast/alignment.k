# Every AST node shape the language bindings model, in one file.
#
# Each binding's alignment test parses this fixture through the real parser
# and asserts the resulting `ast_json` against `alignment.json`, the golden
# capture next to it. The point is to pin the *wire contract* — which nodes
# carry a `type` discriminator, what the `Type` enum actually serializes to,
# and whether serde flattens a newtype variant's fields — because those are
# the details that are easiest to get wrong and that fail silently (an
# unknown tag decodes to null rather than throwing).
#
# Keep it syntactically valid. A diagnostic here means the fixture is wrong,
# not the binding. The `data/cloud` and `foo/bar` packages next to this file
# exist so the imports resolve; see `README.md` for how to regenerate
# `alignment.json`.

import data.cloud
import foo.bar as fb

# --- Type variants -------------------------------------------------------
type TAny = any
type TBasic = str
type TList = [int]
type TDict = {str: int}
type TUnion = int | str
type TFunc = (int, str) -> bool
type TNamed = Cloud
type TLitInt = 1
type TLitStr = "s"
type TLitBool = True
type TLitFloat = 1.5

schema Person:
    """A person."""

    @deprecated
    @info(kwargs = {"tag": "v"})
    name: str = "anonymous"

    age?: int = 0

    check:
        age >= 0, "age must be non-negative"
        age < 200 if age, "age must be a sane number"

# A schema with an index signature exercises `SchemaIndexSignature`. Note the
# signature is a statement in the schema *body*, not part of the `schema`
# header — `schema Bag[k: str]` is a generic schema with an `args` list.
schema Bag:
    [k: str]: int = 0

# --- Schema instantiation, config, keyword and positional args -----------
x = Person {name = "Alice", age = 30}
y = Person(1, name = "Bob")
z = fb
u: Person {name = "Carol"}

# --- Rules ---------------------------------------------------------------
rule R:
    a > 0, "a must be positive"

# --- Assignment, aug-assign, unification, assert, if --------------------
a = 1
a += 2
a: int = 3
# Member and index paths on an assignment target.
x.name.deep = "dotted"
x[0] = "indexed"
assert a > 0
assert a > 0 if a, "a must be positive"
if a:
    b = 1
else:
    b = 2

# --- Expressions ---------------------------------------------------------
lit_int = 1
lit_float = 1.5
lit_str = "s"
lit_long = """
long
"""
lit_name = True
joined = "hi ${x.name}"
subscript = x[0]
subscript_slice = x[0:2]
subscript_step = x[0:2:1]
subscript_q = x?.name
call = f(1, 2, k = 3)
paren = (a)
unary = -a
unary_not = not lit_name
binary = a + 2
compare = a > 1
compare_chain = 0 < a <= 10
tern = a if a else 2
# A dotted *name* is a single Identifier with several names; a Selector only
# appears once there is a subscript or a `?` in the chain.
selector = list_lit[0].name
optional = x?.name
list_lit = [1, 2, 3]
list_if = [i for i in list_lit if i > 1]
list_if_item = [i if i else 0 for i in list_lit]
list_if_entry = [if a: 1 else: 2]
quant = all v in list_lit { v > 0 }
dict_comp = {k: v for k, v in {"a": 1}.items()}
config = {a = 1, b: 2}
config_shorthand = {lit_int, lit_str}
config_if = {
    if a:
        c = 1
    else:
        c = 2
}
starred = [*list_lit, a]
lambda_expr = lambda p: int -> int { p }
lambda_plain = lambda { a }
missing_expr = missing

# A bare expression statement: `Stmt::Expr`. The check block and the lambda
# bodies produce these too, but only nested.
a + 1

# --- Zero-parameter function type -----------------------------------------
# `ast::FunctionType.params_ty` is `Option<Vec<NodeRef<Type>>>`, which looks
# three-state. It is not: `crates/parser/src/parser/ty.rs` only ever builds
# `None` or `Some(non-empty)`, so the wire carries `params_ty: null` and never
# `[]`. A binding that maps `null` to `[]` is therefore normalising, not
# losing information — but nothing else pins that, so this does.
type TFuncNoArgs = () -> bool
