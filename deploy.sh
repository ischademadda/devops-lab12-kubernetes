#!/usr/bin/env bash
# Разворачивает всё с нуля на машине, где уже есть docker, minikube и kubectl.
# Повторный запуск безопасен (apply идемпотентен).
set -euo pipefail
cd "$(dirname "$0")"

APP_REPO="${APP_REPO:-https://github.com/ischademadda/devops-lab11-books-service.git}"
IMAGE="books-api:1.0"

# 1. Кластер
if ! minikube status >/dev/null 2>&1; then
  minikube start --driver=docker --cpus=2 --memory=3072mb
fi

# 2. Образ приложения из ЛР 11 собираем прямо внутри minikube (registry не нужен)
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone --depth 1 "$APP_REPO" "$tmp/app"
minikube image build -t "$IMAGE" "$tmp/app"

# 3. Приложение + БД, затем мониторинг
kubectl apply -f k8s/app/
kubectl apply -k k8s/monitoring

kubectl -n books rollout status statefulset/db --timeout=300s
kubectl -n books rollout status deployment/books-api --timeout=300s
kubectl -n monitoring rollout status deployment/prometheus --timeout=600s
kubectl -n monitoring rollout status deployment/grafana --timeout=600s

kubectl get pods -A
echo
echo "API:        http://$(minikube ip):30080   (kubectl proxy: /api/v1/namespaces/books/services/books-api:http/proxy/)"
echo "Prometheus: http://$(minikube ip):30090"
echo "Grafana:    http://$(minikube ip):30030   (admin / admin-lab12)"
