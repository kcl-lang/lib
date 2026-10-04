# frozen_string_literal: true

# Ruby bindings for the KCL language core.
#
# The native extension (`KclLib.call` / `KclLib.call_with_plugin_agent`)
# dispatches every KCL RPC by name with protobuf-encoded request/response
# bytes. The error convention of the Rust dispatcher: error replies are
# prefixed with "ERROR:" (see docs/abi.md in the repository root).
require_relative "kcl_lib/kcl_ruby"
require_relative "kcl_lib/version"
require_relative "kcl_lib/spec_pb"
require_relative "kcl_lib/api"
require_relative "kcl_lib/facade"

# Re-export the generated protobuf message classes under the KclLib
# namespace, mirroring how `kcl_lib.api` re-exports them in Python, so both
# `KclLib::ExecProgramArgs` and `KclLib::API` are available from the top
# level require.
module KclLib
  include Com::Kcl::Api
end
