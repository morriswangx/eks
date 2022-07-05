func(){
	val=$(aws eks describe-cluster --name $CLUSTERNAME --query cluster.identity.oidc.issuer --output text | cut -d'/' -f 5)
	echo $val
}
CLUSTER_OIDC_ID=$(func)
echo $CLUSTER_OIDC_ID
