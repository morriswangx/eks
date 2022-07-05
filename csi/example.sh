git clone https://github.com/kubernetes-sigs/aws-efs-csi-driver.git
cd aws-efs-csi-driver/examples/kubernetes/multiple_pods/
FILESYSTEMID=$(aws efs describe-file-systems --query "FileSystems[*].FileSystemId" --output text)

