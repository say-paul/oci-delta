package main

import (
	"github.com/containers/oci-delta/cmd"
	"github.com/containers/storage/pkg/reexec"
	"github.com/containers/storage/pkg/unshare"
)

func main() {
	if reexec.Init() {
		return
	}
	unshare.MaybeReexecUsingUserNamespace(false)

	cmd.Execute()
}
