package module

import "github.com/bytecodealliance/wasmtime-go/v22"

func copyStringToWasmMemory(
	store *wasmtime.Store,
	malloc *wasmtime.Func,
	memory *wasmtime.Memory,
	str string,
) (int32, int32, error) {
	bytes := []byte(str)
	length := len(bytes)
	// C str '\0'
	ptr, err := malloc.Call(store, int32(length)+1)
	if err != nil {
		return 0, 0, err
	}
	data := memory.UnsafeData(store)
	idx := ptr.(int32)
	copy(data[idx:(int(idx)+length)], bytes)
	// C str '\0'
	data[int(idx)+length] = 0
	return idx, int32(length), nil
}

func copyCStrFromWasmMemory(
	store *wasmtime.Store,
	memory *wasmtime.Memory,
	ptr int32,
) (string, int32, error) {
	data := memory.UnsafeData(store)
	end := ptr
	for data[end] != 0 {
		end++
	}
	result := string(data[ptr:end])
	return result, end + 1 - ptr, nil
}

func freeMemory(
	store *wasmtime.Store,
	free *wasmtime.Func,
	ptr int32,
	length int32,
) error {
	_, err := free.Call(store, ptr, length)
	return err
}
