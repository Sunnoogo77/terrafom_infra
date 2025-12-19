# Documentation d’architecture – Impulse (Infra Azure & Terraform)

## 1. Présentation générale du projet
- Impulse déploie une plateforme applicative sur Azure, pilotée par Terraform. L’environnement actuellement décrit est `dev` (`envs/dev`).
- Vision DevSecOps : infrastructure codée dans des modules Terraform, pipeline GitHub Actions avec étapes de validation, plan et apply manuel, sécurité par RBAC et Managed Identities.

## 2. Architecture cloud globale (Azure)
- Fichier d’assemblage : `envs/dev/main.tf`.
- Ressources principales instanciées :
  - Groupe de ressources `impulse-rg-dev` (via `modules/network`).
  - Réseau (VNet + sous-réseaux), Log Analytics, SQL managé, Storage, Key Vault, ACR, Azure Container Apps (backend + IA), Static Web App.
  - Groupes Entra ID et RBAC (modules `groups` et `rbac`).
- Chaque brique provient d’un module sous `modules/*` (cf. sections ci-dessous).

## 3. Réseau & segmentation
- Module : `modules/network/main.tf`.
- VNet `impulse-vnet-dev`, plage `10.10.0.0/16`.
- Subnets :
  - `snet-backend` : `10.10.1.0/24` (ACA environment et backend).
  - `snet-ia` : `10.10.2.0/24` (usage IA).
  - `snet-endpoints` : `10.10.4.0/24` (Private Endpoints).
- NSG :
  - `nsg-backend-dev` : autorise `AzureFrontDoor.Backend` vers 443.
  - `nsg-ia-dev` : autorise `10.10.1.0/24` vers 443.
  - `nsg-endpoints-dev` : autorise `10.10.1.0/24` et `10.10.2.0/24` vers 443.
  - Associations sur chaque subnet.
- Remarque : pas de délégation de subnet ACA ni de règles egress restrictives dans le code actuel.

## 4. Container Apps (ACA)
- Module backend : `modules/backend_app`.
  - Crée un environnement ACA `impulse-aca-env-dev` injecté dans `snet-backend`.
  - App backend `impulse-backend-dev`, ingress public activé (`ingress_external_enabled = true`), port 8000.
  - Managed Identity `impulse-backend-mi-dev`.
- Module IA : `modules/ai_app`.
  - Réutilise l’environnement ACA existant.
  - App IA `impulse-ai-dev`, ingress interne (external_disabled), port 8001.
  - Managed Identity `impulse-ai-mi-dev`.
- Registre d’images : ACR `impulseacrdev` (module `modules/acr`), utilisé via `acr_login_server` sur les deux apps.
- Flux : IA peut appeler le backend via `BACKEND_URL`; backend expose une URL publique dans cet état dev.

## 5. Données & services managés
- Base de données : Azure SQL Server `impulse-sql-dev` + DB `impulse-db-dev` (`modules/database`). Public network access désactivé, Private Endpoint `...-pe` sur `snet-endpoints`. Diagnostics SQL vers Log Analytics si fourni.
- Stockage : Storage Account `impulsestordev` (`modules/storage`) avec containers privés (`cv-input`, `lm-generated`, `avatars`, `exports`). Public network access désactivé, HTTPS only, TLS1.2, Private Endpoint blob. Diagnostics optionnels vers Log Analytics.
- Key Vault : `impulse-kv-dev` (`modules/keyvault`), RBAC activé, purge protection, soft delete, réseau par ACL (deny par défaut + bypass AzureServices) et Private Endpoint. Diagnostics optionnels vers Log Analytics.
- ACR : `impulseacrdev` (`modules/acr`), SKU Basic, admin off, Private Endpoint désactivé dans `envs/dev` (`enable_private_endpoint = false`). Diagnostics optionnels vers Log Analytics.
- Private DNS : aucune zone Private DNS dans le code actuel.

## 6. Sécurité & RBAC (Airbags)
- Principe : rôles attribués aux groupes Entra ID, utilisateurs ajoutés manuellement aux groupes.
- Création des groupes : `modules/groups/main.tf` (security groups, mail_disabled).
  - `impulse-infra`, `impulse-devsecops`, `impulse-dev`, `impulse-ia`, `impulse-data`, `impulse-security`, `impulse-soc`.
