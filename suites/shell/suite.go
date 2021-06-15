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

// Package shell provides shell helpers and shell based suites
package shell

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/sirupsen/logrus"
	"github.com/stretchr/testify/require"
	"github.com/stretchr/testify/suite"
)

// Suite is testify suite that provides a shell helper functions for each test.
// For each test generates a unique folder.
// Shell for each test located in the unique test folder.
type Suite struct {
	suite.Suite
}

// Runner creates runner and sets a passed dir and envs
func (s *Suite) Runner(dir string, env ...string) *Runner {
	result := &Runner{
		t: s.T(),
	}
	result.bash.Dir = filepath.Join(findRoot(), dir)
	result.bash.Env = env
	s.T().Cleanup(func() {
		result.logger.Debug("runner: " + result.bash.Dir + ": result.bash.Close()")
		result.bash.Close()
	})
	result.logger = &logrus.Logger{
		Out:   os.Stderr,
		Level: logrus.DebugLevel,
		Formatter: &logrus.TextFormatter{
			DisableQuote: true,
		},
	}
	result.bash.logger = result.logger
	return result
}

func findRoot() string {
	wd, err := os.Getwd()
	if err != nil {
		logrus.Fatal(err.Error())
	}
	currDir := wd
	for len(currDir) > 0 {
		if err != nil {
			logrus.Fatal(err.Error())
		}
		p := filepath.Clean(filepath.Join(currDir, "go.mod"))
		if _, err := os.Open(p); err == nil {
			return currDir
		}
		currDir = filepath.Dir(currDir)
	}
	return ""
}

// Runner is shell runner.
type Runner struct {
	t      *testing.T
	logger *logrus.Logger
	bash   Bash
}

// Dir returns the directory where located current runner intstance
func (r *Runner) Dir() string {
	return r.bash.Dir
}

// Run runs cmd logs stdout, stderror, stdin
// Tries to run cmd on fail during timeout.
// Test could fail on the error or achieved cmd timeout.
func (r *Runner) Run(cmd string) {
	timeoutCh := time.After(time.Minute)
	for {
		r.logger.WithField(r.t.Name(), "stdin").Info(cmd)
		runResult, err := r.bash.Run(cmd)
		require.NoError(r.t, err)
		if runResult.Stdout != "" {
			r.logger.WithField(r.t.Name(), "stdout").Info(runResult.Stdout)
		}
		if runResult.Stderr != "" {
			r.logger.WithField(r.t.Name(), "stderr").Info(runResult.Stderr)
		}
		if runResult.ExitCode == 0 && runResult.Stderr == "" {
			return
		}
		r.logger.WithField(r.t.Name(), "exitCode").Info(runResult.ExitCode)
		select {
		case <-timeoutCh:
			r.logger.Fatal("timeout reached but the command didn't succeed")
			r.t.FailNow()
		default:
			time.Sleep(time.Millisecond * 100)
		}
	}
}
