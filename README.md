# Spring PetClinic — Projekt Dyplomowy DevOps

## Opis projektu

Projekt dyplomowy z zakresu DevOps realizowany na bazie aplikacji [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) — przykładowej aplikacji webowej napisanej w Java Spring Boot, służącej do zarządzania kliniką weterynaryjną.

Celem projektu było zbudowanie kompletnego środowiska produkcyjnego wokół istniejącej aplikacji — od automatyzacji infrastruktury, przez pipeline CI/CD, aż po monitoring. Kod aplikacji nie był modyfikowany. Całość pracy dyplomowej koncentruje się na warstwie DevOps.

---

## Zrealizowane wymagania

### Obowiązkowe ✅

| Wymaganie | Realizacja |
|---|---|
| Repozytorium z kodem aplikacji | Spring PetClinic (Java Spring Boot) |
| Infrastruktura jako kod (IaC) | Terraform — VPC, EKS, ECR, S3 backend |
| IaC idempotentna | `terraform apply` można wywołać wielokrotnie |
| IaC od zera w kilku komendach | `terraform init` + `terraform apply` |
| CI — budowanie na każdym branchu | GitHub Actions — `mvn package` + Docker build |
| CI — publikacja artefaktów | Push obrazu Docker do Amazon ECR |
| CD — deployment na main | `kubectl apply` na AWS EKS |
| Powiadomienia | Discord webhook — build i deploy |
| Dokumentacja | README z opisem projektu i struktury |
| Monitoring | Prometheus + Grafana (kube-prometheus-stack) |

### Opcjonalne ✅

| Ulepszenie | Realizacja |
|---|---|
| Konteneryzacja | Docker (multi-stage build) |
| Orkiestracja | Kubernetes (AWS EKS 1.29) |
| Skalowalność | 2 repliki aplikacji, rolling update |
| Testy wydajnościowe | JMeter (`src/test/jmeter/`) |
| Pełna automatyzacja | Monitoring instalowany automatycznie przez pipeline |

---

## Architektura

```
Developer                GitHub Actions               AWS
──────────               ──────────────          ──────────────
git push      →     1. mvn package           →   ECR (obrazy Docker)
                    2. docker build               EKS (klaster K8s)
                    3. push do ECR                S3 (stan Terraform)
                    4. terraform apply        ←   
                    5. kubectl apply          →   aplikacja działa
                    6. Discord powiadomienie
```

Infrastruktura działa na AWS w regionie `eu-west-1` (Irlandia) i składa się z:
- **VPC** z podsieciami publicznymi i prywatnymi w dwóch strefach dostępności
- **EKS** — zarządzany klaster Kubernetes z node'ami EC2 (t3.small)
- **ECR** — prywatny rejestr obrazów Docker
- **S3** — zdalny backend dla stanu Terraform współdzielony między laptopem a pipeline'em

Aplikacja uruchomiona jest w Kubernetes jako dwa deploymenty:
- `petclinic` — aplikacja Spring Boot (2 repliki, rolling update)
- `demo-db` — baza danych PostgreSQL 18

---

## Bezpieczeństwo

Wszystkie dane wrażliwe przechowywane są jako **GitHub Secrets** i nigdy nie trafiają do repozytorium:

| Secret | Opis |
|---|---|
| `AWS_ACCESS_KEY_ID` | Klucz dostępu AWS |
| `AWS_SECRET_ACCESS_KEY` | Sekretny klucz AWS |
| `DISCORD_WEBHOOK_URL` | URL webhooka Discord |

