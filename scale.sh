#!/bin/bash

# ============================================
# PetClinic Infrastructure Scaling Script
# ============================================

set -e

TERRAFORM_DIR="$(dirname "$0")/terraform"
VARS_FILE="$TERRAFORM_DIR/variables.tf"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
  echo ""
  echo -e "${CYAN}${BOLD}================================================${NC}"
  echo -e "${CYAN}${BOLD}   PetClinic Infrastructure Scaling Manager     ${NC}"
  echo -e "${CYAN}${BOLD}================================================${NC}"
  echo ""
}

print_current() {
  echo -e "${BLUE}${BOLD}📊 Aktualna konfiguracja:${NC}"
  echo ""

  CURRENT_TYPE=$(grep 'default' "$VARS_FILE" | grep -A0 'micro\|small\|medium\|large\|xlarge' | head -1 | tr -d ' "' | sed 's/default=//')
  CURRENT_DESIRED=$(awk '/variable "node_desired_size"/,/}/' "$VARS_FILE" | grep 'default' | tr -d ' ' | sed 's/default=//')
  CURRENT_MIN=$(awk '/variable "node_min_size"/,/}/' "$VARS_FILE" | grep 'default' | tr -d ' ' | sed 's/default=//')
  CURRENT_MAX=$(awk '/variable "node_max_size"/,/}/' "$VARS_FILE" | grep 'default' | tr -d ' ' | sed 's/default=//')
  CURRENT_REPLICAS=$(awk '/variable "app_replicas"/,/}/' "$VARS_FILE" | grep 'default' | tr -d ' ' | sed 's/default=//')

  echo -e "  Instance type:     ${GREEN}${CURRENT_TYPE}${NC}"
  echo -e "  Node desired:      ${GREEN}${CURRENT_DESIRED}${NC}"
  echo -e "  Node min/max:      ${GREEN}${CURRENT_MIN} / ${CURRENT_MAX}${NC}"
  echo -e "  App replicas:      ${GREEN}${CURRENT_REPLICAS}${NC}"
  echo ""
}

choose_instance_type() {
  echo -e "${YELLOW}${BOLD}🖥️  Wybierz typ instancji EC2:${NC}"
  echo ""
  echo -e "  ${BOLD}1)${NC} t3.micro   — 1 vCPU,  1GB RAM  (~\$0.01/h) ⚠️  może być za mało"
  echo -e "  ${BOLD}2)${NC} t3.small   — 2 vCPU,  2GB RAM  (~\$0.02/h) ✅ minimum dla tej apki"
  echo -e "  ${BOLD}3)${NC} t3.medium  — 2 vCPU,  4GB RAM  (~\$0.04/h) ✅ komfortowe"
  echo -e "  ${BOLD}4)${NC} t3.large   — 2 vCPU,  8GB RAM  (~\$0.08/h) 🚀 produkcja"
  echo -e "  ${BOLD}5)${NC} t3.xlarge  — 4 vCPU, 16GB RAM  (~\$0.17/h) 🚀 duży ruch"
  echo ""
  read -rp "$(echo -e "${BOLD}Twój wybór [1-5]:${NC} ")" INSTANCE_CHOICE

  case $INSTANCE_CHOICE in
    1) INSTANCE_TYPE="t3.micro" ;;
    2) INSTANCE_TYPE="t3.small" ;;
    3) INSTANCE_TYPE="t3.medium" ;;
    4) INSTANCE_TYPE="t3.large" ;;
    5) INSTANCE_TYPE="t3.xlarge" ;;
    *) echo -e "${RED}Nieprawidłowy wybór, używam t3.small${NC}"; INSTANCE_TYPE="t3.small" ;;
  esac
}

choose_nodes() {
  echo ""
  echo -e "${YELLOW}${BOLD}🔢 Konfiguracja node'ów EKS:${NC}"
  echo ""
  read -rp "$(echo -e "${BOLD}Minimalna liczba node'ów [1]:${NC} ")" NODE_MIN
  NODE_MIN=${NODE_MIN:-1}

  read -rp "$(echo -e "${BOLD}Maksymalna liczba node'ów [3]:${NC} ")" NODE_MAX
  NODE_MAX=${NODE_MAX:-3}

  read -rp "$(echo -e "${BOLD}Docelowa liczba node'ów [${NODE_MIN}]:${NC} ")" NODE_DESIRED
  NODE_DESIRED=${NODE_DESIRED:-$NODE_MIN}

  # Walidacja
  if [ "$NODE_DESIRED" -lt "$NODE_MIN" ] || [ "$NODE_DESIRED" -gt "$NODE_MAX" ]; then
    echo -e "${RED}⚠️  Docelowa liczba musi być między min a max. Ustawiam na min.${NC}"
    NODE_DESIRED=$NODE_MIN
  fi
}

