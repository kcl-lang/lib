package com.kcl;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import com.kcl.api.Spec.Argument;
import com.kcl.api.Spec.ExecProgramArgs;
import com.kcl.api.Spec.ExecProgramArgs.Builder;
import com.kcl.api.Spec.ExternalPkg;

/**
 * Functional option accepted by the {@link Kcl} facade entry points.
 *
 * <p>
 * Mirrors kcl-go's {@code Option}: each option contributes a slice of state
 * that is merged into a shared {@link KclOptionBag} before the
 * {@link ExecProgramArgs} proto is materialised. Users build options with the
 * static {@code with*} factories on {@link Kcl}; the {@link #apply} method is
 * only callable from within the {@code com.kcl} package because its parameter
 * type is package-private.
 */
@FunctionalInterface
public interface KclOption {
    void apply(KclOptionBag bag);
}

/**
 * Mutable bag of merged option state, mirroring the union of fields the
 * kcl-go {@code Option} struct can populate. Internal to the facade; users
 * only ever see {@link KclOption} instances.
 */
final class KclOptionBag {
    String workDir;
    final List<String> kFilenameList = new ArrayList<String>();
    final List<String> kCodeList = new ArrayList<String>();
    final List<Argument> args = new ArrayList<Argument>();
    final List<String> overrides = new ArrayList<String>();
    final List<String> selectors = new ArrayList<String>();
    final List<ExternalPkg> externalPkgs = new ArrayList<ExternalPkg>();
    String settingsPath;
    Boolean disableNone;
    Boolean sortKeys;
    Boolean showHidden;
    Boolean includeSchemaTypePath;
    Boolean strictRangeCheck;
    Integer verbose;
    Integer debug;

    /**
     * Apply each option in order, mirroring kcl-go's {@code Option.Merge}.
     */
    void applyAll(List<KclOption> options) {
        for (KclOption option : options) {
            option.apply(this);
        }
    }

    /**
     * Materialise the bag into an {@link ExecProgramArgs} proto.
     *
     * <p>
     * When a settings file was recorded via
     * {@code Kcl.withSettings(String)}, it is parsed first and provides the
     * base set of fields; anything the caller populated explicitly through
     * other options is merged on top with kcl-go's {@code Merge} semantics:
     * repeated fields append, non-empty scalars overwrite (last wins), and
     * plain boolean fields only propagate when {@code true} (the zero value
     * means "not set").
     */
    ExecProgramArgs toExecProgramArgs() {
        Builder builder = ExecProgramArgs.newBuilder();
        String baseWorkDir = (workDir == null || workDir.isEmpty()) ? "." : workDir;
        if (settingsPath != null && !settingsPath.isEmpty()) {
            KclSettingsFile.load(settingsPath).applyTo(builder, baseWorkDir);
        }
        if (workDir != null && !workDir.isEmpty()) {
            builder.setWorkDir(workDir);
        }
        builder.addAllKFilenameList(kFilenameList);
        builder.addAllKCodeList(kCodeList);
        builder.addAllArgs(args);
        builder.addAllOverrides(overrides);
        builder.addAllPathSelector(selectors);
        builder.addAllExternalPkgs(externalPkgs);
        if (Boolean.TRUE.equals(disableNone)) {
            builder.setDisableNone(true);
        }
        if (Boolean.TRUE.equals(sortKeys)) {
            builder.setSortKeys(true);
        }
        if (Boolean.TRUE.equals(showHidden)) {
            builder.setShowHidden(true);
        }
        if (Boolean.TRUE.equals(includeSchemaTypePath)) {
            builder.setIncludeSchemaTypePath(true);
        }
        if (Boolean.TRUE.equals(strictRangeCheck)) {
            builder.setStrictRangeCheck(true);
        }
        if (verbose != null && verbose > 0) {
            builder.setVerbose(verbose);
        }
        if (debug != null && debug != 0) {
            builder.setDebug(debug);
        }
        return builder.build();
    }

    static List<String> strings(String... values) {
        return new ArrayList<String>(Arrays.asList(values));
    }
}
