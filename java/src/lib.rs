extern crate anyhow;
extern crate jni;
extern crate kcl_api;
extern crate kcl_parser;
extern crate kcl_sema;
extern crate lazy_static;
extern crate once_cell;
extern crate prost;

use anyhow::Result;
use jni::objects::{GlobalRef, JByteArray, JClass, JObject, JString};
use jni::sys::jbyteArray;
use jni::JNIEnv;
use jni::JavaVM;
use kcl_api::call_with_plugin_agent;
use kcl_api::gpyrpc::LoadPackageArgs;
use kcl_api::service::KclServiceImpl;
use kcl_parser::KCLModuleCache;
use kcl_sema::resolver::scope::KCLScopeCache;
use lazy_static::lazy_static;
use once_cell::sync::OnceCell;
use prost::Message;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::Mutex;

lazy_static! {
    static ref JVM: Mutex<Option<JavaVM>> = Mutex::new(None);
    static ref CALLBACK_OBJ: Mutex<Option<GlobalRef>> = Mutex::new(None);
    static ref MODULE_CACHE: Mutex<OnceCell<KCLModuleCache>> = Mutex::new(OnceCell::new());
    static ref SCOPE_CACHE: Mutex<OnceCell<KCLScopeCache>> = Mutex::new(OnceCell::new());
}

#[unsafe(no_mangle)]
pub extern "system" fn Java_com_kcl_api_API_callNative(
    mut env: JNIEnv,
    _: JClass,
    name: JByteArray,
    args: JByteArray,
) -> jbyteArray {
    intern_call_native_with_plugin(&mut env, name, args).unwrap_or_else(|e| {
        let _ = throw(&mut env, e);
        JObject::default().into_raw()
    })
}

#[unsafe(no_mangle)]
pub extern "system" fn Java_com_kcl_api_API_registerPluginContext(env: JNIEnv, obj: JObject) {
    let jvm = env.get_java_vm().unwrap();
    *JVM.lock().unwrap() = Some(jvm);
    let global_ref = env.new_global_ref(obj).unwrap();
    *CALLBACK_OBJ.lock().unwrap() = Some(global_ref);
}

#[unsafe(no_mangle)]
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

fn intern_call_native_with_plugin(
    env: &mut JNIEnv,
    name: JByteArray,
    args: JByteArray,
) -> Result<jbyteArray> {
    let name = env.convert_byte_array(name)?;
    let args = env.convert_byte_array(args)?;
    let result = call_with_plugin_agent(&name, &args, plugin_agent as u64)?;
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
    let args: LoadPackageArgs = LoadPackageArgs::decode(args.as_ref())?;
    let svc = KclServiceImpl::default();
    // Call load package API and decode the result to protobuf bytes.
    let packages = svc.load_package_with_cache(&args, module_cache.clone(), scope_cache.clone())?;
    let j_byte_array = env.byte_array_from_slice(&packages.encode_to_vec())?;
    Ok(j_byte_array.into_raw())
}

#[unsafe(no_mangle)]
extern "C" fn plugin_agent(
    method: *const c_char,
    args: *const c_char,
    kwargs: *const c_char,
) -> *const c_char {
    let jvm = JVM.lock().unwrap();
    let jvm = jvm.as_ref().unwrap();
    let mut env = jvm.attach_current_thread().unwrap();

    let callback_obj = CALLBACK_OBJ.lock().unwrap();
    let callback_obj = callback_obj.as_ref().unwrap();

    let method = unsafe {
        env.new_string(CStr::from_ptr(method).to_string_lossy().into_owned())
            .expect("Failed to create Java string")
    };
    let args = unsafe {
        env.new_string(CStr::from_ptr(args).to_string_lossy().into_owned())
            .expect("Failed to create Java string")
    };
    let kwargs = unsafe {
        env.new_string(CStr::from_ptr(kwargs).to_string_lossy().into_owned())
            .expect("Failed to create Java string")
    };
    let params = &[(&method).into(), (&args).into(), (&kwargs).into()];
    let result = env
        .call_method(
            callback_obj,
            "callMethod",
            "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;",
            params,
        )
        .unwrap();
    let result: JString = result.l().unwrap().into();
    let result: String = env.get_string(&result).unwrap().into();
    CString::new(result)
        .expect("Failed to create CString")
        .into_raw()
}

fn throw(env: &mut JNIEnv, error: anyhow::Error) -> jni::errors::Result<()> {
    env.throw(("java/lang/Exception", error.to_string()))
}
