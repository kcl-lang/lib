# frozen_string_literal: true

require "minitest/autorun"

require "kcl_lib"

class FacadeTest < Minitest::Test
  # `api_test.rb` defines a top-level TEST_FILE constant; keep this one
  # class-local to avoid the "already initialized constant" warning.
  SCHEMA_FILE = "./test_data/schema.k"

  # -------------------------------------------------------------------------
  # Kcl.run / Kcl.run_files
  # -------------------------------------------------------------------------

  def test_run_with_code
    results = KclLib::Kcl.run("a = 1")
    assert_kind_of KclLib::KclResultList, results
    assert_equal 1, results.length
    assert_equal 1, results.first.get("a")
  end

  def test_run_with_files
    results = KclLib::Kcl.run_files(TEST_FILE)
    assert_equal 2, results.first.get("app.replicas")
  end

  def test_run_accepts_array_for_files
    results = KclLib::Kcl.run_files([TEST_FILE])
    assert_equal 2, results.first.get("app.replicas")
  end

  def test_run_raises_on_error
    error = assert_raises(KclLib::KclError) { KclLib::Kcl.run("a = undefined_name + 1") }
    assert_match(/name 'undefined_name' is not defined/, error.message)
  end

  def test_run_raises_on_missing_file
    assert_raises(KclLib::KclError) { KclLib::Kcl.run_files("file_not_found") }
  end

  def test_run_with_no_input_raises
    # A run with neither code nor files is a facade-level programming error.
    assert_raises(KclLib::KclError) { KclLib::Kcl.exec }
  end

  def test_run_with_overrides
    results = KclLib::Kcl.run_files(TEST_FILE, overrides: ["app.replicas=5"])
    assert_equal 5, results.first.get("app.replicas")
  end

  def test_run_with_args_string_form
    results = KclLib::Kcl.run('env = option("env")', args: ["env=prod"])
    assert_equal "prod", results.first.get("env")
  end

  def test_run_with_args_hash_form
    results = KclLib::Kcl.run('env = option("env")', args: [{ name: "env", value: "staging" }])
    assert_equal "staging", results.first.get("env")
  end

  def test_run_with_args_skips_malformed_specs
    # Mirrors kcl-go's `strings.Index(kv, "=") > 0` guard: entries without "="
    # or starting with "=" are dropped rather than raising.
    results = KclLib::Kcl.run('env = option("env")', args: ["no_equals", "=leading", "env=ok"])
    assert_equal "ok", results.first.get("env")
  end

  def test_run_with_sort_keys
    results = KclLib::Kcl.run("a = 2\nb = 1", sort_keys: true)
    assert_equal ["a", "b"], results.first.to_map.keys
  end

  def test_run_with_disable_none
    results = KclLib::Kcl.run("a = 1\nb = None", disable_none: true)
    refute results.first.to_map.key?("b")
  end

  def test_run_rejects_non_string_code
    assert_raises(KclLib::KclError) { KclLib::Kcl.run(42) }
  end

  def test_run_rejects_non_string_files
    assert_raises(KclLib::KclError) { KclLib::Kcl.run_files(42) }
  end

  # -------------------------------------------------------------------------
  # KclResult
  # -------------------------------------------------------------------------

  def test_result_get_dotted_path
    result = KclLib::Kcl.run("app = {replicas = 2, name = \"web\"}").first
    assert_equal 2, result.get("app.replicas")
    assert_equal "web", result.get("app.name")
  end

  def test_result_get_missing_path_returns_default
    result = KclLib::Kcl.run("a = 1").first
    assert_nil result.get("missing")
    assert_equal :fallback, result.get("a.b.c", :fallback)
  end

  def test_result_get_indexes_lists
    result = KclLib::Kcl.run("items = [{name = \"web\"}, {name = \"api\"}]").first
    assert_equal "web", result.get("items.0.name")
    assert_equal "api", result.get("items.1.name")
    assert_nil result.get("items.9.name")
  end

  def test_result_yaml_document
    result = KclLib::Kcl.run_files(TEST_FILE).first
    assert_equal "app:\n  replicas: 2", result.yaml_document
  end

  def test_result_to_map
    result = KclLib::Kcl.run("a = 1").first
    assert_equal({ "a" => 1 }, result.to_map)
  end

  def test_result_to_list_raises_on_non_list
    result = KclLib::Kcl.run("a = 1").first
    assert_raises(KclLib::KclError) { result.to_list }
  end

  # -------------------------------------------------------------------------
  # KclResult typed getters (mirrors kcl-go's Get(key, &target))
  # -------------------------------------------------------------------------

  def test_get_int
    result = KclLib::Kcl.run("a = 3").first
    assert_equal 3, result.get_int("a")
  end

  def test_get_int_raises_on_type_mismatch
    result = KclLib::Kcl.run('a = "x"').first
    error = assert_raises(KclLib::KclError) { result.get_int("a") }
    assert_match(/failed to convert/, error.message)
  end

  def test_get_int_raises_on_missing_path
    result = KclLib::Kcl.run("a = 3").first
    assert_raises(KclLib::KclError) { result.get_int("missing") }
  end

  def test_get_float_widens_int
    result = KclLib::Kcl.run("a = 3").first
    assert_in_delta 3.0, result.get_float("a")
  end

  def test_get_float_on_float
    result = KclLib::Kcl.run("a = 3.5").first
    assert_in_delta 3.5, result.get_float("a")
  end

  def test_get_str
    result = KclLib::Kcl.run('a = "hello"').first
    assert_equal "hello", result.get_str("a")
  end

  def test_get_bool
    result = KclLib::Kcl.run("a = True").first
    assert_equal true, result.get_bool("a")
  end

  def test_get_as_with_nested_path
    result = KclLib::Kcl.run("app = {replicas = 2}").first
    assert_equal 2, result.get_int("app.replicas")
  end

  def test_get_as_accepts_alternate_types
    result = KclLib::Kcl.run("a = True").first
    assert_equal true, result.get_as("a", [TrueClass, FalseClass])
  end

  def test_get_returns_nil_for_explicit_null
    result = KclLib::Kcl.run("a = None").first
    assert_nil result.get("a")
    # But the path does exist, so the strict getter finds it.
    assert_raises(KclLib::KclError) { result.get_int("a") }
  end

  def test_result_type_name
    assert_equal "map", KclLib::Kcl.run("a = 1").first.type_name
  end

  # -------------------------------------------------------------------------
  # KclResultList
  # -------------------------------------------------------------------------

  def test_result_list_first_and_last
    results = KclLib::Kcl.run_files(TEST_FILE)
    assert_equal results[0], results.first
    assert_equal results[-1], results.last
  end

  def test_result_list_is_an_array
    results = KclLib::Kcl.run_files(TEST_FILE)
    assert_kind_of Array, results
    assert_kind_of KclLib::KclResult, results.map(&:itself).first
  end

  # -------------------------------------------------------------------------
  # Kcl.validate
  # -------------------------------------------------------------------------

  def test_validate_success
    code = "schema Person:\n    name: str\n    age: int\n    check:\n        0 < age < 120\n"
    assert KclLib::Kcl.validate(code, '{"name": "Alice", "age": 10}')
  end

  def test_validate_raises_on_check_failure
    code = "schema Person:\n    name: str\n    age: int\n    check:\n        0 < age < 120\n"
    error = assert_raises(KclLib::KclError) do
      KclLib::Kcl.validate(code, '{"name": "Alice", "age": 1110}')
    end
    refute_empty error.message
  end

  def test_validate_with_yaml_format
    code = "schema Person:\n    name: str\n"
    assert KclLib::Kcl.validate(code, "name: Alice", format: "yaml")
  end

  # -------------------------------------------------------------------------
  # Kcl.split_documents
  # -------------------------------------------------------------------------

  def test_split_documents
    assert_equal ["a: 1", "b: 2"], KclLib::Kcl.split_documents("a: 1\n---\nb: 2\n")
  end

  def test_split_documents_allows_trailing_space
    assert_equal ["a: 1", "c: 3"], KclLib::Kcl.split_documents("a: 1\n--- \nc: 3")
  end

  def test_split_documents_allows_comment
    assert_equal ["a: 1", "c: 3"], KclLib::Kcl.split_documents("a: 1\n--- # trailing\nc: 3")
  end

  def test_split_documents_empty
    assert_equal [], KclLib::Kcl.split_documents("")
    assert_equal [], KclLib::Kcl.split_documents(nil)
  end

  def test_split_documents_drops_empty_documents
    assert_equal ["a: 1"], KclLib::Kcl.split_documents("---\na: 1\n---\n")
  end

  def test_split_documents_single_document
    assert_equal ["a: 1"], KclLib::Kcl.split_documents("a: 1")
  end

  def test_split_documents_raises_on_content_after_separator
    error = assert_raises(KclLib::KclError) do
      KclLib::Kcl.split_documents("a: 1\n--- b: 2\n")
    end
    assert_match(/invalid document separator/, error.message)
  end

  def test_split_documents_handles_crlf
    assert_equal ["a: 1", "b: 2"], KclLib::Kcl.split_documents("a: 1\r\n---\r\nb: 2\r\n")
  end
end
