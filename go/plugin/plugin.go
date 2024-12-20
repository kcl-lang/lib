//go:build cgo
// +build cgo

// Copyright The KCL Authors. All rights reserved.

package plugin

/*
#include <stdint.h>
#include <stdlib.h>

uint64_t kcl_go_plugin_get_proxy_func_ptr();
*/
import "C"
import (
	"encoding/json"
	"errors"
	"fmt"
)

//export kcl_go_plugin_proxy_func
func kcl_go_plugin_proxy_func(_method, _args_json, _kwargs_json *C.char) (result_json *C.char) {
	var method, args_json, kwargs_json string

	if _method != nil {
		method = C.GoString(_method)
	}
	if _args_json != nil {
		args_json = C.GoString(_args_json)
	}
	if _kwargs_json != nil {
		kwargs_json = C.GoString(_kwargs_json)
	}

	result := InvokeJson(method, args_json, kwargs_json)
	return c_String_new(result)
}

func GetInvokeJsonProxyPtr() uint64 {
	ptr := uint64(C.kcl_go_plugin_get_proxy_func_ptr())
	return ptr
}

func Invoke(method string, args []interface{}, kwargs map[string]interface{}) (result_json string) {
	var args_json, kwargs_json string

	if len(args) > 0 {
		d, err := json.Marshal(args)
		if err != nil {
			return JSONError(err)
		}
		args_json = string(d)
	}

	if kwargs != nil {
		d, err := json.Marshal(kwargs)
		if err != nil {
			return JSONError(err)
		}
		kwargs_json = string(d)
	}

	return _Invoke(method, args_json, kwargs_json)
}

func InvokeJson(method, args_json, kwargs_json string) (result_json string) {
	return _Invoke(method, args_json, kwargs_json)
}

func _Invoke(method, args_json, kwargs_json string) (result_json string) {
	defer func() {
		if r := recover(); r != nil {
			result_json = JSONError(errors.New(fmt.Sprint(r)))
		}
	}()

	// Check method name
	if method == "" {
		return JSONError(fmt.Errorf("empty method"))
	}

	// Parse args, kwargs
	args, err := ParseMethodArgs(args_json, kwargs_json)
	if err != nil {
		return JSONError(err)
	}

	// Get plugin method
	methodSpec, found := GetMethodSpec(method)
	if !found {
		return JSONError(fmt.Errorf("invalid method: %s, not found", method))
	}

	// Call plugin method
	result, err := methodSpec.Body(args)
	if err != nil {
		return JSONError(err)
	}
	if result == nil {
		result = new(MethodResult)
	}

	// Encode result to JSON
	data, err := json.Marshal(result.V)
	if err != nil {
		return JSONError(err)
	}

	return string(data)
}
