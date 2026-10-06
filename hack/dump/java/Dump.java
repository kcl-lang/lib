// Cross-language AST dump for the Java binding.
//
//   hack/dump/java.sh <golden.json> <out.json>
//
// Runs the binding's real decoder over the shared capture and writes the tree
// in the shape `hack/ast_diff/canonical.rb` compares.
//
// Java has no field reflection the way Dart does, so the walk uses
// `java.lang.reflect` over the declared fields of each object's class. That is
// the point of doing it this way: a dumper that spelled the field list out by
// hand would be a second list to keep in sync with `com.kcl.ast`, and it would
// go stale silently — which is the failure mode this harness exists to catch.
// Each field is named the way the decoder named it, which for this binding is
// the `@JsonProperty` value when there is one, so the names under test are the
// ones Jackson was asked to honour rather than the ones this file would have
// preferred.
//
// Four Java-specific things the walk has to get right:
//
//   * The tag lives in `@JsonSubTypes` on the *base* class, not on the variant,
//     and the base uses two different `include` styles: `As.PROPERTY` for
//     `Stmt` / `Expr` / `Type` / `MemberOrIndex` / `BinOrCmpOp` and
//     `As.EXTERNAL_PROPERTY` for `LiteralTypeValue` / `NumberLitValue`, whose
//     tag is a sibling of the object rather than a member of it. Reading the
//     annotation rather than the runtime class name gives one answer for both,
//     and it is the binding's own claim about which variant it decoded, so it
//     goes into `@tag` for the comparator's three-way tag cross-check.
//
//   * `Node` and `NodeRef` box their payload under `node` and carry the five
//     position keys flat beside it. The comparator reads a nested `pos` /
//     `position` (R2) and this binding has none, so there is nothing to hoist.
//
//   * `Node#id` is *not* written. Rust only serialises it under
//     `SHOULD_SERIALIZE_ID`, which is off, so the golden carries no `id` and a
//     dumper that emitted the field's value would be reporting a number the
//     wire never had. `kotlin/src/main/kotlin/com/kcl/ast/AstWire.kt` makes the
//     same call for the same reason.
//
//   * Rust's `Option<T>` is `java.util.Optional` here, and serde *writes* an
//     absent `Option` as an explicit `null` rather than omitting the key. An
//     absent `Optional` is therefore dumped as `null`, not dropped: dropping it
//     would compare as a missing key and turn a field the decoder read
//     correctly into a difference.

package astdump;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.fasterxml.jackson.datatype.jdk8.Jdk8Module;
import com.kcl.ast.Module;

import java.io.File;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

public final class Dump {

    /** `Node`/`NodeRef` boxes its payload under this key. */
    private static final String NODE_PAYLOAD = "node";

    public static void main(String[] args) throws Exception {
        if (args.length != 2) {
            System.err.println("usage: hack/dump/java.sh <golden.json> <out.json>");
            System.exit(2);
        }

        String golden = new String(Files.readAllBytes(Paths.get(args[0])), "UTF-8");

        // Read as a bare `Module`, which is what the golden is.
        //
        // This is not the binding's own entry point, and that is a finding
        // rather than a convenience: `JsonUtil` exposes exactly one decoder,
        // `deserializeProgram`, and it wants the `{"root":…,"pkgs":{…}}`
        // envelope that `ParseProgramResult.ast_json` carries. The golden is a
        // single module — the shape `ParseFileResult.ast_json` carries — and
        // this binding has no typed entry point for *that*, so a Java caller
        // who parses one file and asks for the typed AST has to build a mapper
        // themselves. Every other binding here has a `parseModule` next to its
        // `parseProgram` (kotlin's `AstJson.kt` documents that it mirrors the
        // Java helper, and adds the one Java is missing).
        //
        // The mapper below is configured exactly as `JsonUtil.newMapper()`
        // configures its own — same Jdk8 module, same
        // FAIL_ON_UNKNOWN_PROPERTIES — so the decode is the binding's decode.
        ObjectMapper mapper = new ObjectMapper()
                .registerModule(new Jdk8Module())
                .configure(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES, false);

        Module module = mapper.readValue(golden, Module.class);
        if (module == null) {
            System.err.println("the golden deserialized to a null Module");
            System.exit(1);
        }

        Map<String, Object> doc = new LinkedHashMap<>();
        doc.put("schema", "kcl-ast-canonical/1");
        doc.put("binding", "java");
        doc.put("mode", "reflect");
        doc.put("root", dump(module));

        ObjectMapper out = new ObjectMapper().enable(SerializationFeature.INDENT_OUTPUT);
        out.writeValue(new File(args[1]), doc);
    }

