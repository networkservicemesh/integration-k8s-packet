// Copyright (c) 2020-2022 Doc.ai and/or its affiliates.
//
// Copyright (c) 2023-2024 Cisco and/or its affiliates.
//
// Copyright (c) 2024 Pragmagic Inc. and/or its affiliates.
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

package calico_vpp_test

import (
	"testing"

	"github.com/stretchr/testify/suite"

	"github.com/networkservicemesh/integration-tests/extensions/parallel"
	"github.com/networkservicemesh/integration-tests/suites/features"
	"github.com/networkservicemesh/integration-tests/suites/heal"
	"github.com/networkservicemesh/integration-tests/suites/memory"
	"github.com/networkservicemesh/integration-tests/suites/multiforwarder"
	"github.com/networkservicemesh/integration-tests/suites/observability"
	"github.com/networkservicemesh/integration-tests/suites/sriov"
)

func TestMemory(t *testing.T) {
	parallel.Run(t, new(memory.Suite))
}

func TestSRIOV(t *testing.T) {
	suite.Run(t, new(sriov.Suite))
}

func TestMultiForwarder(t *testing.T) {
	suite.Run(t, new(multiforwarder.Suite))
}

func TestHeal(t *testing.T) {
	suite.Run(t, new(heal.Suite))
}

func TestRunObservabilitySuite(t *testing.T) {
	suite.Run(t, new(observability.Suite))
}

// Disabled tests:
// TestMutually_aware_nses - https://github.com/networkservicemesh/integration-k8s-kind/issues/627
type featuresSuite struct {
	features.Suite
}

func (s *featuresSuite) BeforeTest(suiteName, testName string) {
	if testName == "TestMutually_aware_nses" {
		s.T().Skip()
	}
}

func TestRunFeatureSuiteCalico(t *testing.T) {
	featSuite := new(featuresSuite)
	parallel.Run(t, featSuite,
		parallel.WithRunningTestsSynchronously(
			featSuite.TestVl3_dns,
			featSuite.TestVl3_scale_from_zero,
			featSuite.TestScale_from_zero,
			featSuite.TestSelect_forwarder))
}
