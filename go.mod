module github.com/networkservicemesh/integration-k8s-packet

go 1.16

require (
	github.com/googleapis/gnostic v0.5.1 // indirect
	github.com/networkservicemesh/integration-tests v0.0.0-20220527083134-10ba1d22f919
	github.com/stretchr/testify v1.7.0
	gopkg.in/yaml.v2 v2.4.0 // indirect
)

replace github.com/networkservicemesh/integration-tests v0.0.0-20220527083134-10ba1d22f919 => github.com/glazychev-art/integration-tests v0.0.0-20220531123922-d4d28b217e76
