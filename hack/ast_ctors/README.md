# Per-language AST constructor collectors

One file per binding. Each defines a single method and nothing else:

```ruby
def check_<lang>(path_or_dir)
  # => [[struct_name, params, defaulted], ...]
end
```

`check_ast_constructors.rb` requires everything in this directory and calls the
method from its `CHECKS` registry. The rules, the canonical struct list and the
report all live there and are language-independent — a collector only has to
answer one question per constructor, so a binding cannot end up held to a laxer
standard than its neighbours by accident.

## The triple

| element | meaning |
|---|---|
| `struct` | the binding's own name for the node. `STRUCT_ALIASES` in the checker maps it onto the `ast.rs` name; if yours differs, add it there rather than renaming in the source. |
| `params` | every parameter a caller can pass, by name, in declaration order. |
| `defaulted` | the subset of `params` a caller may omit. |

The join from a parameter to an `ast.rs` field tries the exact name, then
`PARAM_ALIASES` for the binding, then one camelCase→snake_case pass. So `ifCond`
finds `if_cond` and `ty_list` finds `ty_list` with no table entry.

## What "defaulted" means

A parameter is in `defaulted` when a caller can leave it out — an `=` default,
`Optional`, a nullable type, a dataclass `default_factory`, a Go zero-value that
the language fills in, and so on. Rule 1 compares the two lists: a field Rust
*always* writes (`Vec`, `HashMap`) must not appear only in `params`.

## Rules a collector cannot escape

These are enforced by `compare`, not by the collector, but a collector that
misreports them is worse than one that does not exist:

- Return a constructor even when it is a *convenience* — a varargs helper, a
  delegate. `compare` judges a struct once over the **union** of its
  constructors, so a convenience that forwards is free, and one that does not
  forward anything shows up in the unreachable list.
- Return the struct a constructor **actually builds**, not the one its name
  suggests. Kotlin's `schemaConfig` builds `SchemaExpr`.
- A constructor whose return type is a tagged-enum wrapper rather than the
  payload struct it fills in is a blind spot. Do not paper over it in the
  collector — register it in `WRAPPED_PAYLOADS` in the checker, where the claim
  is written down and reviewable.

## Before you claim it works

A collector that reports "ok" on a broken binding is worse than none, so:

1. Run `ruby hack/check_ast_constructors.rb` and expect a **non-zero** exit
   until the binding is complete. `ok (N constructors)` with `N` far below the
   number of node types means your regex is not matching, not that the binding
   is good.
2. Break something on purpose and confirm the rules name the right struct. The
   self-test in `hack/test_check_ast_constructors.rb` is where that belongs.
3. Never widen `NOT_NODES`, `NOT_ON_THE_WIRE`, `PARAM_ALIASES`,
   `STRUCT_ALIASES` or `KNOWN_HELPERS` to make your binding pass without
   checking the exclusion against `ast.rs` first. Those tables are the whole
   enforcement mechanism; an unjustified entry hides a real gap everywhere.