// Copyright (c) 2020-2021 Doc.ai and/or its affiliates.
//
// Copyright (c) 2021 Nordix Foundation.
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
	"flag"
	"testing"

	"github.com/stretchr/testify/require"
	"github.com/stretchr/testify/suite"

	"github.com/networkservicemesh/integration-tests/suites/heal"
	"github.com/networkservicemesh/integration-tests/suites/memory"
	"github.com/networkservicemesh/integration-tests/suites/multiforwarder"
	"github.com/networkservicemesh/integration-tests/suites/ovs"
	"github.com/networkservicemesh/integration-tests/suites/sriov"
)

func TestMemory(t *testing.T) {
	suite.Run(t, new(memory.Suite))
}

func TestSRIOV(t *testing.T) {
	suite.Run(t, new(sriov.Suite))
}

func TestOVS(t *testing.T) {
	f := flag.Lookup("testify.m")
	require.NoError(t, flag.Set("testify.m", "TestKernel2Kernel"))
	defer func() { _ = flag.Set("testify.m", f.Value.String()) }()
	suite.Run(t, new(ovs.Suite))
}

func TestMultiForwarder(t *testing.T) {
	suite.Run(t, new(multiforwarder.Suite))
}

func TestHeal(t *testing.T) {
	suite.Run(t, new(heal.Suite))
}
