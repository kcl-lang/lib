# An unused import is the lint diagnostic chosen for `lint_path_with_errors`
# because it is the one that needs neither a stdlib package to be downloaded
# nor a semantic error to be reported first: the check fires on the import
# statement itself, so the result is one line and it is the linter's, not the
# parser's.
#
# The kcl.mod beside it is load-bearing. Without a manifest the import does not
# resolve and the linter reports the unresolved package instead, which is a
# parser diagnostic wearing the linter's clothes -- the case would still pass
# `has_result`, but for the wrong reason, and a binding that dropped every
# result from a *resolvable* program would go unnoticed.
import regex

app = {name = "x"}
