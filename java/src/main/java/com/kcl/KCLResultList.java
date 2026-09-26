package com.kcl;

import java.util.ArrayList;
import java.util.Collections;
import java.util.Iterator;
import java.util.List;
import java.util.Map;

/**
 * Collection of {@link KCLResult} documents produced by a run, mirroring
 * kcl-go's {@code KCLResultList}. The raw runtime outputs
 * ({@code json_result}/{@code yaml_result}) are kept for callers that need
 * the untouched response.
 */
public final class KCLResultList implements Iterable<KCLResult> {
    private final List<KCLResult> results;
    private final String rawJsonResult;
    private final String rawYamlResult;

    KCLResultList(List<KCLResult> results, String rawJsonResult, String rawYamlResult) {
        this.results = Collections.unmodifiableList(new ArrayList<KCLResult>(results));
        this.rawJsonResult = rawJsonResult == null ? "" : rawJsonResult;
        this.rawYamlResult = rawYamlResult == null ? "" : rawYamlResult;
    }

    /** Number of documents in the result. */
    public int size() {
        return results.size();
    }

    /** Whether the run produced no documents. */
    public boolean isEmpty() {
        return results.isEmpty();
    }

    /** The i-th document, mirroring kcl-go's {@code KCLResultList.Get}. */
    public KCLResult get(int index) {
        if (index < 0 || index >= results.size()) {
            return null;
        }
        return results.get(index);
    }

    /** The first document, or {@code null} when empty. */
    public KCLResult first() {
        return results.isEmpty() ? null : results.get(0);
    }

    /** The last document, or {@code null} when empty. */
    public KCLResult tail() {
        return results.isEmpty() ? null : results.get(results.size() - 1);
    }

    /** All documents as an unmodifiable list, mirroring kcl-go's {@code Slice}. */
    public List<KCLResult> asList() {
        return results;
    }

    @Override
    public Iterator<KCLResult> iterator() {
        return results.iterator();
    }

    /**
     * The first document decoded as a map, mirroring kcl-go's
     * {@code KCLResultList.ToMap}.
     *
     * @throws KclException
     *             when the result list is empty or the first document is not a
     *             map
     */
    public Map<String, Object> toMap() {
        KCLResult first = first();
        if (first == null) {
            throw new KclException("result is nil");
        }
        return first.toMap();
    }

    /** Dotted-key lookup on the first document; {@code null} when absent. */
    public Object get(String key) {
        KCLResult first = first();
        if (first == null) {
            return null;
        }
        return first.get(key);
    }

    /** The untouched {@code ExecProgramResult.json_result} emitted by the runtime. */
    public String getRawJsonResult() {
        return rawJsonResult;
    }

    /** The untouched {@code ExecProgramResult.yaml_result} emitted by the runtime. */
    public String getRawYamlResult() {
        return rawYamlResult;
    }
}
