#!/bin/bash

kubectl -n devtroncd get secret devtron-secret -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d
export nodeport=$(kubectl get svc -n devtroncd devtron-service -o jsonpath="{.spec.ports[0].nodePort}")
echo "\n"
echo http://HOST_IP:$nodeport/dashboard
