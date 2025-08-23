# nexus-core
IaC and GitOps configurations

flux bootstrap github \
  --components-extra=image-reflector-controller,image-automation-controller \
  --owner=git-saj \
  --repository=nexus-core \
  --branch=main \
  --path=flux/clusters/nexus \
  --personal
