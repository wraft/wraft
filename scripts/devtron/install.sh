#!/bin/bash

# kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-Storages.yaml

helm repo add devtron https://helm.devtron.ai

helm install devtron devtron/devtron-operator \
--create-namespace --namespace devtroncd \
--set components.devtron.service.type=NodePort

kubectl -n devtroncd get secret devtron-secret -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d
export nodeport=$(kubectl get svc -n devtroncd devtron-service -o jsonpath="{.spec.ports[0].nodePort}")
http://HOST_IP:$nodeport/dashboard
