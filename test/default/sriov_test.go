// Copyright (c) 2024 Cisco and/or its affiliates.
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

package default_test

import (
	"testing"

	"github.com/stretchr/testify/suite"

	"github.com/networkservicemesh/integration-tests/suites/multiforwarder_vlantag"
	"github.com/networkservicemesh/integration-tests/suites/sriov_vlantag"
)

func TestSRIOV_VlanTag(t *testing.T) {
	suite.Run(t, new(sriov_vlantag.Suite))
}

func TestMultiForwarder_VlanTag(t *testing.T) {
	suite.Run(t, new(multiforwarder_vlantag.Suite))
}