- Attributions RBAC : `modules/rbac/main.tf`, instancié dans `envs/dev/main.tf`.
  - Resource Group : Owner (infra), Contributor (devsecops), Reader (dev, ia, data), Security Reader (security, soc).
  - Key Vault : Key Vault Administrator (infra), Secrets Officer (devsecops), Secrets User (MI backend, MI IA), Key Vault Reader (security, soc).
  - Storage : Blob Data Contributor (MI backend), Blob Data Reader (MI IA, groupe dev).
  - SQL : Contributor (data) sur le serveur SQL.
  - ACR : AcrPull (MI backend, MI IA), AcrPush (devsecops).
  - Log Analytics : Log Analytics Reader (security, soc) si `law_id` fourni (câblé dans `envs/dev/main.tf`).
- Managed Identities : créées dans `modules/backend_app` et `modules/ai_app`, consommées par `modules/rbac`.
- Objectif de sécurité : Zero Trust/Least Privilege via RBAC et Private Endpoints, bien que certains points restent ouverts (ingress backend public, pas de Front Door/WAF, DNS privé manquant).

## 7. Observabilité & SOC
- Workspace : Log Analytics `impulse-law-dev` (`modules/monitoring`), rétention 30 jours.
- Diagnostics : configurables sur SQL, Storage, Key Vault, ACR via `log_analytics_workspace_id` (activés en dev car l’ID est passé).
- SOC : pas de Sentinel/Defender dans le code actuel ; seuls rôles Log Analytics Reader (security, soc) sont prévus via `modules/rbac`.

## 8. CI/CD & Terraform
- Workflow unique : `.github/workflows/impulse-terraform.yml.yml`.
- Jobs :
  - `validate` : `terraform fmt -check`, `terraform init -backend=false`, `terraform validate`, `tfsec`, `tflint`, `checkov`.
  - `plan` (non PR fork) : login Azure via `AZURE_CREDENTIALS` (JSON Service Principal), `terraform init -backend=false`, `terraform plan`, export JSON, artefact du plan.
  - `security` : Trivy IaC (SARIF), trufflehog.
  - `apply` (workflow_dispatch, env dev) : télécharge l'artefact, init local backend, `terraform apply`.
- Secrets/vars attendus : `AZURE_CREDENTIALS` (JSON Service Principal) et `TF_VAR_sql_admin_password`. Le backend Terraform est local (`backend "local"` et `-backend=false` en CI), donc pas de verrouillage distant dans l'état actuel.
- Génération `AZURE_CREDENTIALS` : créer un Service Principal avec un rôle adapté (RG) puis `az ad sp create-for-rbac --name "<name>" --role Contributor --scopes "/subscriptions/<SUBSCRIPTION_ID>" --sdk-auth` et placer la sortie JSON dans le secret GitHub `AZURE_CREDENTIALS`. Les champs `clientId`, `clientSecret`, `subscriptionId`, `tenantId` doivent provenir du même tenant et de la même souscription (ne pas mélanger app/tenant et subscription).

## Secrets GitHub requis
- `AZURE_CREDENTIALS` : JSON Service Principal Azure contenant `clientId`, `clientSecret`, `subscriptionId`, `tenantId`.
- `TF_VAR_sql_admin_password` : mot de passe admin SQL (Terraform var), requis pour `plan/apply`.

Note CRITIQUE : les 4 valeurs du JSON (`clientId`, `clientSecret`, `subscriptionId`, `tenantId`) doivent venir du même tenant et de la même souscription (ne pas mélanger une app registration d’un tenant avec une subscription d’un autre tenant).

## 9. Limites actuelles & évolutions prévues
- Pas de Front Door/WAF, backend ACA exposé publiquement en dev.
- Pas de Private DNS pour les Private Endpoints.
- ACR sans Private Endpoint (flag désactivé en dev).
- Pas de Sentinel/Defender déployés.
- Backend Terraform local (pas de state distant/lock).
- Subnets non délégués à ACA et règles egress non restreintes.
- Ces points sont à renforcer pour une mise en production.

## 10. Navigation dans le repository
- `envs/dev` : assemblage de l’infra (providers, variables, main, outputs, tfvars).
- `modules/` : briques réutilisables (réseau, base de données, stockage, key vault, acr, apps ACA backend/IA, frontend, monitoring, rbac, groups).
- `modules/groups` : création des groupes Entra ID.
- `modules/rbac` : attributions de rôles aux groupes et Managed Identities.
- `.github/workflows/` : pipelines CI/CD Terraform et scans sécurité.
- `policies/` : configurations tfsec et checkov.
- `diagrammes/` : diagrammes existants (référence visuelle, non générateurs de code).
