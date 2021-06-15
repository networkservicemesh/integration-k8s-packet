// Copyright (c) 2020-2021 Doc.ai and/or its affiliates.
//
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at:
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package shell

import (
	"context"
	"errors"
	"io"
	"os"
	"os/exec"
	"strings"
	"sync"

	"github.com/sirupsen/logrus"
)

const (
	bufferSize     = 1 << 16
	successMessage = "gotestmd/pkg/suites/shell/Bash.const.successMessageIndicator"
	errorMessage   = "gotestmd/pkg/suites/shell/Bash.const.errorMessage"
	checkStatusCmd = `if [ $? -eq 0 ]; then
	echo ` + successMessage + `
else
	echo ` + errorMessage + `
fi`
	errEndCmd = `echo >&2 ` + successMessage
)

// Bash is api for bash procces
type Bash struct {
	Dir       string
	Env       []string
	once      sync.Once
	resources []io.Closer
	stdin     io.Writer
	stdout    io.Reader
	stderr    io.Reader
	ctx       context.Context
	cancel    context.CancelFunc
	cmd       *exec.Cmd
	logger    *logrus.Logger
}

// Close closses current bash process and all used resources
func (b *Bash) Close() {
	b.once.Do(b.init)
	b.cancel()
	_, _ = b.stdin.Write([]byte("exit 0\n"))
	_ = b.cmd.Wait()
	for _, r := range b.resources {
		_ = r.Close()
	}
}

func (b *Bash) init() {
	b.ctx, b.cancel = context.WithCancel(context.Background())
	p, err := exec.LookPath("bash")
	if err != nil {
		panic(err.Error())
	}
	if len(b.Env) == 0 {
		b.Env = os.Environ()
	}
	b.cmd = &exec.Cmd{
		Dir:  b.Dir,
		Env:  b.Env,
		Path: p,
	}

	stderr, err := b.cmd.StderrPipe()
	if err != nil {
		panic(err.Error())
	}
	b.resources = append(b.resources, stderr)
	b.stderr = stderr

	stdin, err := b.cmd.StdinPipe()
	if err != nil {
		panic(err.Error())
	}
	b.resources = append(b.resources, stdin)
	b.stdin = stdin

	stdout, err := b.cmd.StdoutPipe()
	if err != nil {
		panic(err.Error())
	}
	b.resources = append(b.resources, stdout)
	b.stdout = stdout

	err = b.cmd.Start()
	if err != nil {
		panic(err.Error())
	}
}

func (b *Bash) readPipe(pipe io.Reader) (result string, success bool, err error) {
	var buffer []byte = make([]byte, bufferSize)
	cur := 0
	for b.ctx.Err() == nil {
		// b.logger.WithField("func", "bash/stdoutHandler").Debug("read")
		n, err := pipe.Read(buffer[cur:])
		if err != nil {
			// b.logger.WithField("func", "bash/stdoutHandler").Debug("read err")
			return "", false, err
		}
		// b.logger.WithField("func", "bash/stdoutHandler").Debug("read OK")
		r := strings.TrimSpace(string(buffer[:cur+n]))
		if strings.HasSuffix(r, successMessage) {
			if len(r) > len(successMessage) {
				result = r[:len(r)-len("\n")-len(successMessage)]
			}
			success = true
			break
		}
		if strings.HasSuffix(r, errorMessage) {
			if len(r) > len(errorMessage) {
				result = r[:len(r)-len("\n")-len(errorMessage)]
			}
			break
		}
		cur += n
		if cur == bufferSize {
			return "", false, errors.New("read buffer overflow")
		}
	}
	return result, success, nil
}

// Run runs the cmd. Returs stdout and stderror as a result.
func (b *Bash) Run(s string) (stdout string, stderr string, success bool, err error) {
	b.once.Do(b.init)

	if b.ctx.Err() != nil {
		return "", "", false, b.ctx.Err()
	}

	_, err = b.stdin.Write([]byte(s + "\n"))
	if err != nil {
		return "", "", false, err
	}

	_, err = b.stdin.Write([]byte(checkStatusCmd + "\n"))
	if err != nil {
		return "", "", false, err
	}
	stdout, success, err = b.readPipe(b.stdout)
	if err != nil {
		return "", "", false, err
	}

	_, err = b.stdin.Write([]byte(errEndCmd + "\n"))
	if err != nil {
		return "", "", false, err
	}
	stderr, _, err = b.readPipe(b.stderr)
	if err != nil {
		return "", "", false, err
	}

	return stdout, stderr, success, nil
}
