// _types.mjs — Type hierarchy. Mirrors `ast::Type` in `crates/ast/src/ast.rs`.
//
// `Type` is declared `#[serde(tag = "type", content = "value")]` — note the
// `content`. That makes it the one hierarchy in the AST that is *adjacently*
// tagged rather than internally tagged: every node is a two-key object
// `{"type": "<Variant>", "value": <payload>}`, and the tag names the shape,
// not the type. A basic type therefore reads back as
// `{"type": "Basic", "value": "Int"}` and **not** as `{"type": "Int"}`,
// because `BasicType` is a fieldless enum with no struct wrapper.
//
// There is no `Void`, `Undefined`, `None`, `SchemaRef` or `KeyValue` variant:
// the eight below are the whole enum. A tag outside this set is returned as
// `UnknownType` rather than dropped, so a newer parser degrades instead of
// throwing.

import { nodeFromWire } from './_base.mjs'

/**
 * `Type::Any` — a bare `{"type": "Any"}` with no payload.
 * @typedef {Object} AnyType
 * @property {'Any'} type
 */

/**
 * `Type::Basic(BasicType)`. The payload is a bare string, not an object.
 * @typedef {Object} BasicType
 * @property {'Basic'} type
 * @property {string} name  "Bool" | "Int" | "Float" | "Str"
 */

/**
 * `Type::Named(Identifier)`. The payload is a bare `Identifier`, not a
 * `NodeRef<Identifier>` — `Type` is adjacently tagged, so the newtype is
 * inlined into `value` with no position wrapper around it. The loader guards
 * on a missing payload, so the field can be `undefined` here.
 * @typedef {Object} NamedType
 * @property {'Named'} type
 * @property {Identifier|undefined} identifier  the inlined `Identifier` struct
 */

/**
 * `Type::List(ListType)`.
 * @typedef {Object} ListType
 * @property {'List'} type
 * @property {MaybeNode<Type>|undefined} innerType
 */

/**
 * `Type::Dict(DictType)`.
 * @typedef {Object} DictType
 * @property {'Dict'} type
 * @property {MaybeNode<Type>|undefined} keyType
 * @property {MaybeNode<Type>|undefined} valueType
 */

/**
 * `Type::Union(UnionType)`. The Rust field is `type_elements`; it is exposed
 * as `types` here because `types` is what a caller reaches for.
 * @typedef {Object} UnionType
 * @property {'Union'} type
 * @property {Array<MaybeNode<Type>>} types
 */

/**
 * `Type::Literal(LiteralType)`. `LiteralType` is *itself* tagged, so the
 * payload is doubly nested: `{"type":"Int","value":{"value":1,"suffix":null}}`.
 * @typedef {Object} LiteralType
 * @property {'Literal'} type
 * @property {Record<string,any>} value
 * @property {string|undefined} innerTag  the inner `LiteralType` tag
 */

/**
 * `Type::Function(FunctionType)`.
 * @typedef {Object} FunctionType
 * @property {'Function'} type
 * @property {Array<MaybeNode<Type>>|undefined} paramsTy
 * @property {MaybeNode<Type>|undefined} retTy
 */

/**
 * A tag this build does not know about. `value` is the raw payload, so a
 * caller can still reach the data a future parser emitted.
 * @typedef {Object} UnknownType
 * @property {'Unknown'} type
 * @property {string} tag     the tag the parser actually sent
 * @property {*} value
 */

/**
 * @typedef {AnyType|BasicType|NamedType|ListType|DictType|UnionType|LiteralType|FunctionType|UnknownType} Type
 */

/**
 * `ast::Identifier` — `a`, `_c`, `pkg.a`. A plain struct with no tag.
 * @typedef {Object} Identifier
 * @property {Array<MaybeNode<string>>} names
 * @property {string} pkgpath
 * @property {string|undefined} ctx  "Load" | "Store"
 */

/**
 * Build an `Identifier` from the wire object. Exported because the `Type`
 * and `Expr` hierarchies both embed one inline.
 * @param {Record<string,any>|undefined|null} w
 * @returns {Identifier|undefined}
 */
export function identifierFromWire(w) {
  if (!w) return undefined
  return {
    names: (w.names || []).map((/** @type {any} */ n) => nodeFromWire(n, (x) => /** @type {string} */ x)),
    pkgpath: w.pkgpath || '',
    ctx: w.ctx,
  }
}

/**
 * Polymorphic `Type` loader.
 * @param {Record<string,any>|undefined|null} w
 * @returns {Type|undefined}
 */
export function typeFromWire(w) {
  if (!w) return undefined
  const tag = w.type
  if (tag === undefined || tag === null) return undefined
  const value = w.value

  switch (tag) {
    case 'Any':
      return { type: 'Any' }
    case 'Basic':
      return { type: 'Basic', name: typeof value === 'string' ? value : '' }
    case 'Named':
      return { type: 'Named', identifier: identifierFromWire(value) }
    case 'List': {
      const list = value || {}
      return { type: 'List', innerType: nodeFromWire(list.inner_type, typeFromWire) }
    }
    case 'Dict': {
      const dict = value || {}
      return {
        type: 'Dict',
        keyType: nodeFromWire(dict.key_type, typeFromWire),
        valueType: nodeFromWire(dict.value_type, typeFromWire),
      }
    }
    case 'Union': {
      const union = value || {}
      return {
        type: 'Union',
        // The Rust field is `type_elements`.
        types: (union.type_elements || []).map((/** @type {any} */ t) => nodeFromWire(t, typeFromWire)),
      }
    }
    case 'Literal':
      return {
        type: 'Literal',
        value,
        // `LiteralType` carries its own tag, so record it rather than making
        // the caller reach into `value` to find out which literal it is.
        innerTag: value && typeof value === 'object' ? value.type : undefined,
      }
    case 'Function': {
      const fn = value || {}
      return {
        type: 'Function',
        paramsTy: (fn.params_ty || []).map((/** @type {any} */ p) => nodeFromWire(p, typeFromWire)),
        retTy: nodeFromWire(fn.ret_ty, typeFromWire),
      }
    }
    default:
      return { type: 'Unknown', tag, value }
  }
}

/**
 * @template T
 * @typedef {import('./_base.mjs').Node<T>} Node
 */
/** @template T @typedef {import('./_base.mjs').MaybeNode<T>} MaybeNode */
