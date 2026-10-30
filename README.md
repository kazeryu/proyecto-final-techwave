# TechWave Solutions

Panel web de la empresa del proyecto. La misma imagen sirve en las dos ranuras
(blue y green). El Service apunta solo a una. Si la ranura nueva no pasa
`/health`, el script deshace el Deployment y el tráfico se queda donde estaba.

## Qué responde la aplicación

- `GET /` panel con la versión y la ranura que está sirviendo
- `GET /health` y `GET /version`
- `GET /api/services`
- `GET /metrics`

Si `OTEL_EXPORTER_OTLP_ENDPOINT` tiene valor, manda trazas al collector.

## Tests

```bash
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements-dev.txt
PYTHONPATH=app pytest tests -q
```

## Compose

```bash
docker compose up -d --build
```

- Aplicación: http://127.0.0.1:8080
- Grafana: http://127.0.0.1:3000 (admin / techwave-lab, o sin login)
- Prometheus: http://127.0.0.1:9090
- Jaeger: http://127.0.0.1:16686

```bash
docker compose stop
```

## Kubernetes en local

```bash
chmod +x scripts/*.sh
./scripts/demo-kind.sh
./scripts/release.sh --version 1.1.0
./scripts/release.sh --version 1.2.0 --fail
./scripts/rollback.sh
```

La aplicación queda en http://127.0.0.1:30080. `--fail` hace que `/health`
devuelva 500: el rollout no termina, se deshace y el Service no cambia.

El stack de monitorización del clúster está en `k8s/monitoring/` y se aplica
con `./scripts/apply-monitoring.sh`. Para ver Grafana y Jaeger uso Compose,
que es más cómodo.

## EKS

Región `eu-west-1`, perfil `devops-personal`. La cuenta por defecto de esta máquina
no puede crear una VPC y, además, no es la del proyecto.

```bash
cd terraform/bootstrap
terraform init && terraform apply

cd ../envs/prod
terraform init
terraform apply
aws eks update-kubeconfig --name techwave --region eu-west-1
```

El plano de control se cobra por hora aunque el clúster esté vacío. No hay NAT.
Cuando acabe la prueba:

```bash
terraform destroy
cd ../../bootstrap && terraform destroy
```

## GitHub Actions

En `main` corre los tests y publica la imagen en GHCR (`:sha`, `:1.0.0` y
`:latest`). El despliegue a EKS solo sale si se lanza el workflow a mano y
la variable `DEPLOY_ENABLED` vale `true`. Las claves van en los secretos del
repositorio: `AWS_ACCESS_KEY_ID` y `AWS_SECRET_ACCESS_KEY`.

El paquete de GHCR tiene que ser público para que los nodos puedan bajar la
imagen. Si se deja privado, hace falta un `imagePullSecret`.

## Secretos

`k8s/secret.yaml` lleva un token de la práctica, no una clave de verdad.
La contraseña de Grafana del clúster está en el Secret `grafana-admin`.
Terraform no guarda claves: el estado va a S3 cifrado y el lock a DynamoDB.
