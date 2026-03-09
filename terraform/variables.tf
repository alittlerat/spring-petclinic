variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "petclinic-cluster"
}

# Skalowanie - zmieniaj tylko tutaj
variable "node_min_size" {
  description = "Minimalna liczba node'ów"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maksymalna liczba node'ów"
  type        = number
  default     = 2
}

variable "node_desired_size" {
  description = "Docelowa liczba node'ów"
  type        = number
  default     = 1
}

variable "node_instance_type" {
  description = "Typ instancji EC2 dla node'ów"
  type        = string
  default     = "t3.medium"
}

variable "app_replicas" {
  description = "Liczba replik aplikacji w Kubernetes"
  type        = number
  default     = 2
}
