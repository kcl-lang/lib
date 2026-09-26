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