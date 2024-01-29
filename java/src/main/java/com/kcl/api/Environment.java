package com.kcl.api;

/**
 * Environment resolves environment-specific project metadata.
 */
public enum Environment {
    INSTANCE;

    public static final String UNKNOWN = "<unknown>";
    private String classifier = UNKNOWN;

    static {
        final StringBuilder classifier = new StringBuilder();
        final String os = System.getProperty("os.name").toLowerCase();
        if (os.startsWith("windows")) {
            classifier.append("windows");
        } else if (os.startsWith("mac")) {
            classifier.append("osx");
        } else {
            classifier.append("linux");
        }
        classifier.append("-");
        final String arch = System.getProperty("os.arch").toLowerCase();
        if (arch.equals("aarch64")) {
            classifier.append("aarch_64");
        } else {
            classifier.append("x86_64");
        }
        INSTANCE.classifier = classifier.toString();
    }

    /**
     * Returns the classifier of the compiled environment.
     *
     * @return The classifier of the compiled environment.
     */
    public static String getClassifier() {
        return INSTANCE.classifier;
    }
}
