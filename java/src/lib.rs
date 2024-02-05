extern crate anyhow;
extern crate jni;
extern crate kcl_lang;
extern crate lazy_static;
extern crate once_cell;

use anyhow::Result;
use jni::objects::{JByteArray, JClass, JObject};
use jni::sys::jbyteArray;
use jni::JNIEnv;
use lazy_static::lazy_static;
use once_cell::sync::OnceCell;
use std::sync::Mutex;

lazy_static! {
    static ref API_INSTANCE: Mutex<OnceCell<kcl_lang::API>> = Mutex::new(OnceCell::new());
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

fn intern_call_native(env: &mut JNIEnv, name: JByteArray, args: JByteArray) -> Result<jbyteArray> {
    let binding = API_INSTANCE.lock().unwrap();
    let api = binding.get_or_init(|| kcl_lang::API::new().expect("Failed to create API instance"));
    let name = env.convert_byte_array(name)?;
    let args = env.convert_byte_array(args)?;
    let result = api.call_native(&name, &args)?;
    let j_byte_array = env.byte_array_from_slice(&result)?;
    Ok(j_byte_array.into_raw())
}

fn throw(env: &mut JNIEnv, error: anyhow::Error) -> jni::errors::Result<()> {
    env.throw(("java/lang/Exception", error.to_string()))
}