choose_replicas() {
  echo ""
  echo -e "${YELLOW}${BOLD}🐋 Liczba replik aplikacji w Kubernetes:${NC}"
  echo ""
  echo -e "  Repliki = ile kopii aplikacji działa równocześnie"
  echo -e "  Więcej replik = większa dostępność i obsługa ruchu"
  echo ""
  read -rp "$(echo -e "${BOLD}Liczba replik [2]:${NC} ")" APP_REPLICAS
  APP_REPLICAS=${APP_REPLICAS:-2}
}

update_variables() {
  echo ""
  echo -e "${BLUE}📝 Aktualizuję terraform/variables.tf...${NC}"

  sed -i "/variable \"node_instance_type\"/,/^}/{s/default *= *\".*\"/default     = \"${INSTANCE_TYPE}\"/}" "$VARS_FILE"
  sed -i "/variable \"node_min_size\"/,/^}/{s/default *= *[0-9]*/default     = ${NODE_MIN}/}" "$VARS_FILE"
  sed -i "/variable \"node_max_size\"/,/^}/{s/default *= *[0-9]*/default     = ${NODE_MAX}/}" "$VARS_FILE"
  sed -i "/variable \"node_desired_size\"/,/^}/{s/default *= *[0-9]*/default     = ${NODE_DESIRED}/}" "$VARS_FILE"
  sed -i "/variable \"app_replicas\"/,/^}/{s/default *= *[0-9]*/default     = ${APP_REPLICAS}/}" "$VARS_FILE"

  echo -e "${GREEN}✅ Plik zaktualizowany${NC}"
}

show_cost_estimate() {
  echo ""
  echo -e "${YELLOW}${BOLD}💰 Szacowane koszty:${NC}"
  echo ""

  case $INSTANCE_TYPE in
    "t3.micro")  HOURLY=0.01 ;;
    "t3.small")  HOURLY=0.02 ;;
    "t3.medium") HOURLY=0.04 ;;
    "t3.large")  HOURLY=0.08 ;;
    "t3.xlarge") HOURLY=0.17 ;;
  esac

  DAILY=$(echo "$HOURLY * $NODE_DESIRED * 24" | bc)
  MONTHLY=$(echo "$DAILY * 30" | bc)

  echo -e "  ${NODE_DESIRED}x ${INSTANCE_TYPE} = ~\$${DAILY}/dzień (~\$${MONTHLY}/miesiąc)"
  echo -e "  ${BOLD}Prezentacja 2 dni:${NC} ~\$$(echo "$DAILY * 2" | bc)"
  echo ""
}

run_terraform() {
  cd "$TERRAFORM_DIR"

  echo ""
  echo -e "${BLUE}${BOLD}🔍 Uruchamiam terraform plan...${NC}"
  echo ""

  terraform plan

  echo ""
  echo -e "${YELLOW}${BOLD}❓ Czy chcesz zastosować te zmiany?${NC}"
  echo ""
  echo -e "  ${BOLD}1)${NC} ✅ Tak — zastosuj (terraform apply)"
  echo -e "  ${BOLD}2)${NC} ❌ Nie — anuluj"
  echo ""
  read -rp "$(echo -e "${BOLD}Twój wybór [1-2]:${NC} ")" APPLY_CHOICE

  case $APPLY_CHOICE in
    1)
      echo ""
      echo -e "${GREEN}${BOLD}🚀 Uruchamiam terraform apply...${NC}"
      echo ""
      terraform apply -auto-approve
      echo ""
      echo -e "${GREEN}${BOLD}✅ Infrastruktura zaktualizowana!${NC}"
      ;;
    *)
      echo ""
      echo -e "${YELLOW}⏸️  Anulowano. Plik variables.tf został zaktualizowany ale zmiany nie zostały wdrożone.${NC}"
      echo -e "${YELLOW}   Możesz ręcznie uruchomić: cd terraform && terraform apply${NC}"
      ;;
  esac
}

# ============================================
# MAIN
# ============================================

print_header
print_current
choose_instance_type
choose_nodes
choose_replicas
show_cost_estimate
update_variables
run_terraform
