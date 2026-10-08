# frozen_string_literal: true

# Constructors for the C binding.
#
# `c/include/kcl_lib_ast.h` declares no constructor *functions* at all. There is
# no `kcl_unary_expr_new(...)`, no `kcl_unary_expr_init(...)`, no `*_make` and no
# `*_build` anywhere under `c/` — the only public entry points the header offers
# are the two decoders `kcl_ast_parse_module(const char* ast_json)` and
# `kcl_ast_parse_program(const char* ast_json)`, four `*_free`s, the six
# `*_name` enum printers and the embedded JSON parser. Nothing in the package
# takes a node's fields as arguments.
#
# C is the one language here where that is not the end of the story, because C
# ships its own constructor: the designated initializer. `kcl_config_entry_t ce
# = { 0 };` is `c/examples/ast_alignment.c:133`, in the binding's own test
# suite, and it is the same argument `check_go` makes about a keyed struct
# literal and `check_python` makes about a dataclass's generated `__init__` —
# the language's own spelling of a constructor is the struct itself, so a
# struct's *members* are the parameters a caller can pass. A designated
# initializer omits what it does not mention and the omitted member is
# zero-initialized, so `defaulted` is `params` for every struct below, and rule
# 1 — a collection field must never be a required parameter — cannot fire for
# C. That is the right outcome rather than a lenient one: `paths_count = 0` is
# not something a C caller should ever be made to write.
#
# Two things follow from reading the struct and not a call site, and both are
# why this is a different scan from its neighbours:
#
#   * A `struct` definition is found wherever it appears, which is what reaches
#     the tagged-enum payloads. `Stmt`, `Expr` and `Type` are
#     `#[serde(tag = "type")]` enums in `ast.rs`, so their variants have no
#     struct for a constructor to be named after; C models each of them as an
#     anonymous struct in the wrapper's `union`, reachable as a member
#     (`e.u.unary_expr.op = …`). That is 22 `Expr` arms and 7 `Type` arms, and
#     every one of them is a constructor a caller can complete — the C arm's own
#     name is the `ast.rs` spelling for 29 of the 30 (the thirtieth being a
#     struct nested inside another arm, `u.literal_type.int_value`), so the
#     naming rule below reaches them without a table.
#   * C's own conventions add members that are not `ast.rs` fields, and a
#     collector that dropped them would be describing a language C does not
#     have. `Option<T>` is a value plus a `has_*` flag (`SchemaAttr.op` /
#     `has_op`, `NumberLit.binary_suffix` / `has_binary_suffix`,
#     `IntLiteralType.suffix` / `has_suffix`); a `Vec<T>` is a pointer plus a
#     `_count` twin (`Target.paths` / `paths_count`, `Compare.ops` /
#     `ops_count`); a `hash_map` is `{items, count}` (`*_node_list_t`,
#     `kcl_opt_*_list_t`); and a tag+content enum is a `kind` plus the raw
#     string kept for unknown variants (`kcl_expr_t.type_tag`,
#     `NumberLit.value_kind`). All of them are in `params`, so the rules name
#     them and a reviewer can see the cost in the report rather than having it
#     normalised away here.
#
# The `KCL_DECLARE_NODE` / `KCL_DECLARE_NODE_LIST` macros are expanded from
# their own `#define` bodies before the scan, so the fourteen `Node<T>` wrappers
# and thirteen list carriers they declare are found without either being spelled
# out by hand, and a change to either macro body is picked up rather than
# missed. `Node<T>` is recognised structurally — three members, `node`, `pos`,
# `id`, in that order — because that is what the macro and the one hand-written
# `Node<String>` (`kcl_string_node_t`) both declare, and `ast.rs:134` is the
# struct they are; with the two hand-written list carriers that is fifteen
# `Node<T>`s and fifteen carriers. `Node` is in `NOT_NODES`, so they are judged
# by nothing; they are returned because a binding that does expose a `Node`
# constructor should say so. C's is a complete one, and not by accident: the
# five position members live behind a `kcl_pos_t *pos` rather than being
# spelled out flat, which is the failure the checker documents for Python's.
#
# Three judgement calls, all of them stated here because a reader should be
# able to overrule them:
#
#   * `kcl_json_value_t` is returned even though it is not a node. It is the
#     header's embedded JSON DOM ("so the binding stays self-contained with no
#     vendored dependency"), and returning it keeps this file free of a
#     name-based filter; `compare` files it under `unmapped`, which is the
#     honest place for it.
#   * A member whose name begins with `_` is not a parameter. There is exactly
#     one — `_internals`, on `kcl_module_t` and `kcl_program_t` — and the
#     header says of it: "Internal arena owning every allocation reachable
#     from this module. Opaque; do not touch." A caller cannot pass it and
#     nothing reads it, so counting it would be a rule 3 complaint about an
#     arena rather than about the AST.
#   * A declaration that cannot be read as a member raises rather than being
#     skipped, which is `check_go`'s discipline: the quiet version of this
#     parse is the one that reports success having stopped matching.
#
# What this collector does not see, and neither could a C caller: the two
# decoders are not returned. `kcl_ast_parse_module` returns a `kcl_module_t`
# from a `const char*`, and reporting it as a constructor of `Module` with the
# parameter `ast_json` would be a rule 3 complaint invented out of nothing —
# it takes a document, not a node's fields.
#
# Four C types are named for something other than the `ast.rs` struct they are,
# and they are the one place this file overrides the naming rule rather than
# applying it. Each is written down below with the line it can be checked
# against, because a rename that is not written down is the failure
# `STRUCT_ALIASES` exists to prevent — and each of the four belongs in that
# table, which is written for the renames a collector cannot see. The fourth,
# `u.literal_type.int_value`, is additionally the `WRAPPED_PAYLOADS` shape the
# checker names for Kotlin's `literalIntType`, reached through a different door:
# `WRAPPED_PAYLOADS` is keyed by *function name*, and C has no function here,
# so that claim has nowhere in the tables to live and is made here instead.
# Returning all four under their C spelling would be no more honest — it would
# only move each claim out of the problems list and into the missing list,
# where it stops being checkable against a struct at all.

