// Copyright (c) 2020-2022 Doc.ai and/or its affiliates.
//
// Copyright (c) 2023 Cisco and/or its affiliates.
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

package main_test

import (
	"testing"

	"github.com/stretchr/testify/suite"

	"github.com/networkservicemesh/integration-tests/extensions/parallel"
	"github.com/networkservicemesh/integration-tests/suites/features"
	"github.com/networkservicemesh/integration-tests/suites/heal"
	"github.com/networkservicemesh/integration-tests/suites/memory"
	"github.com/networkservicemesh/integration-tests/suites/multiforwarder_vlantag"
	"github.com/networkservicemesh/integration-tests/suites/observability"
	"github.com/networkservicemesh/integration-tests/suites/sriov_vlantag"
)

func TestMemory(t *testing.T) {
	parallel.Run(t, new(memory.Suite))
}

func TestSRIOV_VlanTag(t *testing.T) {
	suite.Run(t, new(sriov_vlantag.Suite))
}

func TestMultiForwarder_VlanTag(t *testing.T) {
	suite.Run(t, new(multiforwarder_vlantag.Suite))
}

func TestHeal(t *testing.T) {
	suite.Run(t, new(heal.Suite))
}

func TestRunObservabilitySuite(t *testing.T) {
	suite.Run(t, new(observability.Suite))
}

func TestFeatureSuite(t *testing.T) {
	featuresSuite := new(features.Suite)
	parallel.Run(t, featuresSuite,
		parallel.WithRunningTestsSynchronously(
			featuresSuite.TestVl3_dns,
			featuresSuite.TestVl3_scale_from_zero,
			featuresSuite.TestScale_from_zero,
			featuresSuite.TestSelect_forwarder))
}
