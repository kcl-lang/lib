"""Sample KCL used by AstJsonAlignmentTest to exercise every AST node shape
that was added during the typed AST packages."""

schema Person:
    """A person."""

    @deprecated
    name: str = "anonymous"

    age: int = 0

    check:
        age >= 0 if age, "age must be non-negative"

x = Person {name = "Alice", age = 30}

# A lambda with arguments — exercises the Arguments and Lambda AST nodes.
adder = lambda x: int, y: int -> int {
    x + y
}

# A schema with mixin + decorator — exercises decorators as flat DTOs.
mixin HasTimestamp:
    createdAt: str = "1970-01-01T00:00:00Z"

@deprecated
schema Article(HasTimestamp):
    title: str

# --- Type variants -------------------------------------------------------
# `Type` is adjacently tagged, so every one of these carries its payload under
# `value` rather than beside the tag. A decoder that reads the fields off the
# wrapper finds the tag where a field name belongs and decodes nulls.
type TList = [int]
type TDict = {str: int}
type TUnion = int | str

schema Endpoint:
    ports: [int] = []
    owner?: Person = None

# --- Statement variants --------------------------------------------------
# `IfStmt`, `AugAssignStmt` and `AssertStmt` had no decoder at all, so each of
# these used to fall through to the catch-all and vanish from the tree. The
# leading underscore is what makes a KCL binding mutable.
_counter = 0
_counter += 1
assert _counter >= 0
if _counter:
    _counter = 0
else:
    _counter = 1

# `declared: Person {…}` — a unification, whose `target` is one
# `NodeRef<Identifier>` rather than the list `AssignStmt` has.
service: Endpoint {ports = [1]}