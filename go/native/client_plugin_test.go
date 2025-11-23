//go:build cgo
// +build cgo

package native

import (
	"strings"
	"testing"

	"kcl-lang.io/lib/go/api"
	"kcl-lang.io/lib/go/plugin"
)

func init() {
	// Add a plugin named hello
	plugin.RegisterPlugin(plugin.Plugin{
		Name: "hello",
		MethodMap: map[string]plugin.MethodSpec{
			"add": {
				Body: func(args *plugin.MethodArgs) (*plugin.MethodResult, error) {
					v := args.IntArg(0) + args.IntArg(1)
					return &plugin.MethodResult{V: v}, nil
				},
			},
		},
	})
}

func TestExecProgramWithPlugin(t *testing.T) {
	client := NewNativeServiceClient()
	result, err := client.ExecProgram(&api.ExecProgramArgs{
		KFilenameList: []string{"main.k"},
		KCodeList:     []string{code},
		Args: []*api.Argument{
			{
				Name:  "a",
				Value: "1",
			},
			{
				Name:  "b",
				Value: "2",
			},
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	if result.ErrMessage != "" {
		t.Fatal("error message must be empty")
	}
}

func TestExecProgramWithPluginError(t *testing.T) {
	client := NewNativeServiceClient()
	result, err := client.ExecProgram(&api.ExecProgramArgs{
		KFilenameList: []string{"main.k"},
		KCodeList:     []string{code},
	})
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(result.ErrMessage, "strconv.ParseInt: parsing \"<nil>\": invalid syntax") {
		t.Fatal(result.ErrMessage)
	}
}
