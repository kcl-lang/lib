# frozen_string_literal: true

require_relative "lib/kcl_lib/version"

Gem::Specification.new do |spec|
  spec.name = "kcl-lib"
  spec.version = KclLib::VERSION
  spec.authors = ["The KCL Authors"]
  spec.email = ["kcl-lang@googlegroups.com"]

  spec.summary = "KCL Ruby Lib"
  spec.description = "Ruby bindings for the KCL language core, speaking protobuf with the native runtime through a thin Rust FFI layer."
  spec.homepage = "https://kcl-lang.io/"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.1"

  # The gem currently ships as sources; run `make build` to compile the
  # native extension (`lib/kcl_lib/kcl_ruby.bundle`) before using it.
  spec.files = Dir["lib/**/*", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "google-protobuf", [">= 3.24", "< 5.0"]
end
