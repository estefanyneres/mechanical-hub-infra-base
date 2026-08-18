variable "projectName" {
  default = "mechanical-hub"
}

variable "region_default" {
  default = "us-east-1"
}

variable "cidr_vpc" {
  default = "10.0.0.0/16"
}

variable "tags" {
  default = {
    School      = "FIAP"
    Environment = "Production"
  }
}
