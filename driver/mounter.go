/*
   Copyright 2019 Tuxera Oy. All Rights Reserved.

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.

*/

/*
 * courtesy: https://github.com/digitalocean/csi-digitalocean/blob/master/driver/mounter.go
 */

package driver

import (
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

type Mounter interface {
	// Mount a volume
	Mount(sourcePath string, destPath, mountType string, opts ...string) error

	// Unmount a volume
	UMount(destPath string) error

	// IsMounted checks whether the target path is a correct mount (i.e:
	// propagated). It returns true if it's mounted. An error is returned in
	// case of system errors or if it's mounted incorrectly.
	IsMounted(target string) (bool, error)
}

type mounter struct {
}

type findmntResponse struct {
	FileSystems []fileSystem `json:"filesystems"`
}

type fileSystem struct {
	Target      string `json:"target"`
	Propagation string `json:"propagation"`
	FsType      string `json:"fstype"`
	Options     string `json:"options"`
}

/*
 * Mounts the mooseFs filesystem
 *
 *
 */

func (m *mounter) Mount(sourcePath, destPath, mountType string, opts ...string) error {
	mountCmd := "mount"
	mountArgs := []string{}

	if sourcePath == "" {
		return errors.New("source is not specified for mounting the volume")
	}

	if destPath == "" {
		return errors.New("Destination path is not specified for mounting the volume")
	}

	mountArgs = append(mountArgs, "-t", mountType)
	if len(opts) > 0 {
		mountArgs = append(mountArgs, "-o", strings.Join(opts, ","))
	}

	mountArgs = append(mountArgs, sourcePath)
	mountArgs = append(mountArgs, destPath)

	// create target, os.Mkdirall is noop if it exists
	err := os.MkdirAll(destPath, 0750)
	if err != nil {
		return err
	}

	out, err := exec.Command(mountCmd, mountArgs...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("mounting failed: %v cmd: '%s %s' output: %q",
			err, mountCmd, strings.Join(mountArgs, " "), string(out))
	}

	return nil
}

/*
 * Un-Mount the moooseFs filesystem
 *
 *
 *
 *
 */

func (m *mounter) UMount(destPath string) error {
	umountCmd := "umount"
	umountArgs := []string{}

	if destPath == "" {
		return errors.New("Destination path not specified for unmounting volume")
	}

	umountArgs = append(umountArgs, destPath)

	out, err := exec.Command(umountCmd, umountArgs...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("mounting failed: %v cmd: '%s %s' output: %q",
			err, umountCmd, strings.Join(umountArgs, " "), string(out))
	}

	return nil
}

/*
 *	Checks if the given target path is mounted
 *
 *
 *	courtesy: https://github.com/digitalocean/csi-digitalocean/blob/master/driver/mounter.go
 */

 func (m *mounter) IsMounted(target string) (bool, error) {
	if target == "" {
		return false, errors.New("target is not specified for checking the mount")
	}

	findmntCmd := "findmnt"
	_, err := exec.LookPath(findmntCmd)
	if err != nil {
		if err == exec.ErrNotFound {
			return false, fmt.Errorf("%q executable not found in $PATH", findmntCmd)
		}
		return false, err
	}

	findmntArgs := []string{"-o", "TARGET,PROPAGATION,FSTYPE,OPTIONS", "-M", target, "-J"}

	out, err := exec.Command(findmntCmd, findmntArgs...).CombinedOutput()
	if err != nil {
		// findmnt exits with non zero exit status if it couldn't find anything
		if strings.TrimSpace(string(out)) == "" {
			return false, nil
		}

		return false, fmt.Errorf("checking mounted failed: %v cmd: %q output: %q",
			err, findmntCmd, string(out))
	}

	// no response means there is no mount
	if string(out) == "" {
		return false, nil
	}

	var resp *findmntResponse
	err = json.Unmarshal(out, &resp)
	if err != nil {
		return false, fmt.Errorf("couldn't unmarshal data: %q: %s", string(out), err)
	}

	targetFound := false
	for _, fs := range resp.FileSystems {
		// check if the mount is propagated correctly. It should be set to shared.
		if fs.Propagation != "shared" {
			return true, fmt.Errorf("mount propagation for target %q is not enabled", target)
		}

		// the mountpoint should match as well
		if fs.Target == target {
			targetFound = true
		}
	}

	return targetFound, nil
}