    // ------------------------------------------------------------------
    // the walk
    // ------------------------------------------------------------------

    private static Object dump(Object v) throws IllegalAccessException {
        if (v == null) {
            return null;
        }
        if (v instanceof Optional) {
            // serde writes an absent `Option` as an explicit `null`, so an
            // empty Optional is dumped as one rather than dropped.
            return dump(((Optional<?>) v).orElse(null));
        }
        if (v instanceof String || v instanceof Boolean || v instanceof Integer
                || v instanceof Long || v instanceof Double) {
            return v;
        }
        if (v instanceof Enum) {
            // The wire spells the operators as bare strings — `"op": "USub"`,
            // `"ctx": "Load"` — and the enum constant is the same spelling.
            // The `symbol()` accessor on `UnaryOp` is the *operator glyph*
            // (`"-"`), which is a different thing entirely.
            return ((Enum<?>) v).name();
        }
        if (v instanceof Map) {
            Map<String, Object> m = new LinkedHashMap<>();
            for (Map.Entry<?, ?> e : ((Map<?, ?>) v).entrySet()) {
                m.put(String.valueOf(e.getKey()), dump(e.getValue()));
            }
            return m;
        }
        if (v instanceof Collection) {
            List<Object> list = new ArrayList<>();
            for (Object o : (Collection<?>) v) {
                list.add(dump(o));
            }
            return list;
        }

        Class<?> cls = v.getClass();
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("@cls", cls.getSimpleName());

        String tag = tagOf(cls);
        if (tag != null) {
            out.put("@tag", tag);
        }

        for (Field f : fieldsOf(cls)) {
            String name = jsonName(f);
            if (name == null) {
                continue; // @JsonIgnore
            }
            if (isNode(cls) && f.getName().equals("id")) {
                // See the header: Rust only serialises `id` under
                // SHOULD_SERIALIZE_ID, which is off.
                continue;
            }
            f.setAccessible(true);
            out.put(name, dump(f.get(v)));
        }
        return out;
    }

    // ------------------------------------------------------------------
    // reflection helpers
    // ------------------------------------------------------------------

    /**
     * The declared instance fields of {@code cls} and every superclass, nearest
     * first. Walking the chain is what makes an inherited field — `Node`'s
     * position keys, seen from `NodeRef` — show up, so a dumper here does not
     * have to know that `NodeRef` adds nothing of its own.
     */
    private static List<Field> fieldsOf(Class<?> cls) {
        List<Field> out = new ArrayList<>();
        for (Class<?> c = cls; c != null && c != Object.class; c = c.getSuperclass()) {
            for (Field f : c.getDeclaredFields()) {
                if (Modifier.isStatic(f.getModifiers()) || f.isSynthetic()) {
                    continue;
                }
                out.add(f);
            }
        }
        return out;
    }

    /**
     * The name Jackson was told to use for {@code f}, or {@code null} when the
     * field is ignored. Reading this off the annotation is what makes the diff
     * about the decoder: a field this dumper renamed on its own initiative
     * would compare under a name no caller ever sees.
     */
    private static String jsonName(Field f) {
        if (f.isAnnotationPresent(JsonIgnore.class)) {
            return null;
        }
        JsonProperty p = f.getAnnotation(JsonProperty.class);
        return p != null && !p.value().isEmpty() ? p.value() : f.getName();
    }

    private static boolean isNode(Class<?> cls) {
        return com.kcl.ast.Node.class.isAssignableFrom(cls);
    }

    /**
     * The wire tag this binding claims for {@code cls}, read out of the
     * {@code @JsonSubTypes} table on the nearest base that declares one.
     *
     * <p>Neither tag style is special-cased: {@code As.PROPERTY} and
     * {@code As.EXTERNAL_PROPERTY} differ in where the tag sits on the wire,
     * not in which name the variant answers to, and the name is what the
     * comparator cross-checks.
     *
     * <p>{@code null} for a class with no table and no entry — a plain struct
     * like {@code ImportStmt} is a class *with* an entry, so it does answer;
     * a DTO like {@code ConfigEntry} is not in any table and correctly answers
     * nothing, which the comparator reads as "this object claims no tag".
     */
    private static String tagOf(Class<?> cls) {
        for (Class<?> c = cls; c != null; c = c.getSuperclass()) {
            JsonSubTypes types = c.getAnnotation(JsonSubTypes.class);
            if (types == null) {
                continue;
            }
            for (JsonSubTypes.Type t : types.value()) {
                if (t.value().equals(cls)) {
                    return t.name();
                }
            }
        }
        return null;
    }

    private Dump() {
    }
}
