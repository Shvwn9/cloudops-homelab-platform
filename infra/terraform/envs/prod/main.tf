terraform {
  required_version = ">= 1.6.0"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 7.0"
    }
  }
}

provider "oci" {
  region = var.region
  auth   = "InstancePrincipal"
}

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

variable "region" {
  description = "Région OCI, par exemple eu-paris-1"
  type        = string
}

variable "compartment_ocid" {
  description = "OCID du compartiment OCI"
  type        = string
}

variable "ssh_public_key" {
  description = "Clé publique SSH au format OpenSSH"
  type        = string
}

variable "display_name" {
  description = "Nom de l'instance"
  type        = string
  default     = "masterops-k3s-prod"
}

variable "ssh_allowed_cidr" {
  description = "CIDR autorisé en SSH. Idéalement votre IP publique suivie de /32."
  type        = string
  default     = "0.0.0.0/0"
}

variable "availability_domain_index" {
  description = "Index de l'Availability Domain : 0, 1 ou 2 selon la région"
  type        = number
  default     = 0
}

variable "shape" {
  description = "Shape OCI de la VM"
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "ocpus" {
  description = "Nombre d'OCPU"
  type        = number
  default     = 1
}

variable "memory_in_gbs" {
  description = "Mémoire en Go"
  type        = number
  default     = 2
}

variable "ubuntu_version" {
  description = "Version Ubuntu"
  type        = string
  default     = "22.04"
}

# -----------------------------------------------------------------------------
# Sources de données
# -----------------------------------------------------------------------------

data "oci_identity_availability_domains" "ads" {
  compartment_id = var.compartment_ocid
}

# Recherche automatiquement la dernière image Ubuntu compatible avec la shape.
data "oci_core_images" "ubuntu" {
  compartment_id          = var.compartment_ocid
  operating_system        = "Canonical Ubuntu"
  operating_system_version = var.ubuntu_version
  shape                   = var.shape
  state                   = "AVAILABLE"
  sort_by                 = "TIMECREATED"
  sort_order              = "DESC"
}

# -----------------------------------------------------------------------------
# Réseau
# -----------------------------------------------------------------------------

resource "oci_core_vcn" "main" {
  compartment_id = var.compartment_ocid
  cidr_blocks     = ["10.0.0.0/16"]
  display_name    = "${var.display_name}-vcn"
  dns_label       = "masterops"
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.display_name}-igw"
  enabled        = true
}

resource "oci_core_route_table" "public" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.display_name}-public-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }
}

# Cette Security List autorise uniquement les connexions sortantes.
# Les connexions entrantes sont gérées par la NSG ci-dessous.
resource "oci_core_security_list" "egress_only" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.display_name}-egress-only"

  egress_security_rules {
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = false
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = var.compartment_ocid
  vcn_id                     = oci_core_vcn.main.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "${var.display_name}-public-subnet"
  dns_label                  = "public"
  route_table_id             = oci_core_route_table.public.id
  security_list_ids          = [oci_core_security_list.egress_only.id]
  prohibit_public_ip_on_vnic = false
}

# -----------------------------------------------------------------------------
# Network Security Group
# -----------------------------------------------------------------------------

resource "oci_core_network_security_group" "k3s" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "${var.display_name}-nsg"
}

# SSH
resource "oci_core_network_security_group_security_rule" "ssh" {
  network_security_group_id = oci_core_network_security_group.k3s.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = var.ssh_allowed_cidr
  source_type               = "CIDR_BLOCK"
  description               = "SSH"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = 22
      max = 22
    }
  }
}

# HTTP et HTTPS
resource "oci_core_network_security_group_security_rule" "web" {
  for_each = {
    http  = 80
    https = 443
  }

  network_security_group_id = oci_core_network_security_group.k3s.id
  direction                 = "INGRESS"
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  description               = upper(each.key)
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = each.value
      max = each.value
    }
  }
}

# -----------------------------------------------------------------------------
# VM Ubuntu + K3s
# -----------------------------------------------------------------------------

resource "oci_core_instance" "k3s" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[var.availability_domain_index].name
  compartment_id      = var.compartment_ocid
  display_name        = var.display_name
  shape               = var.shape

  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    assign_public_ip = true
    hostname_label   = "k3s"
    nsg_ids          = [oci_core_network_security_group.k3s.id]
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu.images[0].id
    boot_volume_size_in_gbs = 10
  }

  metadata = {
    ssh_authorized_keys = trimspace(var.ssh_public_key)

    user_data = base64encode(<<-CLOUD_INIT
      #cloud-config
      package_update: true

      packages:
        - curl

      runcmd:
        - [ bash, -lc, 'curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --write-kubeconfig-mode=0644" sh -' ]
    CLOUD_INIT
    )
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = true
  }

  lifecycle {
    # Évite de remplacer la VM lorsque Oracle publie une nouvelle image Ubuntu.
    ignore_changes = [source_details[0].source_id]
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "public_ip" {
  description = "Adresse IPv4 publique de la VM"
  value       = oci_core_instance.k3s.public_ip
}

output "ssh_command" {
  description = "Commande de connexion SSH"
  value       = "ssh -i ~/.ssh/masterops_oci ubuntu@${oci_core_instance.k3s.public_ip}"
}

output "ubuntu_image" {
  description = "Image Ubuntu sélectionnée"
  value       = data.oci_core_images.ubuntu.images[0].display_name
}