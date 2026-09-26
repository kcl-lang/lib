package main

import (
	"fmt"

	"github.com/kcl-lang/wasm-lib/pkg/module"
)

const source = `
schema Person:
  name: str

p = Person {name = "Alice"}`

func main() {
	m, err := module.New("../../kcl.wasm")
	if err != nil {
		panic(err)
	}
	result, err := m.Run(&module.RunOptions{
		Filename: "test.k",
		Source:   source,
	})
	if err != nil {
		panic(err)
	}
	fmt.Println("--- run ---")
	fmt.Println(result)

	result, err = m.Fmt(&module.FmtOptions{
		Source: source,
	})
	if err != nil {
		panic(err)
	}
	fmt.Println("--- fmt ---")
	fmt.Println(result)

	result, err = m.RunWithLogMessage(&module.RunWithLogMessageOptions{
		Filename: "test.k",
		Source:   source,
	})
	if err != nil {
		panic(err)
	}
	fmt.Println("--- run with log message ---")
	fmt.Println(result)

	version, err := m.Version()
	if err != nil {
		panic(err)
	}
	fmt.Println("--- version ---")
	fmt.Println(version)

	// PingArgs{value: "hello-kcl"}: field 1 (string) tag 0x0a, length 9.
	pingArgs := append([]byte{0x0a, 0x09}, []byte("hello-kcl")...)
	pingResult, err := m.Call(&module.CallOptions{
		MethodName: "KclService.Ping",
		Args:       pingArgs,
	})
	if err != nil {
		panic(err)
	}
	fmt.Println("--- call KclService.Ping ---")
	fmt.Printf("%q\n", pingResult)
}
