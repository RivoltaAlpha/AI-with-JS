targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the environment that can be used as part of naming resource convention')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

param rg string = ''
param webappName string = 'webapp'

@description('Location for the Static Web App')
@allowed(['westus2', 'centralus', 'eastus2', 'westeurope', 'eastasia', 'eastasiastage'])
@metadata({
  azd: {
    type: 'location'
  }
})
param webappLocation string

@description('Id of the user or app to assign application roles')
param principalId string

// ---------------------------------------------------------------------------
// Common variables
var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = uniqueString(subscription().id, environmentName)
var tags = {
  'azd-env-name': environmentName
}

// Resource names using the resource token
var webapiName = 'webapi-${resourceToken}'
var appServicePlanName = 'appserviceplan-${resourceToken}'
var cognitiveServicesName = 'cs-${environmentName}-${resourceToken}'
var aiHubName = 'aih-${environmentName}-${resourceToken}'

// ---------------------------------------------------------------------------
// Resources

// Organize resources in a resource group ✅
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(rg) ? rg : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// User-assigned managed identity
module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.0' = {
  name: 'userAssignedIdentity'
  scope: resourceGroup
  params: {
    name: 'uai-${environmentName}-${resourceToken}'
    location: location
    tags: tags
  }
}

module webapp 'br/public:avm/res/web/static-site:0.7.0' = {
  name: 'webapp'
  scope: resourceGroup
  params: {
    name: webappName
    location: webappLocation
    tags: union(tags, { 'azd-service-name': webappName })
    sku: 'Standard'
  }
}

module serverfarm 'br/public:avm/res/web/serverfarm:0.4.1' = {
  name: 'appserviceplan'
  scope: resourceGroup
  params: {
    name: appServicePlanName
    skuName: 'B1'
  }
}

// Web API module will be defined later with AI services configuration

// Azure Cognitive Services account for AI models
module cognitiveServices 'br/public:avm/res/cognitive-services/account:0.7.0' = {
  name: 'cognitiveServices'
  scope: resourceGroup
  params: {
    name: cognitiveServicesName
    kind: 'AIServices'
    sku: 'S0'
    location: location
    tags: union(tags, { 'azd-service-name': 'ai-services' })
    publicNetworkAccess: 'Enabled'
  }
}

// Machine Learning workspace for AI Hub
module machineLearning 'br/public:avm/res/machine-learning-services/workspace:0.7.0' = {
  name: 'machineLearning'
  scope: resourceGroup
  params: {
    name: aiHubName
    sku: 'Basic'
    location: location
    tags: union(tags, { 'azd-service-name': 'ai-hub' })
    associatedApplicationInsightsResourceId: applicationInsights.outputs.resourceId
    associatedKeyVaultResourceId: keyVault.outputs.resourceId
    associatedStorageAccountResourceId: storageAccount.outputs.resourceId
    managedIdentities: {
      systemAssigned: true
    }
  }
}

// Application Insights for monitoring
module applicationInsights 'br/public:avm/res/insights/component:0.4.0' = {
  name: 'applicationInsights'
  scope: resourceGroup
  params: {
    name: 'ai-${environmentName}'
    workspaceResourceId: logAnalyticsWorkspace.outputs.resourceId
    location: location
    tags: union(tags, { 'azd-service-name': 'monitoring' })
  }
}

// Log Analytics Workspace
module logAnalyticsWorkspace 'br/public:avm/res/operational-insights/workspace:0.7.0' = {
  name: 'logAnalyticsWorkspace'
  scope: resourceGroup
  params: {
    name: 'law-${environmentName}'
    location: location
    tags: union(tags, { 'azd-service-name': 'monitoring' })
  }
}

// Key Vault for secrets
module keyVault 'br/public:avm/res/key-vault/vault:0.9.0' = {
  name: 'keyVault'
  scope: resourceGroup
  params: {
    name: 'kv-${take(resourceToken, 21)}' // Ensure max 24 chars
    location: location
    tags: union(tags, { 'azd-service-name': 'secrets' })
    sku: 'standard'
    enableRbacAuthorization: true
    accessPolicies: [
      {
        objectId: principalId
        permissions: {
          secrets: ['get', 'list', 'set']
          keys: ['get', 'list']
          certificates: ['get', 'list']
        }
      }
    ]
  }
}

// Storage Account for AI Hub
module storageAccount 'br/public:avm/res/storage/storage-account:0.14.3' = {
  name: 'storageAccount'
  scope: resourceGroup
  params: {
    name: 'st${take(resourceToken, 19)}' // Ensure max 24 chars
    location: location
    tags: union(tags, { 'azd-service-name': 'storage' })
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
    allowBlobPublicAccess: false
    supportsHttpsTrafficOnly: true
  }
}

// Update the web API to include environment variables for AI services
module webapi 'br/public:avm/res/web/site:0.15.1' = {
  name: webapiName
  scope: resourceGroup
  params: {
    kind: 'app'
    name: webapiName
    serverFarmResourceId: serverfarm.outputs.resourceId
    tags: union(tags, { 'azd-service-name': 'webapi' })
    siteConfig: {
      cors: {
        allowedOrigins: ['*']
        supportCredentials: false
      }
      appSettings: [
        {
          name: 'AZURE_INFERENCE_API_KEY'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.outputs.name};SecretName=azure-inference-api-key)'
        }
        {
          name: 'AZURE_INFERENCE_SDK_ENDPOINT'
          value: cognitiveServices.outputs.endpoint
        }
        {
          name: 'AZUREAI_MODEL'
          value: 'gpt-4o'
        }
        {
          name: 'INSTANCE_NAME'
          value: cognitiveServicesName
        }
        {
          name: 'AZURE_AI_PROJECT_CONNECTION_STRING'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.outputs.name};SecretName=ai-project-connection-string)'
        }
        {
          name: 'AZURE_AI_AGENT_ID'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.outputs.name};SecretName=ai-agent-id)'
        }
      ]
    }
    managedIdentities: {
      userAssignedResourceIds: [userAssignedIdentity.outputs.resourceId]
    }
  }
}

// Grant the web API access to Key Vault
resource keyVaultRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup.id, userAssignedIdentity.outputs.principalId, '4633458b-17de-408a-b874-0445c86b69e6')
  scope: resourceGroup
  properties: {
    principalId: userAssignedIdentity.outputs.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalType: 'ServicePrincipal'
  }
}

// Store secrets in Key Vault
resource keyVaultSecretsReference 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVault.outputs.name
  scope: resourceGroup
}

resource cognitiveServicesSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  name: 'azure-inference-api-key'
  parent: keyVaultSecretsReference
  properties: {
    value: listKeys(resourceId('Microsoft.CognitiveServices/accounts', cognitiveServicesName), '2024-10-01').key1
  }
}

output WEBAPP_URL string = webapp.outputs.defaultHostname
output WEBAPI_URL string = webapi.outputs.defaultHostname
output AZURE_INFERENCE_ENDPOINT string = cognitiveServices.outputs.endpoint
output AZURE_AI_HUB_NAME string = machineLearning.outputs.name
output KEY_VAULT_NAME string = keyVault.outputs.name
output RESOURCE_GROUP_ID string = resourceGroup.id
