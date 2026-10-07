package ast

import "encoding/json"

// The decode helpers the generated `fromWire` methods call. Everything that a
// field's shape decides at *generation* time is already in the generated code;
// these four are the ones whose answer depends on the value rather than on the
// declaration, and they are here rather than inlined so the generated files
// stay a statement about the Rust source and nothing else.

var nullJSON = json.RawMessage("null")

// isJSONNull reports whether a key was absent or explicitly null. The two mean
// the same thing to a decoder and neither means "present and empty": Rust's
// `Option<T>` is three-state in the type and two on the wire, and a `null` in a
// `Vec<Option<NodeRef<T>>>` is a slot that is *meant* to be there.
func isJSONNull(raw json.RawMessage) bool {
	trimmed := bytesTrimSpace(raw)
	return len(trimmed) == 0 || string(trimmed) == "null"
}

func bytesTrimSpace(raw json.RawMessage) []byte {
	start, end := 0, len(raw)
	for start < end && isSpace(raw[start]) {
		start++
	}
	for end > start && isSpace(raw[end-1]) {
		end--
	}
	return raw[start:end]
}

func isSpace(c byte) bool {
	return c == ' ' || c == '\t' || c == '\n' || c == '\r'
}

// readJSON keeps a value whole. `NumberLitValue.value` is `any`: the four
// variants carry an int, a float, or a string, and there is no single Go type
// that is all three. Splitting it per kind would invent structure the wire does
// not have -- the Rust type is a bare enum with a `value` payload and nothing
// else.
func readJSON(raw json.RawMessage) any {
	if isJSONNull(raw) {
		return nil
	}
	var out any
	if err := json.Unmarshal(raw, &out); err != nil {
		return nil
	}
	return out
}

// readDocument is `readJSON` for a field that is *known* to be an object, so it
// returns an empty map rather than nil and a derived tag beside it is always
// readable. `Type::Literal`'s payload is the one: a second `tag/content`
// document with no fixed field set.
func readDocument(raw json.RawMessage) map[string]any {
	out := map[string]any{}
	if isJSONNull(raw) {
		return out
	}
	if err := json.Unmarshal(raw, &out); err != nil {
		return map[string]any{}
	}
	return out
}

// readOptString is `Option<String>`, which is a pointer rather than `""`: the
// distinction is load-bearing for `Identifier.pkgpath`, where an absent path
// and an empty one are different answers to "is this qualified?".
func readOptString(raw json.RawMessage) *string {
	if isJSONNull(raw) {
		return nil
	}
	var out string
	if err := json.Unmarshal(raw, &out); err != nil {
		return nil
	}
	return &out
}

// marshalAdjacent writes an adjacently-tagged variant back out.
//
// Rust's `#[serde(tag = "type", content = "value")]` puts the tag and the
// payload in *sibling* keys: `Type::List(ListType)` is
// `{"type": "List", "value": {"inner_type": …}}`, where the content object
// carries no tag of its own. `encoding/json` has no notion of a wrapper around
// a struct's fields, so the fields go out flat and the wrapper is spliced on
// here.
//
// `v` is the payload with its `MarshalJSON` already removed by the caller's
// `type plain T` conversion -- that conversion is what stops this re-encoding
// from calling itself. `tag` is the variant's own name and is written
// unconditionally, so a payload built by hand without a tag still marshals to
// the variant it is declared as rather than to an untagged object.
//
// A payload that encodes to `{}` is a unit variant, and serde leaves the
// content key off those entirely: `Type::Any` is `{"type": "Any"}`, not
// `{"type": "Any", "value": {}}`. Writing the key anyway would be the
// difference between a round-trip that reproduces the capture and one that
// adds a key to every unit-typed annotation in it.
func marshalAdjacent(v any, tag, key, content string) ([]byte, error) {
	fields, err := json.Marshal(v)
	if err != nil {
		return nil, err
	}
	wrapper := map[string]any{key: tag}
	if string(fields) != "{}" {
		wrapper[content] = json.RawMessage(fields)
	}
	return json.Marshal(wrapper)
}

// readAdjacent returns the payload object of an adjacently-tagged variant, or
// an empty document when there is none. `Type::Any` carries no content key at
// all, and a variant with no fields has nothing to read either way; the two
// are the same document to a decoder that is about to look up zero keys in it.
func readAdjacent(d map[string]json.RawMessage, content string) (map[string]json.RawMessage, error) {
	inner := map[string]json.RawMessage{}
	raw := d[content]
	if isJSONNull(raw) {
		return inner, nil
	}
	if err := json.Unmarshal(raw, &inner); err != nil {
		return nil, err
	}
	return inner, nil
}
