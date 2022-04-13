// Copyright (c) 2020-2022 Doc.ai and/or its affiliates.
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
	"github.com/networkservicemesh/integration-tests/suites/observability"
	"github.com/networkservicemesh/integration-tests/suites/sriov"
)

func TestMemory(t *testing.T) {
	suite.Run(t, new(memory.Suite))
}

func TestSRIOV(t *testing.T) {
	f := flag.Lookup("gotestmd.t")
	require.NoError(t, flag.Set("gotestmd.t", "10m"))
	defer func() { _ = flag.Set("gotestmd.t", f.Value.String()) }()
	suite.Run(t, new(sriov.Suite))
}

func TestMultiForwarder(t *testing.T) {
	f := flag.Lookup("gotestmd.t")
	require.NoError(t, flag.Set("gotestmd.t", "10m"))
	defer func() { _ = flag.Set("gotestmd.t", f.Value.String()) }()
	suite.Run(t, new(multiforwarder.Suite))
}

func TestHeal(t *testing.T) {
	suite.Run(t, new(heal.Suite))
}

func TestRunObservabilitySuite(t *testing.T) {
	suite.Run(t, new(observability.Suite))
}