def check_c(path)
  # The one file that holds the C AST. A directory is accepted so the registry
  # can point at `c/` or at `c/include/`; both are one `kcl_lib_ast.h` away.
  header =
    if File.directory?(path)
      %w[kcl_lib_ast.h include/kcl_lib_ast.h].map { |rel| File.join(path, rel) }.find { |f| File.exist?(f) }
    else
      path
    end
  raise "c: no kcl_lib_ast.h at #{path}" if header.nil? || !File.exist?(header)

  # Comments first. The header's preamble quotes `ast.rs` field-for-field and
  # its member comments quote them again ("`names` is `Vec<Node<String>>`"), so
  # a brace in a comment would otherwise be counted as a body.
  src = File.read(header).gsub(%r{/\*.*?\*/}m, " ").gsub(%r{//[^\n]*}, " ")

  # Then the two macros, captured before the directives that hold them are
  # removed — the body of `KCL_DECLARE_NODE` is itself a `struct` definition
  # with the parameter `name` where the tag goes, which a scan of the raw
  # header would read as a struct called `name`.
  macros = {}
  src.scan(/^[ \t]*#define[ \t]+(\w+)\(([^)]*)\)(.*?)(?<!\\)\n/m) do |name, args, body|
    macros[name] = [args.split(",").first.to_s.strip, body.gsub(/\\\r?\n[ \t]*/, " ")]
  end
  src = src.gsub(/^[ \t]*#(?:.*\\\r?\n)*.*\n/, "\n")

  # Expand `KCL_DECLARE_NODE(kcl_expr_node)` into the
  # `typedef struct kcl_expr_node { … } kcl_expr_node_t;` its `#define` spells,
  # and `KCL_DECLARE_NODE_LIST(kcl_string)` likewise.
  #
  # The parameter is substituted as a whole *token*, which is what C does and
  # what `\b` gets wrong here. `} name##_t` puts `#` straight after `name`, so
  # the lookahead must accept a non-word character — but `_` is a word
  # character, so stripping the `##` first would leave `name_t` with no
  # boundary on either side and silently expand all fourteen wrappers to a
  # struct called `name`. The lookbehind stops the left edge so the parameter is
  # not matched inside a longer identifier; the `##` goes second, while the
  # parameter is still a token of its own.
  %w[KCL_DECLARE_NODE_LIST KCL_DECLARE_NODE].each do |macro|
    (param, body) = macros.fetch(macro)
    src = src.gsub(/^[ \t]*#{macro}\((\w+)\);[ \t]*$/) do
      # The argument is read out of the match before any gsub runs: each one
      # is a pattern in its own right and resets `Regexp.last_match`.
      arg = Regexp.last_match(1)
      body.gsub(/(?<![\w])#{Regexp.escape(param)}(?=\W|$)/) { arg }.gsub("##", "") << ";"
    end
  end

  # The four C types whose name is not `ast.rs`'s, keyed by the path this scan
  # reaches them at. Every other struct in the header is named by the rule
  # below, and this is the whole of the exception.
  #
  #   * `kcl_program_t` is `SerializeProgram` (ast.rs:386), the serialised
  #     projection `parse_program` sends. Left to the rule it camel-cases to
  #     `Program`, the resolution index (ast.rs:435) — a struct `ast.rs` never
  #     serialises and one C does not model, so the report would hold C to
  #     `pkgs_not_imported` and `modules_not_imported` and never mention
  #     `SerializeProgram` at all. The same correction `STRUCT_ALIASES` already
  #     makes for Kotlin's `Program`.
  #   * `u.compare_expr` is `Compare` (ast.rs:1385) and `u.subscript_expr` is
  #     `Subscript` (ast.rs:1302). Two of the twenty-nine union arms, and the
  #     only two whose C spelling is not the `ast.rs` one; the other twenty-
  #     seven are the rule below verbatim.
  #   * `u.literal_type.int_value` is `IntLiteralType` (ast.rs:1909), the
  #     payload of the `LiteralType::Int` variant — a struct nested inside the
  #     tag+content arm, with no name of its own in C. `LiteralType::Int` is
  #     the only variant whose payload is a struct rather than a scalar
  #     (`Bool(bool)`, `Float(f64)`, `Str(String)`), which is why this is a
  #     single entry in Kotlin's `WRAPPED_PAYLOADS` and a single entry here.
  renames = {
    "kcl_program_t" => "SerializeProgram",
    "kcl_expr_t.u.compare_expr" => "Compare",
    "kcl_expr_t.u.subscript_expr" => "Subscript",
    "kcl_type_node_t.u.literal_type.int_value" => "IntLiteralType"
  }

  ctors = []
  seen = {}

  c_structs(src, nil).each do |path, body|
    params = c_members(body, path).reject { |member| member.start_with?("_") }

    # `ast.rs`'s name for this struct. The C name is `kcl_foo_t` for a
    # `foo`, and the union arms and the `KCL_DECLARE_NODE` expansions are
    # named for the type they carry, so one rule covers both: strip the `kcl_`
    # and the `_t`, then camel-case what is left. It lands on the `ast.rs`
    # spelling for every DTO and for 28 of the 30 union structs; the two it
    # does not are in `renames` above, and a name the rule produces that
    # `ast.rs` does not declare is left alone for `compare` to file as
    # `unmapped` rather than being second-guessed here.
    leaf = path.split(".").last.sub(/\Akcl_/, "").sub(/_t\z/, "")
    name = renames[path] ||
           leaf.split("_").reject(&:empty?).map { |w| w[0].upcase + w[1..] }.join

    # The fifteen `Node<T>` wrappers are the one thing here that is not named
    # for its type: `ast.rs:134` is `Node<T>`, `NOT_NODES` exempts it, and all
    # fifteen declare the same three members, so they are one entry.
    name = "Node" if params == %w[node pos id]

    entry = [name, params, params.dup]
    # Two C structs reaching the same `ast.rs` struct over the same members is
    # the fifteen `Node` wrappers and nothing else, and `compare` unions a
    # struct's constructors anyway — recording one twice would inflate the
    # count this collector is asked to report.
    next if seen[entry]
    seen[entry] = true

    ctors << entry
  end

  ctors
end

# Every `struct` definition in `text`, in source order, as `[path, body]`.
#
# A `union` is walked but not returned: a union is how C spells a tagged enum,
# and it is the `struct` inside it that is the payload. The declarator a union
# carries (`u`, in all four unions this header declares) becomes a path
# segment, which is what makes an arm's path `kcl_expr_t.u.unary_expr` and a
# struct nested in that arm's `LiteralType` payload
# `kcl_type_node_t.u.literal_type.int_value`.
def c_structs(text, parent)
  found = []
  at = 0

  while (m = /\b(struct|union)\b(?:\s+([A-Za-z_]\w*))?\s*\{/.match(text, at))
    keyword, tag = m[1], m[2]
    closing = c_closing_brace(text, m.end(0) - 1)
    break if closing.nil?

    body = text[(m.end(0))...closing]
    # Everything between the closing brace and the `;` is the declarator. A
    # bare `struct kcl_json_value { … };` has none and is named by its tag; a
    # `typedef struct kcl_pos { … } kcl_pos_t;` has one and is named by it.
    after = text[(closing + 1)..] || ""
    semicolon = after.index(";")
    break if semicolon.nil?
    declarator = after[0...semicolon]
    if declarator.include?(",")
      raise "c: #{parent || "(top level)"}: `#{keyword} … #{declarator.strip};` declares more than one name, " \
            "which this scan reads as one"
    end
    here = declarator[/([A-Za-z_]\w*)\s*(?:\[[^\]]*\])?\s*(?::\s*[^,]+)?\z/, 1] || tag

    if here
      found << [parent ? "#{parent}.#{here}" : here, body] if keyword == "struct"
      found.concat(c_structs(body, parent ? "#{parent}.#{here}" : here))
    end

    # Past the declarator and its `;`, so a nested definition is reported by
    # the recursion and not again by this pass.
    at = closing + 1 + semicolon + 1
  end

  found
end

# The members of one struct body, in declaration order.
#
# Split on the `;` at brace depth zero, which is what keeps a nested `struct`
# or `union` body's own semicolons out of the parent's member list. C's
# declarator is the last name in the declaration, so `kcl_opt_expr_node_t
# value` is `value` and `kcl_string_node_t* asname` is `asname`.
def c_members(body, path)
  members = []
  depth = 0
  start = 0

  body.each_char.with_index do |ch, i|
    case ch
    when "{", "(", "[" then depth += 1
    when "}", ")", "]" then depth -= 1
    when ";"
      if depth.zero?
        members << c_member(body[start...i], path)
        start = i + 1
      end
    end
  end

  members.compact
end

# One member declaration, as its name, or nil for nothing. A nested
# `struct { … } name;` is named after its closing brace, and a declaration
# with no name there is an anonymous member — legal C, and unnameable by a
# caller, so it is raised rather than dropped.
def c_member(decl, path)
  text = decl.strip
  return nil if text.empty?

  text = text[(text.rindex("}") + 1)..].to_s.strip if text.include?("}")
  name = text[/([A-Za-z_]\w*)\s*(?:\[[^\]]*\])?\s*(?::\s*[^,]+)?\z/, 1]
  raise "c: cannot read this line of `#{path}` as a member: #{decl.strip}" if name.nil?

  name
end

# The `}` matching the `{` at `open`, or nil if the header does not close it.
def c_closing_brace(src, open)
  depth = 0
  i = open

  while i < src.length
    case src[i]
    when "{" then depth += 1
    when "}"
      depth -= 1
      return i if depth.zero?
    end
    i += 1
  end

  nil
end
