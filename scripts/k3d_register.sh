# create regisry
k3d registry create wraft-registry --port 5050

# create cluster using regisry
k3d cluster create omar-cluster -p "9900:80@loadbalancer"  --registry-use wraft-registry:5050 --registry-config registries.yaml

docker tag wraft-docs:latest localhost:5050/wraft-docs:v1.0

docker push localhost:5050/wraft-docs:v1.0

kubectl create deployment wraft-docs-server --image=wraft-registry:5050/wraft-docs:v1.0

kubectl create service clusterip wraft-docs-server --tcp=9091:9091

kubectl apply -f .\ingress.yaml