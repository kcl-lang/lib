extern crate anyhow;
extern crate jni;
extern crate kclvm_api;
extern crate kclvm_parser;
extern crate kclvm_sema;
extern crate lazy_static;
extern crate once_cell;
extern crate prost;

use anyhow::Result;
use jni::objects::{JByteArray, JClass, JObject};
use jni::sys::jbyteArray;
use jni::JNIEnv;
use kclvm_api::call;
use kclvm_api::gpyrpc::LoadPackageArgs;
use kclvm_api::service::KclvmServiceImpl;
use kclvm_parser::KCLModuleCache;
use kclvm_sema::resolver::scope::KCLScopeCache;
use lazy_static::lazy_static;
use once_cell::sync::OnceCell;
use prost::Message;
use std::sync::Mutex;

lazy_static! {
    static ref MODULE_CACHE: Mutex<OnceCell<KCLModuleCache>> = Mutex::new(OnceCell::new());
    static ref SCOPE_CACHE: Mutex<OnceCell<KCLScopeCache>> = Mutex::new(OnceCell::new());
}

#[no_mangle]
pub extern "system" fn Java_com_kcl_api_API_callNative(
    mut env: JNIEnv,
    _: JClass,
    name: JByteArray,
    args: JByteArray,
) -> jbyteArray {
    intern_call_native(&mut env, name, args).unwrap_or_else(|e| {
        let _ = throw(&mut env, e);
        JObject::default().into_raw()
    })
}

#[no_mangle]
pub extern "system" fn Java_com_kcl_api_API_loadPackageWithCache(
    mut env: JNIEnv,
    _: JClass,
    args: JByteArray,
) -> jbyteArray {
    intern_load_package_with_cache(&mut env, args).unwrap_or_else(|e| {
        let _ = throw(&mut env, e);
        JObject::default().into_raw()
    })
}

fn intern_call_native(env: &mut JNIEnv, name: JByteArray, args: JByteArray) -> Result<jbyteArray> {
    let name = env.convert_byte_array(name)?;
    let args = env.convert_byte_array(args)?;
    let result = call(&name, &args)?;
    let j_byte_array = env.byte_array_from_slice(&result)?;
    Ok(j_byte_array.into_raw())
}

/// This is a stateful API, so we avoid serialization overhead and directly use JVM
/// to instantiate global variables here.
fn intern_load_package_with_cache(env: &mut JNIEnv, args: JByteArray) -> Result<jbyteArray> {
    // AST module cache
    let binding = MODULE_CACHE.lock().unwrap();
    let module_cache = binding.get_or_init(|| KCLModuleCache::default());
    // Resolver scope cache
    let binding = SCOPE_CACHE.lock().unwrap();
    let scope_cache = binding.get_or_init(|| KCLScopeCache::default());
    // Load package arguments from protobuf bytes.
    let args = env.convert_byte_array(args)?;
    let args: LoadPackageArgs = <LoadPackageArgs as Message>::decode(args.as_ref())?;
    let svc = KclvmServiceImpl::default();
    // Call load package API and decode the result to protobuf bytes.
    let packages = svc.load_package_with_cache(&args, module_cache.clone(), scope_cache.clone())?;
    let j_byte_array = env.byte_array_from_slice(&packages.encode_to_vec())?;
    Ok(j_byte_array.into_raw())
}

fn throw(env: &mut JNIEnv, error: anyhow::Error) -> jni::errors::Result<()> {
    env.throw(("java/lang/Exception", error.to_string()))
}
