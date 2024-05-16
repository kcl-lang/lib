use pyo3::exceptions::PyException;
use pyo3::prelude::*;

/// Formats the sum of two numbers as string.
#[pyfunction]
fn call<'a>(name: &'a [u8], args: &'a [u8]) -> PyResult<Vec<u8>> {
    kcl_lang::call(name, args).map_err(|e| PyErr::new::<PyException, _>(e.to_string()))
}

/// A Python module implemented in Rust.
#[pymodule]
fn _kcl_lib(_py: Python, m: &PyModule) -> PyResult<()> {
    m.add_function(wrap_pyfunction!(call, m)?)?;
    Ok(())
}
