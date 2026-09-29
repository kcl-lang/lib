import XCTest

@testable import KclLib

// Mirrors python/tests/plugin_test.py: register a plugin method, run KCL
// code that calls it through `import kcl_plugin.<name>`, and assert both the
// returned value and the failure protocol (a thrown closure surfaces in
// `err_message`).
final class PluginTests: XCTestCase {

  func testExecPlugin() throws {
    let context = PluginContext()
    var callCount = 0
    context.registerPlugin(
      "my_plugin",
      methods: [
        "add": { args, _ in
          callCount += 1
          let a = (args[0] as? NSNumber)?.intValue ?? 0
          let b = (args[1] as? NSNumber)?.intValue ?? 0
          return a + b
        }
      ])

    let api = API()
    api.attachPluginContext(context)
    defer { api.detachPluginContext() }

    var execArgs = ExecProgramArgs()
    execArgs.kFilenameList.append("test_data/plugin.k")
    let result = try api.execProgram(execArgs)
    XCTAssertEqual("result: 2", result.yamlResult)
    XCTAssertEqual(1, callCount, "the Swift closure must be invoked exactly once")
  }

  func testExecPluginError() throws {
    let context = PluginContext()
    context.registerPlugin(
      "my_plugin",
      methods: [
        "add": { _, _ in
          throw KclError.runtime("plugin error")
        }
      ])

    let api = API()
    api.attachPluginContext(context)
    defer { api.detachPluginContext() }

    var execArgs = ExecProgramArgs()
    execArgs.kFilenameList.append("test_data/plugin.k")
    let result = try api.execProgram(execArgs)
    XCTAssertTrue(
      result.errMessage.contains("plugin error"),
      "expected the thrown message in err_message, got \(result.errMessage)")
  }

  func testExecPluginKwargs() throws {
    let context = PluginContext()
    context.registerMethod(
      "my_plugin",
      name: "greet"
    ) { _, kwargs in
      let name = kwargs["name"] as? String ?? ""
      return "hello, \(name)"
    }

    let api = API()
    api.attachPluginContext(context)
    defer { api.detachPluginContext() }

    var execArgs = ExecProgramArgs()
    execArgs.kFilenameList.append("test_data/plugin_kwargs.k")
    let result = try api.execProgram(execArgs)
    XCTAssertEqual("result: hello, world", result.yamlResult)
  }

  func testFacadePluginContext() throws {
    let context = PluginContext()
    context.registerPlugin(
      "my_plugin",
      methods: [
        "add": { args, _ in
          ((args[0] as? NSNumber)?.intValue ?? 0) + ((args[1] as? NSNumber)?.intValue ?? 0)
        }
      ])

    var options = KclOptions()
    options.pluginContext = context
    // The facade borrows the process-wide plugin slot for the duration of
    // the run and releases it afterwards.
    let result = try Kcl.runFiles(["test_data/plugin.k"], options: options)
    XCTAssertEqual(2, result.get("result") as? Int)
  }
}
