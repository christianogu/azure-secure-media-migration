# Build Notes – Secure Media Migration to Azure

## Setup
- Azure Pay-As-You-Go
- Budget alert: $40/month (alerts at 50% and 100%)
- Tools: Azure CLI (Cloud Shell, PowerShell)

## Resource Group
- `rg-hyenlo-migration` in East US

## Network
- VNet `vnet-hyenlo`: 10.0.0.0/16
- Subnet `snet-workload`: 10.0.1.0/24 (for the simulated on-prem VM)
- Subnet `snet-private-endpoints`: 10.0.2.0/24 (for the storage private endpoint)
- NSG `nsg-workload` attached to `snet-workload`
  - Allows SSH (port 22) only from my IP (/32). Everything else inbound is blocked by default.
  - Why: least privilege at the network layer

## Storage
- Storage account: `sthyenlo4299`

# Build Notes – Secure Media Migration to Azure

## Design
- Source ("on-prem"): workstation holding HyenLo Visuals footage (.braw raw files)
- Destination: Azure Blob Storage, container `footage`

## Security
- Shared-key auth disabled → access only via Entra ID sign-in + RBAC (Storage Blob Data Contributor, scoped to one storage account)
- Storage firewall: default Deny, one allowed IP (the source workstation)
- TLS 1.2 minimum, HTTPS only, public blob access disabled
- Soft delete (7 days) + versioning

## Cost
- Lifecycle rule: Hot → Cool at 30 days → Archive at 90 days; old versions deleted after 30 days

## Migration
- Uploaded with `az storage blob upload-batch --auth-mode login`
- Verified: file names and byte sizes match between source and Azure

## Monitoring
- Blob read/write/delete logs → Log Analytics (`law-hyenlo`)
- Tested: key-based access attempt blocked (403) and logged
