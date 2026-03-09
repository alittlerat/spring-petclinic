# Spring PetClinic — DevOps Diploma Project

Projekt dyplomowy z zakresu DevOps. Aplikacja [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) wdrożona na infrastrukturze AWS EKS z pełnym pipeline'em CI/CD, monitoringiem oraz automatyzacją infrastruktury jako kod (IaC).

## Stos technologiczny

| Warstwa | Technologia |
|---|---|
| Aplikacja | Spring Boot (Java 17, Maven) |
| Baza danych | PostgreSQL |
| Konteneryzacja | Docker |
| Rejestr obrazów | Amazon ECR |
| Orkiestracja | Kubernetes (AWS EKS) |
| Infrastruktura jako kod | Terraform |
| CI/CD | GitHub Actions |
| Monitoring | Prometheus + Grafana |
| Powiadomienia | Discord |

## Struktura repozytorium

```
.
├── Dockerfile                           # Definicja obrazu Docker aplikacji
├── docker-compose.yml                   # Lokalne uruchomienie z bazą danych
├── .github/
│   └── workflows/
│       └── ci-cd.yml                    # Pipeline CI/CD (GitHub Actions)
├── terraform/
│   ├── main.tf                          # Definicja infrastruktury (VPC, EKS, ECR)
│   ├── variables.tf                     # Zmienne — tutaj konfigurujesz skalowanie
│   └── outputs.tf                       # Outputy Terraform (URL klastra, ECR itp.)
├── k8s/
│   ├── petclinic.yml                    # Deployment + Service aplikacji
│   └── db.yml                           # Deployment PostgreSQL + Secret
└── src/                                 # Kod źródłowy aplikacji (nie modyfikowany)
    └── test/
        └── jmeter/
            └── petclinic_test_plan.jmx  # Testy wydajnościowe JMeter
```

## Szybki start

### Wymagania
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) skonfigurowane z odpowiednimi uprawnieniami
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)
- [Docker](https://docs.docker.com/get-docker/)

### Uruchomienie lokalne (bez AWS)

```bash
# Uruchom aplikację z bazą PostgreSQL lokalnie
docker compose up

# Aplikacja dostępna pod: http://localhost:8080
```

### Wdrożenie na AWS

#### 1. Sklonuj repozytorium
```bash
git clone https://github.com/alittlerat/spring-petclinic.git
cd spring-petclinic
```

#### 2. Postaw infrastrukturę
```bash
cd terraform
terraform init
terraform apply
```

Terraform stworzy: VPC, EKS klaster, ECR repozytorium. Czas: ~10-15 minut.

#### 3. Skonfiguruj kubectl
```bash
aws eks update-kubeconfig --region eu-west-1 --name petclinic-cluster
```

#### 4. Wdróż aplikację
```bash
kubectl apply -f k8s/
```

#### 5. Zniszcz infrastrukturę
```bash
cd terraform
terraform destroy
```

## Pipeline CI/CD

### Każdy push (dowolna gałąź)
1. Budowanie aplikacji (`mvn package`)
2. Budowanie obrazu Docker
3. Push obrazu do Amazon ECR
4. Powiadomienie Discord o wyniku

### Push na `main`
Wszystko powyżej, dodatkowo:

5. Deployment na EKS (`kubectl apply`)
6. Powiadomienie Discord o wdrożeniu

## Skalowanie

Wszystkie parametry skalowania znajdują się w `terraform/variables.tf`:

| Zmienna | Domyślna wartość | Opis |
|---|---|---|
| `node_desired_size` | 1 | Docelowa liczba node'ów EKS |
| `node_min_size` | 1 | Minimalna liczba node'ów |
| `node_max_size` | 2 | Maksymalna liczba node'ów |
| `node_instance_type` | t3.medium | Typ instancji EC2 |
| `app_replicas` | 2 | Liczba replik aplikacji w Kubernetes |

Aby przeskalować, zmień wartości w `variables.tf` i wykonaj:
```bash
cd terraform
terraform apply
```

## Monitoring

Prometheus i Grafana zainstalowane przez Helm na klastrze EKS.

```bash
# Instalacja
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace

# Dostęp do Grafany (lokalnie przez port-forward)
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
# Otwórz: http://localhost:3000  (login: admin / prom-operator)
```

## Testy wydajnościowe

Projekt zawiera plan testów JMeter w `src/test/jmeter/petclinic_test_plan.jmx`.

```bash
# Uruchomienie testów (wymagany Apache JMeter)
jmeter -n -t src/test/jmeter/petclinic_test_plan.jmx -l results.jtl
```

## Szacowane koszty AWS

| Scenariusz | Koszt |
|---|---|
| Development (klaster wyłączony) | ~$0/dzień |
| Klaster włączony (1x t3.medium) | ~$5/dzień |
| Prezentacja (1-2 dni) | ~$10 łącznie |