W pipeline odwoływanie się do sekretów wygląda następująco:
```yaml
env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

Dodatkowo plik `.gitignore` wyklucza z repozytorium:
- `terraform/.terraform/` — lokalne moduły Terraform
- `terraform/terraform.tfstate*` — stan infrastruktury
- `terraform/*.tfvars` — lokalne zmienne z potencjalnie wrażliwymi danymi

---

## Uruchomienie projektu

### Wymagania wstępne
- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) skonfigurowane z uprawnieniami AdministratorAccess
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/) >= 3.0
- Skonfigurowane GitHub Secrets (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `DISCORD_WEBHOOK_URL`)

### Postawienie infrastruktury
```bash
cd terraform
terraform init
terraform apply
```

### Konfiguracja kubectl
```bash
aws eks update-kubeconfig --region eu-west-1 --name petclinic-cluster
```

### Wdrożenie aplikacji
Pipeline wdraża aplikację automatycznie po każdym pushu na `main`. Ręcznie:
```bash
kubectl apply -f k8s/
```

### Zniszczenie infrastruktury
```bash
cd terraform
terraform destroy
```

### Skalowanie infrastruktury
```bash
./scale.sh
```

Interaktywny skrypt pyta o typ instancji, liczbę node'ów i replik, pokazuje szacowany koszt i wykonuje `terraform apply`.

---

## Pipeline CI/CD

### Każdy push (dowolna gałąź)
1. Budowanie aplikacji (`mvn package`)
2. Budowanie obrazu Docker
3. Push obrazu do Amazon ECR z tagiem SHA commita
4. Terraform Plan — zapisany jako artefakt (dostępny 30 dni)
5. Powiadomienie Discord o wyniku

### Push na `main` — dodatkowo
6. Terraform Apply — aktualizacja infrastruktury
7. Aktualizacja kubeconfig
8. Auto-update tagu obrazu w `k8s/petclinic.yml`
9. Deploy na EKS (`kubectl apply`)
10. Instalacja/aktualizacja monitoringu przez Helm
11. Oczekiwanie na zakończenie rolling update
12. Powiadomienie Discord o wdrożeniu

---

## Monitoring

Prometheus + Grafana instalowane automatycznie przez pipeline przy każdym wdrożeniu na `main`.

### Dostęp lokalny (port-forward)
```bash
export POD_NAME=$(kubectl --namespace monitoring get pod \
  -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=monitoring" -oname)
kubectl --namespace monitoring port-forward $POD_NAME 3000

# Otwórz: http://localhost:3000  (login: admin)
# Hasło:
kubectl --namespace monitoring get secrets monitoring-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d
```

### Dostęp produkcyjny
W środowisku produkcyjnym Grafana powinna być dostępna publicznie przez:
- **Ingress Controller** z dedykowanym adresem URL
- **SSL/TLS** przez AWS Certificate Manager
- **Autentykację** przez OAuth2 lub LDAP

Dostępne dashboardy:
- `Kubernetes / Compute Resources / Cluster` — ogólny stan klastra
- `Kubernetes / Compute Resources / Pod` — szczegóły podów
- `Kubernetes / Compute Resources / Node (Pods)` — zużycie zasobów

---

## Dostęp do aplikacji

### Lokalnie (port-forward)
```bash
kubectl port-forward svc/petclinic 8888:80
# Otwórz: http://localhost:8888
```

### Produkcyjnie
W środowisku produkcyjnym aplikacja powinna być dostępna publicznie przez:
- **AWS Load Balancer Controller** — automatyczne tworzenie ALB
- **Ingress** — jeden Load Balancer dla wielu aplikacji
- **SSL/TLS** przez AWS Certificate Manager
- **Route53** — własna domena (np. `https://petclinic.twojadomena.pl`)

---

## Zero Downtime Deployment

Aplikacja uruchomiona jest w dwóch replikach. Podczas wdrożenia nowej wersji Kubernetes stosuje rolling update — zastępuje repliki jedna po drugiej. Weryfikacja:

```bash
# Terminal 1
kubectl port-forward svc/petclinic 8888:80

# Terminal 2 — monitoring podczas deploymentu
while true; do
  echo "$(date '+%H:%M:%S') - $(curl -s -o /dev/null -w '%{http_code}' http://localhost:8888)"
  sleep 2
done
# Aplikacja zwraca 200 przez cały czas trwania deploymentu
```

---

## Struktura repozytorium

Pliki oznaczone 🔧 zostały stworzone w ramach projektu dyplomowego. Pozostałe pochodzą z oryginalnego repozytorium [spring-projects/spring-petclinic](https://github.com/spring-projects/spring-petclinic) i nie były modyfikowane.

```
.
├── 🔧 Dockerfile                           # Definicja obrazu Docker (multi-stage build)
├── 🔧 scale.sh                             # Interaktywny skrypt skalowania infrastruktury
├── 🔧 .github/
│   └── workflows/
│       └── ci-cd.yml                       # Pipeline CI/CD (GitHub Actions)
├── 🔧 terraform/
│   ├── main.tf                             # Infrastruktura (VPC, EKS, ECR, access entry)
│   ├── variables.tf                        # Zmienne konfiguracyjne i skalowanie
│   └── outputs.tf                          # Outputy (URL klastra, ECR itp.)
├── 🔧 k8s/
│   ├── petclinic.yml                       # Deployment + Service aplikacji
│   └── db.yml                              # Deployment PostgreSQL + Secret
│
│   ── Pliki oryginalne (nie modyfikowane) ──
│
├── docker-compose.yml                      # Lokalne uruchomienie z bazą danych
├── pom.xml                                 # Definicja zależności Maven
├── mvnw / mvnw.cmd                         # Maven wrapper (Linux/Windows)
├── .mvn/                                   # Konfiguracja Maven wrapper
└── src/                                    # Kod źródłowy aplikacji Java
    ├── main/java/                          # Kontrolery, modele, serwisy
    ├── main/resources/
    │   ├── application*.properties         # Konfiguracja aplikacji
    │   ├── db/                             # Skrypty SQL inicjalizacji bazy
    │   └── templates/                      # Szablony HTML (Thymeleaf)
    └── test/
        ├── java/                           # Testy jednostkowe i integracyjne
        └── jmeter/
            └── petclinic_test_plan.jmx     # Testy wydajnościowe JMeter
```

---

## Stos technologiczny

| Warstwa | Technologia |
|---|---|
| Aplikacja | Spring Boot 4.x (Java 17, Maven) |
| Baza danych | PostgreSQL 18 |
| Konteneryzacja | Docker (multi-stage build) |
| Rejestr obrazów | Amazon ECR |
| Orkiestracja | Kubernetes (AWS EKS 1.29) |
| Infrastruktura jako kod | Terraform |
| Stan infrastruktury | AWS S3 (zdalny backend) |
| CI/CD | GitHub Actions |
| Monitoring | Prometheus + Grafana (kube-prometheus-stack) |
| Powiadomienia | Discord webhook |

---

## Szacowane koszty AWS

| Scenariusz | Koszt |
|---|---|
| Development (klaster wyłączony) | ~$0/dzień |
| Klaster włączony (2x t3.small) | ~$3/dzień |
| Prezentacja (1-2 dni) | ~$6 łącznie |

Infrastruktura może być w całości zniszczona jedną komendą (`terraform destroy`) i postawiona od nowa przed prezentacją (`terraform apply`).
