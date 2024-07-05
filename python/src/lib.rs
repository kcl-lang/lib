use pyo3::exceptions::PyException;
use pyo3::prelude::*;

/// Call KCL API with the API name and argument protobuf bytes.
#[pyfunction]
fn call<'a>(name: &'a [u8], args: &'a [u8]) -> PyResult<Vec<u8>> {
    kclvm_api::call(name, args).map_err(|e| PyErr::new::<PyException, _>(e.to_string()))
}

/// Call KCL API with the API name and plugin agent address and
/// argument protobuf bytes.
#[pyfunction]
fn call_with_plugin_agent<'a>(
    name: &'a [u8],
    args: &'a [u8],
    plugin_agent: u64,
) -> PyResult<Vec<u8>> {
    kclvm_api::call_with_plugin_agent(name, args, plugin_agent)
        .map_err(|e| PyErr::new::<PyException, _>(e.to_string()))
}

/// A Python module implemented in Rust.
#[pymodule]
fn _kcl_lib(_py: Python, m: &PyModule) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(call, m)?)?;
    m.add_function(wrap_pyfunction!(call_with_plugin_agent, m)?)?;
    Ok(())
}
