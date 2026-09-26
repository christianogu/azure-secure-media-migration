# Build Notes – Secure Media Migration to Azure

## Setup
- Azure for Students subscription
- Budget alert: $10/month (alerts at 50% and 100%)
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
