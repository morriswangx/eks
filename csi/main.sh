export CLUSTERNAME=Cluster44
export CLUSTER_NAME=$CLUSTERNAME
export VPCID=vpc-0c4580d7a7874cf1c
export VPC_ID=$VPCID
export AWSREGION=us-east-2
export AWS_REGION=$AWSREGION
export ACCOUNTID=669892482971
export ACCOUNT_ID=$ACCOUNTID
export CSI_POLICY_NAME=AmazonEKS_EFS_CSI_Driver_Policy_$CLUSTERNAME
export CSI_ROLE_NAME=AmazonEKS_EFS_CSI_Driver_Role_$CLUSTERNAME
export CSI_SECURIT_GROUP=$CLUSTERNAME-EfsSecurityGroup
export AMAZON_IMAGE_REGISTRY=602401143452

sudo apt update

echo "Download the IAM policy document from GitHub"
curl -o iam-policy-example.json https://raw.githubusercontent.com/kubernetes-sigs/aws-efs-csi-driver/master/docs/iam-policy-example.json

echo "Create the policy. You can change AmazonEKS_EFS_CSI_Driver_Policy to a different name, but if you do, make sure to change it in later steps too."
aws iam create-policy \
    --policy-name $CSI_POLICY_NAME \
    --policy-document file://iam-policy-example.json

echo "Create an IAM role and attach the IAM policy to it. Annotate the Kubernetes service account with the IAM role ARN and the IAM role with the Kubernetes service account name. You can create the role using eksctl or the AWS CLI."

echo "a. Determine your cluster's OIDC provider URL. Replace my-cluster with your cluster name. If the output from the command is None, review the Prerequisites."
CLUSTER_OIDC_ID=$(./fun.sh)

echo "Create the role. You can change AmazonEKS_EFS_CSI_DriverRole to a different name, but if you do, make sure to change it in later steps too."
aws iam create-role \
  --role-name $CSI_ROLE_NAME \
  --assume-role-policy-document file://"trust-policy.json"

echo "Attach the IAM policy to the role. Replace 111122223333 with your account ID. If your cluster is in the AWS GovCloud (US-East) or AWS GovCloud (US-East) AWS Regions, then replace arn:aws: with arn:aws-us-gov: before running the following command."
aws iam attach-role-policy \
  --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/$CSI_POLICY_NAME \
  --role-name $CSI_ROLE_NAME

kubectl apply -f efs-service-account.yaml


echo "Install the Amazon EFS driver"


echo "Install the Amazon EFS CSI driver using Helm "
helm repo add aws-efs-csi-driver https://kubernetes-sigs.github.io/aws-efs-csi-driver/
helm repo update

helm upgrade -i aws-efs-csi-driver aws-efs-csi-driver/aws-efs-csi-driver \
    --namespace kube-system \
    --set image.repository=$AMAZON_IMAGE_REGISTRY.dkr.ecr.$AWS_REGION.amazonaws.com/eks/aws-efs-csi-driver \
    --set controller.serviceAccount.create=false \
    --set controller.serviceAccount.name=efs-csi-controller-sa

echo "\nnow checking\n"
kubectl get pod -n kube-system -l "app.kubernetes.io/name=aws-efs-csi-driver,app.kubernetes.io/instance=aws-efs-csi-driver"


echo "Create an Amazon EFS file system"
vpc_id=$(aws eks describe-cluster \
    --name $CLUSTER_NAME \
    --query "cluster.resourcesVpcConfig.vpcId" \
    --output text)

cidr_range=$(aws ec2 describe-vpcs \
    --vpc-ids $vpc_id \
    --query "Vpcs[].CidrBlock" \
    --output text)

echo "Create a security group. Replace the example values with your own."
security_group_id=$(aws ec2 create-security-group \
    --group-name $CSI_SECURIT_GROUP \
    --description "My EFS security group" \
    --vpc-id $vpc_id \
    --output text)

echo "Create an inbound rule that allows inbound NFS traffic from the CIDR for your cluster's VPC."
aws ec2 authorize-security-group-ingress \
    --group-id $security_group_id \
    --protocol tcp \
    --port 2049 \
    --cidr $cidr_range

echo "Create a file system. Replace region-code with the AWS Region that your cluster is in."
file_system_id=$(aws efs create-file-system \
    --region $AWS_REGION \
    --performance-mode generalPurpose \
    --query 'FileSystemId' \
    --output text)
kubectl get nodes
echo "ip-172-31-13-11.us-east-2.compute.internal" \
	"ip-172-31-13-75.us-east-2.compute.internal" \
	"ip-172-31-30-77.us-east-2.compute.internal" \
	"ip-172-31-37-9.us-east-2.compute.internal"

aws efs create-mount-target \
    --file-system-id $file_system_id \
    --subnet-id subnet-075deb112d5b80ba5 \
    --security-groups $security_group_id

aws efs create-mount-target \
    --file-system-id $file_system_id \
    --subnet-id subnet-0d6fe4188fafa4b0a \
    --security-groups $security_group_id



