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

package main_test

import (
	"testing"

	"github.com/stretchr/testify/suite"

	"github.com/networkservicemesh/integration-tests/extensions/base"
	"github.com/networkservicemesh/integration-tests/suites/memory"
	"github.com/networkservicemesh/integration-tests/suites/multiforwarder"
	"github.com/networkservicemesh/integration-tests/suites/sriov"
)

func setupDeployments(t *testing.T) {
	// this function is a temporary workaround for the following issue:
	// https://github.com/networkservicemesh/integration-k8s-packet/issues/68

	baseSuite := base.Suite{}
	baseSuite.SetT(t)
	baseSuite.SetupSuite()

	r := baseSuite.Runner("../deployments-k8s/apps/forwarder-vpp")
	r.Run("sed -i 's/hostNetwork:\\ true/hostNetwork:\\ false/g' forwarder.yaml")
}

func TestMemory(t *testing.T) {
	setupDeployments(t)
	suite.Run(t, new(memory.Suite))
}

func TestSRIOV(t *testing.T) {
	suite.Run(t, new(sriov.Suite))
}

func TestMultiForwarder(t *testing.T) {
	setupDeployments(t)
	suite.Run(t, new(multiforwarder.Suite))
}
