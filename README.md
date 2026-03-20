# Spring PetClinic — Projekt Dyplomowy DevOps

## Opis projektu

Projekt dyplomowy z zakresu DevOps realizowany na bazie aplikacji [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) — przykładowej aplikacji webowej napisanej w Java Spring Boot, służącej do zarządzania kliniką weterynaryjną.

Celem projektu było zbudowanie kompletnego środowiska produkcyjnego wokół istniejącej aplikacji — od automatyzacji infrastruktury, przez pipeline CI/CD, aż po monitoring. Kod aplikacji nie był modyfikowany. Całość pracy dyplomowej koncentruje się na warstwie DevOps.

---

## Architektura

```
Developer                GitHub                      AWS
──────────               ──────                 ──────────────
git push      →     GitHub Actions         →    ECR (rejestr obrazów)
                    buduje aplikację        →    EKS (klaster Kubernetes)
                    tworzy obraz Docker     →    Discord (powiadomienia)
                    aktualizuje k8s         →    S3 (stan infrastruktury)
```

Infrastruktura działa na AWS w regionie `eu-west-1` (Irlandia) i składa się z:
- **VPC** z podsieciami publicznymi i prywatnymi w dwóch strefach dostępności
- **EKS** — zarządzany klaster Kubernetes z grupą node'ów EC2
- **ECR** — prywatny rejestr obrazów Docker
- **S3** — zdalny backend dla stanu Terraform (współdzielony między laptopem a pipeline'em)

Aplikacja uruchomiona jest w Kubernetes jako dwa deploymenty:
- `petclinic` — aplikacja Spring Boot (2 repliki)
- `demo-db` — baza danych PostgreSQL

---

## Co zostało zrealizowane

### Infrastruktura jako kod (IaC)
Cała infrastruktura AWS opisana jest w Terraform. Postawienie środowiska od zera wymaga trzech komend (`init`, `plan`, `apply`). Infrastruktura jest idempotentna — wielokrotne wywołanie `apply` nie powoduje zmian jeśli stan jest zgodny z definicją. Stan Terraform przechowywany jest w S3, dzięki czemu jest współdzielony między lokalnym środowiskiem dewelopera a pipeline'em CI/CD.

### Pipeline CI/CD
Pipeline zbudowany w GitHub Actions realizuje dwa scenariusze:

**Push na dowolną gałąź:**
- Kompilacja aplikacji przez Maven
- Budowanie obrazu Docker
- Push obrazu do Amazon ECR z tagiem odpowiadającym SHA commita
- Generowanie Terraform Plan zapisanego jako artefakt (dostępny przez 30 dni)
- Powiadomienie na Discord o wyniku

**Push na gałąź `main` — dodatkowo:**
- Terraform Apply — aktualizacja infrastruktury
- Automatyczna aktualizacja tagu obrazu w manifeście Kubernetes
- Wdrożenie na EKS przez `kubectl apply`
- Oczekiwanie na zakończenie rolling update
- Powiadomienie na Discord o wdrożeniu

### Zero Downtime Deployment
Aplikacja uruchomiona jest w dwóch replikach. Podczas wdrożenia nowej wersji Kubernetes stosuje rolling update — zastępuje repliki jedna po drugiej, dzięki czemu aplikacja jest dostępna przez cały czas trwania deploymentu.

### Monitoring
Na klastrze zainstalowany jest `kube-prometheus-stack` przez Helm, zawierający:
- **Prometheus** — zbieranie metryk z klastra i aplikacji
- **Grafana** — wizualizacja metryk z gotowymi dashboardami Kubernetes
- **Alertmanager** — zarządzanie alertami

Monitoring instalowany jest automatycznie przez pipeline przy każdym wdrożeniu.

### Skalowanie
Projekt zawiera interaktywny skrypt `scale.sh` który pozwala na skalowanie infrastruktury bez ręcznej edycji plików. Skrypt pyta o typ instancji EC2, liczbę node'ów i replik aplikacji, pokazuje szacowany koszt, wykonuje `terraform plan` i pyta o potwierdzenie przed zastosowaniem zmian.

---

## Stos technologiczny

| Warstwa | Technologia |
|---|---|
| Aplikacja | Spring Boot 4.x (Java 17, Maven) |
| Baza danych | PostgreSQL 18 |
| Konteneryzacja | Docker |
| Rejestr obrazów | Amazon ECR |
| Orkiestracja | Kubernetes (AWS EKS 1.29) |
| Infrastruktura jako kod | Terraform |
| Stan infrastruktury | AWS S3 |
| CI/CD | GitHub Actions |
| Monitoring | Prometheus + Grafana |
| Powiadomienia | Discord webhook |

---

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
│   ├── variables.tf                        # Zmienne konfiguracyjne i skalowanie
│   └── outputs.tf                          # Outputy Terraform (URL klastra, ECR itp.)
├── 🔧 k8s/
│   ├── petclinic.yml                       # Deployment + Service aplikacji (zmodyfikowany)
│   └── db.yml                              # Deployment PostgreSQL + Secret
│
│   ── Pliki oryginalne (nie modyfikowane) ──
│
├── docker-compose.yml                      # Lokalne uruchomienie z bazą danych
├── pom.xml                                 # Definicja zależności i konfiguracja Maven
├── mvnw / mvnw.cmd                         # Maven wrapper (Linux/Windows)
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

---

## Szacowane koszty AWS

| Scenariusz | Koszt |
|---|---|
| Development (klaster wyłączony) | ~$0/dzień |
| Klaster włączony (2x t3.small) | ~$3/dzień |
| Prezentacja (1-2 dni) | ~$6 łącznie |

Infrastruktura może być w całości zniszczona jedną komendą (`terraform destroy`) i postawiona od nowa.
