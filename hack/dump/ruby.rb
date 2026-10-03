# frozen_string_literal: true

# Cross-language AST dump for the Ruby binding.
#
#   ruby -Iruby/lib hack/dump/ruby.rb <golden.json> <out.json>
#
# Runs `KclLib::AST.parse_module` over the shared capture and writes the tree
# in the shape `hack/ast_diff/canonical.rb` compares. Nothing is reimplemented
# here: the walk is reflection over whatever the decoder produced, so a field
# read wrongly shows up in the dump as the wrong value rather than being
# papered over by a second, hand-written copy of the decoder.
#
# Ruby models the AST in two ways at once and this walk has to tell them
# apart:
#
#   * `Node` is a real `Struct` — the `NodeRef<T>` wrapper — with a nested
#     `Pos`. The comparator's R2 hoists the position back onto the wrapper,
#     which is where the wire has it.
#   * the variants are not `Struct`s at all. `variant_class` builds a class
#     whose fields live in an `@fields` hash behind `method_missing`, and
#     which carries the parser's tag in a `@tag` class variable reachable
#     through `Taggable#tag`. So each variant object reports its class name
#     *and* the tag the binding believes it has, and the comparator checks
#     both against the golden.
#   * the plain structs (`Identifier`, `Target`, `ConfigEntry`, `Module`, …)
#     are ordinary `Struct`s with no tag, which is correct: Rust declares
#     them as structs, not as enum variants.

require "json"
require "kcl_lib/ast"

A = KclLib::AST

def short(name)
  name.to_s.split("::").last
end

def dump(value)
  case value
  when nil, true, false, Integer, Float, String then value
  when Symbol then value.to_s
  when Array then value.map { |item| dump(item) }
  when A::Pos
    value.to_h.transform_values { |v| dump(v) }
  when A::Node
    out = { "node" => dump(value.node) }
    out["pos"] = dump(value.pos) unless value.pos.nil?
    out
  when A::MemberOrIndex
    # `ast::MemberOrIndex` is `#[serde(tag = "type", content = "value")]`, so
    # the discriminator is a *value*. Ruby keeps it in `kind`.
    { "@cls" => short(value.class.name), "@tag" => value.kind.to_s,
      "value" => dump(value.value) }
  when Struct
    out = { "@cls" => short(value.class.name) }
    value.members.each { |m| out[m.to_s] = dump(value[m]) }
    out
  when Hash
    value.each_with_object({}) { |(k, v), h| h[k.to_s] = dump(v) }
  else
    if value.respond_to?(:to_h) && value.class.name
      out = { "@cls" => short(value.class.name), "@tag" => value.tag.to_s }
      value.to_h.each { |k, v| out[k.to_s] = dump(v) }
      out
    else
      value.to_s
    end
  end
end

golden_path, out_path = ARGV
abort "usage: ruby hack/dump/ruby.rb <golden.json> <out.json>" unless golden_path && out_path

module_ast = A.parse_module(File.read(golden_path))

File.write(out_path, JSON.pretty_generate(
                         "schema" => "kcl-ast-canonical/1",
                         "binding" => "ruby",
                         "mode" => "reflect",
                         "root" => dump(module_ast)
                       ))
