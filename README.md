# Spring PetClinic — DevOps Diploma Project

Projekt dyplomowy z zakresu DevOps. Aplikacja [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) wdrożona na infrastrukturze AWS EKS z pełnym pipeline'em CI/CD, monitoringiem oraz automatyzacją infrastruktury jako kod (IaC).

## Stos technologiczny

| Warstwa | Technologia |
|---|---|
| Aplikacja | Spring Boot 4.x (Java 17, Maven) |
| Baza danych | PostgreSQL 18 |
| Konteneryzacja | Docker |
| Rejestr obrazów | Amazon ECR |
| Orkiestracja | Kubernetes (AWS EKS 1.29) |
| Infrastruktura jako kod | Terraform |
| Stan infrastruktury | AWS S3 (zdalny backend) |
| CI/CD | GitHub Actions |
| Monitoring | Prometheus + Grafana (kube-prometheus-stack) |
| Powiadomienia | Discord webhook |

## Struktura repozytorium

Pliki oznaczone 🔧 zostały stworzone w ramach projektu dyplomowego. Pozostałe pliki pochodzą z oryginalnego repozytorium [spring-projects/spring-petclinic](https://github.com/spring-projects/spring-petclinic) i nie były modyfikowane.

```
.
├── 🔧 Dockerfile                           # Definicja obrazu Docker aplikacji
├── 🔧 scale.sh                             # Interaktywny skrypt skalowania infrastruktury
├── 🔧 .github/
│   └── workflows/
│       └── ci-cd.yml                       # Pipeline CI/CD (GitHub Actions)
├── 🔧 terraform/
│   ├── main.tf                             # Definicja infrastruktury (VPC, EKS, ECR)
│   ├── variables.tf                        # Zmienne — tutaj konfigurujesz skalowanie
│   └── outputs.tf                          # Outputy Terraform (URL klastra, ECR itp.)
├── 🔧 k8s/
│   ├── petclinic.yml                       # Deployment + Service aplikacji (zmodyfikowany)
│   └── db.yml                              # Deployment PostgreSQL + Secret
│
│   ── Pliki oryginalne (nie modyfikowane) ──
│
├── docker-compose.yml                      # Lokalne uruchomienie z bazą danych
├── pom.xml                                 # Definicja zależności i konfiguracja Maven
├── mvnw                                    # Maven wrapper (Linux/Mac)
├── mvnw.cmd                                # Maven wrapper (Windows)
├── .mvn/                                   # Konfiguracja Maven wrapper
└── src/                                    # Kod źródłowy aplikacji Java
    ├── main/
    │   ├── java/                           # Kod aplikacji (kontrolery, modele, serwisy)
    │   └── resources/
    │       ├── application*.properties     # Konfiguracja aplikacji
    │       ├── db/                         # Skrypty inicjalizacji bazy danych
    │       └── templates/                  # Szablony HTML (Thymeleaf)
    └── test/
        ├── java/                           # Testy jednostkowe i integracyjne
        └── jmeter/
            └── petclinic_test_plan.jmx     # Testy wydajnościowe JMeter
```

## Szybki start

### Wymagania
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) skonfigurowane z uprawnieniami AdministratorAccess
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/) >= 3.0
- [Docker](https://docs.docker.com/get-docker/)

### Uruchomienie lokalne (bez AWS)

```bash
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

Terraform stworzy: VPC, EKS klaster (2x t3.small), ECR repozytorium, S3 backend. Czas: ~15 minut.

#### 3. Skonfiguruj kubectl
```bash
aws eks update-kubeconfig --region eu-west-1 --name petclinic-cluster
```

#### 4. Wdróż aplikację
```bash
kubectl apply -f k8s/
```

#### 5. Zainstaluj monitoring
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace
```

#### 6. Zniszcz infrastrukturę
```bash
cd terraform
terraform destroy
```

## Pipeline CI/CD

### Każdy push (dowolna gałąź)
1. Budowanie aplikacji (`mvn package`)
2. Budowanie obrazu Docker
3. Push obrazu do Amazon ECR
4. Terraform Plan — zapisany jako artefakt (30 dni)
5. Powiadomienie Discord o wyniku

### Push na `main` — dodatkowo
6. Terraform Apply — aktualizacja infrastruktury
7. Deploy na EKS (`kubectl apply`)
8. Auto-update tagu obrazu w `k8s/petclinic.yml`
9. Instalacja/aktualizacja monitoringu przez Helm
10. Oczekiwanie na rollout (`kubectl rollout status`)
11. Powiadomienie Discord o wdrożeniu

## Skalowanie

Użyj interaktywnego skryptu:

```bash
./scale.sh
```

Skrypt pyta o typ instancji, liczbę node'ów i replik, pokazuje szacowany koszt, wykonuje `terraform plan` i pyta czy zastosować zmiany.

Parametry skalowania w `terraform/variables.tf`:

| Zmienna | Domyślna wartość | Opis |
|---|---|---|
| `node_desired_size` | 1 | Docelowa liczba node'ów EKS |
| `node_min_size` | 1 | Minimalna liczba node'ów |
| `node_max_size` | 2 | Maksymalna liczba node'ów |
| `node_instance_type` | t3.small | Typ instancji EC2 |
| `app_replicas` | 2 | Liczba replik aplikacji w Kubernetes |

## Monitoring

Prometheus + Grafana instalowane automatycznie przez pipeline przy każdym wdrożeniu.

Dostęp do Grafany:
```bash
export POD_NAME=$(kubectl --namespace monitoring get pod \
  -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=monitoring" -oname)
kubectl --namespace monitoring port-forward $POD_NAME 3000

# Otwórz: http://localhost:3000  (login: admin)
# Hasło:
kubectl --namespace monitoring get secrets monitoring-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d
```

Dostępne dashboardy:
- `Kubernetes / Compute Resources / Cluster` — ogólny stan klastra
- `Kubernetes / Compute Resources / Pod` — szczegóły podów
- `Kubernetes / Compute Resources / Node (Pods)` — zużycie zasobów na node'ach

## Weryfikacja ciągłości działania (zero downtime)

```bash
# Terminal 1 — port-forward
kubectl port-forward svc/petclinic 8888:80

# Terminal 2 — monitoring HTTP
while true; do
  echo "$(date '+%H:%M:%S') - $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8888)"
  sleep 2
done
```

Podczas rolling update aplikacja zawsze zwraca `200` dzięki 2 repliком.

## Testy wydajnościowe

```bash
jmeter -n -t src/test/jmeter/petclinic_test_plan.jmx -l results.jtl
```

## Szacowane koszty AWS

| Scenariusz | Koszt |
|---|---|
| Development (klaster wyłączony) | ~$0/dzień |
| Klaster włączony (2x t3.small) | ~$3/dzień |
| Prezentacja (1-2 dni) | ~$6 łącznie |
