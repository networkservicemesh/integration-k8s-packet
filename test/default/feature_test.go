// Copyright (c) 2024 Cisco and/or its affiliates.
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

package default_test

import (
	"testing"

	"github.com/networkservicemesh/integration-tests/extensions/parallel"
	"github.com/networkservicemesh/integration-tests/suites/features"
)

func TestFeatureSuite(t *testing.T) {
	featuresSuite := new(features.Suite)
	parallel.Run(t, featuresSuite,
		parallel.WithRunningTestsSynchronously(
			featuresSuite.TestVl3_ipv6,
			featuresSuite.TestVl3_dns,
			featuresSuite.TestVl3_lb,
			featuresSuite.TestVl3_scale_from_zero,
			featuresSuite.TestScale_from_zero,
			featuresSuite.TestSelect_forwarder))
}
