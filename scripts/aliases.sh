pcluster-create() { pcluster create-cluster --cluster-name="$1" --cluster-config=configs/cluster-config-wb.yaml}
pcluster-ssh() { pcluster ssh --cluster-name="$1" -i /Users/devin/devin.pastoor.pem }
pcluster-list() { pcluster list-clusters }
pcluster-desc() { pcluster describe-cluster --cluster-name="$1" }
pcluster-del() { pcluster delete-cluster --cluster-name="$1" }
