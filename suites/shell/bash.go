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
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"

	"github.com/sirupsen/logrus"
)

const (
	bufferSize           = 1 << 16
	finishMessage        = "gotestmd/pkg/suites/shell/Bash.const.finish"
	cmdPrintStatusCode   = `echo -e \\n$?`
	cmdPrintStdoutFinish = `echo ` + finishMessage
	cmdPrintStderrFinish = `echo >&2 ` + finishMessage
)

// Bash is api for bash procces
type Bash struct {
	Dir            string
	Env            []string
	once           sync.Once
	resources      []io.Closer
	stdin          io.Writer
	stdout         io.Reader
	stderr         io.Reader
	ctx            context.Context
	cancel         context.CancelFunc
	cmd            *exec.Cmd
	logger         *logrus.Logger
	pipeReadBuffer []byte
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
	b.pipeReadBuffer = make([]byte, bufferSize)
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

func (b *Bash) readUntilFinishMessage(pipe io.Reader) (string, error) {
	cur := 0
	for b.ctx.Err() == nil {
		n, err := pipe.Read(b.pipeReadBuffer[cur:])
		if err != nil {
			return "", err
		}
		result := strings.TrimSpace(string(b.pipeReadBuffer[:cur+n]))
		fmt.Println("read:", result)
		if strings.HasSuffix(result, finishMessage) {
			result = strings.TrimSpace(result[:len(result)-len(finishMessage)])
			return result, nil
		}
		cur += n
		if cur == len(b.pipeReadBuffer) {
			return "", errors.New("read buffer overflow")
		}
	}
	return "", b.ctx.Err()
}

// RunResult contains full result of an executed command
type RunResult struct {
	Stdout   string
	Stderr   string
	ExitCode int
}

// Run runs the command
func (b *Bash) Run(s string) (RunResult, error) {
	b.once.Do(b.init)

	if b.ctx.Err() != nil {
		return RunResult{}, b.ctx.Err()
	}

	_, err := b.stdin.Write([]byte(s + "\n"))
	if err != nil {
		return RunResult{}, err
	}

	_, err = b.stdin.Write([]byte(cmdPrintStatusCode + "\n"))
	if err != nil {
		return RunResult{}, err
	}

	_, err = b.stdin.Write([]byte(cmdPrintStdoutFinish + "\n"))
	if err != nil {
		return RunResult{}, err
	}

	stdout, err := b.readUntilFinishMessage(b.stdout)
	if err != nil {
		return RunResult{}, err
	}

	lastLineBreak := strings.LastIndex(stdout, "\n")
	var exitCodeString string
	if lastLineBreak == -1 {
		fmt.Println("line break not found")
		exitCodeString = stdout
		stdout = ""
	} else {
		fmt.Println("line break found!")
		exitCodeString = stdout[(lastLineBreak + 1):]
		stdout = strings.TrimSpace(stdout[:lastLineBreak])
	}
	fmt.Println("exit code string:", exitCodeString)
	exitCode64, err := strconv.ParseInt(exitCodeString, 0, 9)
	if err != nil {
		return RunResult{}, err
	}

	_, err = b.stdin.Write([]byte(cmdPrintStderrFinish + "\n"))
	if err != nil {
		return RunResult{}, err
	}
	stderr, err := b.readUntilFinishMessage(b.stderr)
	if err != nil {
		return RunResult{}, err
	}

	result := RunResult{
		Stdout:   stdout,
		Stderr:   stderr,
		ExitCode: int(exitCode64),
	}
	return result, nil
}
