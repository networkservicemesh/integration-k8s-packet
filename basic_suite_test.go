// Copyright (c) 2020 Doc.ai and/or its affiliates.
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

package main_test

import (
	"testing"

	"github.com/edwarnicke/exechelper"
	"github.com/sirupsen/logrus"
	"github.com/stretchr/testify/suite"

	"github.com/networkservicemesh/integration-k8s-packet/k8s"
	"github.com/networkservicemesh/integration-k8s-packet/k8s/require"
	"github.com/networkservicemesh/integration-k8s-packet/spire"
)

type BasicTestsSuite struct {
	suite.Suite
	options []*exechelper.Option
}

func (s *BasicTestsSuite) SetupSuite() {
	s.options = []*exechelper.Option{
		exechelper.WithStderr(logrus.StandardLogger().WriterLevel(logrus.WarnLevel)),
		exechelper.WithStdout(logrus.StandardLogger().WriterLevel(logrus.InfoLevel)),
	}

	s.Require().NoError(spire.Setup(s.options...))
}

func (s *BasicTestsSuite) TearDownSuite() {
	s.Require().NoError(spire.Delete(s.options...))
}

func (s *BasicTestsSuite) TearDownTest() {
	k8s.ShowLogs(s.options...)

	s.Require().NoError(exechelper.Run("kubectl delete serviceaccounts --all"))
	s.Require().NoError(exechelper.Run("kubectl delete services --all"))
	s.Require().NoError(exechelper.Run("kubectl delete deployment --all"))
	s.Require().NoError(exechelper.Run("kubectl delete pods --all --grace-period=0 --force"))
}

func (s *BasicTestsSuite) TestDeployAlpine() {
	defer require.NoRestarts(s.T())

	s.Require().NoError(exechelper.Run("kubectl apply -f ./deployments/alpine.yaml", s.options...))
	s.Require().NoError(exechelper.Run("kubectl wait --for=condition=ready pod -l app=alpine", s.options...))
}

func TestRunBasicSuite(t *testing.T) {
	suite.Run(t, &BasicTestsSuite{})
}
