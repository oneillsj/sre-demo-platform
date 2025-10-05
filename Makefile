CLUSTER_NAME = sre-demo
IP ?= localhost

init: create build load

create:
	kind create cluster --name $(CLUSTER_NAME) --config kind-config.yaml

build:
	docker build -t flask-demo:v0.1 ./src

load:
	kind load docker-image flask-demo:v0.1 --name $(CLUSTER_NAME)

delete:
	kind delete cluster --name $(CLUSTER_NAME)

deploy-all: deploy-nginx deploy-flask-demo deploy-prometheus deploy-grafana

undeploy-all: undeploy-grafana undeploy-prometheus undeploy-flask-demo undeploy-nginx

deploy-nginx:
	kubectl apply -f infra/nginx/deployment.yaml
	kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx
	@echo "Waiting for NGINX admission webhook to be reachable..."; \
	for i in $$(seq 1 30); do \
		if kubectl get validatingwebhookconfigurations ingress-nginx-admission >/dev/null 2>&1; then \
			echo "✔ Webhook configuration found"; break; \
		else \
			echo "Waiting for ingress-nginx-admission webhook registration..."; \
			sleep 3; \
		fi; \
	done

undeploy-nginx:
	kubectl delete -f infra/nginx/deployment.yaml --ignore-not-found

deploy-flask-demo:
	kubectl apply -f apps/flask-demo/deployment.yaml
	kubectl apply -f apps/flask-demo/service.yaml
	kubectl apply -f apps/flask-demo/ingress.yaml

undeploy-flask-demo:
	kubectl delete -f apps/flask-demo/service.yaml --ignore-not-found
	kubectl delete -f apps/flask-demo/ingress.yaml --ignore-not-found
	kubectl delete -f apps/flask-demo/deployment.yaml --ignore-not-found --wait=false
	kubectl delete -f infra/nginx/deployment.yaml --ignore-not-found

deploy-prometheus:
	kubectl apply -f infra/monitoring/prometheus/deployment.yaml
	kubectl apply -f infra/monitoring/prometheus/configmap.yaml
	kubectl apply -f infra/monitoring/prometheus/service.yaml
	kubectl apply -f infra/monitoring/prometheus/ingress.yaml

undeploy-prometheus:
	kubectl delete -f infra/monitoring/prometheus/ingress.yaml --ignore-not-found
	kubectl delete -f infra/monitoring/prometheus/service.yaml --ignore-not-found
	kubectl delete -f infra/monitoring/prometheus/configmap.yaml --ignore-not-found
	kubectl delete -f infra/monitoring/prometheus/deployment.yaml --ignore-not-found

deploy-grafana:
	kubectl apply -f infra/monitoring/grafana/configmap.yaml
	kubectl apply -f infra/monitoring/grafana/deployment.yaml
	kubectl apply -f infra/monitoring/grafana/service.yaml
	kubectl apply -f infra/monitoring/grafana/ingress.yaml

undeploy-grafana:
	kubectl delete -f infra/monitoring/grafana/ingress.yaml --ignore-not-found
	kubectl delete -f infra/monitoring/grafana/service.yaml --ignore-not-found
	kubectl delete -f infra/monitoring/grafana/deployment.yaml --ignore-not-found
	kubectl delete -f infra/monitoring/grafana/configmap.yaml --ignore-not-found

test-all: test-flask test-prometheus test-grafana
	@echo "All tests executed!"

test-flask:
	@echo "Waiting for ingress-nginx-controller to be ready..."
	kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx
	@echo "Waiting for flask-demo pods to be ready..."
	kubectl rollout status deployment/flask-demo -n demo
	@echo "Testing app via Ingress on http://$(IP)/app"; \
	\
	if curl -sS http://$(IP)/app/healthz | grep -q "OK"; then \
		echo "✔ /healthz passed"; \
	else \
		echo "✘ /healthz failed"; exit 1; \
	fi; \
	\
	if curl -sS "http://$(IP)/app/compute?n=7" | grep -q '"result":49'; then \
		echo "✔ /compute passed"; \
	else \
		echo "✘ /compute failed"; exit 1; \
	fi; \
	\
	if curl -sS http://$(IP)/app/metrics | grep -q 'python_gc_objects_collected_total'; then \
		echo "✔ /metrics passed"; \
	else \
		echo "✘ /metrics failed"; exit 1; \
	fi

test-prometheus:
	@echo "Checking Prometheus scrape status for flask-demo..."; \
	RESP=$$(curl -s "http://$(IP)/prometheus/api/v1/query?query=up%7Bjob%3D%22flask-demo%22%7D"); \
	VALUE=$$(echo $$RESP | jq -r '.data.result[0].value[1] // empty'); \
	if [ "$$VALUE" = "1" ]; then \
		echo "✔ Prometheus is scraping flask-demo (up=1)"; \
	elif [ "$$VALUE" = "0" ]; then \
		echo "✘ Prometheus target found but not up (up=0)"; exit 1; \
	else \
		echo "✘ Prometheus query returned no result for job=flask-demo"; \
		echo $$RESP; exit 1; \
	fi

test-grafana:
	@echo "Checking Grafana health..."; \
	RESP=$$(curl -s "http://$(IP)/grafana/api/health"); \
	DB=$$(echo $$RESP | jq -r '.database // empty'); \
	if [ "$$DB" = "ok" ]; then \
		echo "✔ Grafana is healthy"; \
	else \
		echo "✘ Grafana health check failed"; \
		echo $$RESP; exit 1; \
	fi

.PHONY: create delete build load delete deploy-all undeploy-all test-all
