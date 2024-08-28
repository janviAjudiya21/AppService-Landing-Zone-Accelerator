@description('Optional, default is false. Set to true if you want to deploy ASE v3 instead of Multitenant App Service Plan.')
param deployAseV3 bool = false

@description('Optional if deployAseV3 = false. The identifier for the App Service Environment v3 resource.')
@minLength(1)
@maxLength(36)
param aseName string = ''

@description('Required. Name of the App Service Plan.')
@minLength(1)
@maxLength(40)
param appServicePlanName string

@description('Required. Name of the web app.')
@maxLength(60)
param webAppName string 

@description('Required. Name of the managed Identity that will be assigned to the web app.')
@minLength(3)
@maxLength(128)
param managedIdentityName string

@description('Required. Name of the Azure App Configuration. Alphanumerics, underscores, and hyphens. Must be unique')
@minLength(5)
@maxLength(50)
param appConfigurationName string

@description('Optional S1 is default. Defines the name, tier, size, family, and capacity of the App Service Plan. Plans ending with _AZ are deploying at least three instances in three Availability Zones. EP* is only for functions')
@allowed([ 'S1', 'S2', 'S3', 'P1V3', 'P2V3', 'P3V3', 'P1V3_AZ', 'P2V3_AZ', 'P3V3_AZ', 'EP1', 'EP2', 'EP3', 'ASE_I1V2_AZ', 'ASE_I2V2_AZ', 'ASE_I3V2_AZ', 'ASE_I1V2', 'ASE_I2V2', 'ASE_I3V2' ])
param sku string = 'S1'

@description('Optional. Location for all resources.')
param location string = resourceGroup().location

@description('Resource tags that we might need to add to all resources (i.e. Environment, Cost center, application name, etc.)')
param tags object = {}

@description('Default is empty. If empty no Private Endpoint will be created for the resource. Otherwise, the subnet where the private endpoint will be attached to.')
param subnetPrivateEndpointId string = ''

@description('Optional. Array of custom objects describing vNet links of the DNS zone. Each object should contain vnetName, vnetId, registrationEnabled')
param virtualNetworkLinks array = []

@description('If empty, private DNS zone will be deployed in the current RG scope.')
param vnetHubResourceId string = ''

@description('Kind of server OS of the App Service Plan.')
@allowed([ 'Windows', 'Linux'])
param webAppBaseOs string = 'Windows'

@description('An existing Log Analytics Workspace Id for creating App Insights, diagnostics, etc.')
param logAnalyticsWsId string

@description('The subnet ID that is dedicated to Web Server, for Vnet Injection of the web app. If deployAseV3=true then this is the subnet dedicated to the ASE v3.')
param subnetIdForVnetInjection string

@description('The name of an existing Key Vault that will be used to store secrets (connection string).')
param keyvaultName string

@description('The name of the secret that stores the Redis connection string.')
param redisConnectionStringSecretName string = ''

@description('The connection string of the default SQL Database.')
param sqlDbConnectionString string = ''

@description('Deploy an Azure App Configuration, or not.')
param deployAppConfig bool = false

var vnetHubSplitTokens = !empty(vnetHubResourceId) ? split(vnetHubResourceId, '/') : array('')

var webAppDnsZoneName = 'privatelink.azurewebsites.net'
var appConfigurationDnsZoneName = 'privatelink.azconfig.io'
var slotName = 'staging'

var redisConnStr = !empty(redisConnectionStringSecretName) ? {redisConnectionStringSecret: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=${redisConnectionStringSecretName})'} : {}

resource keyvault 'Microsoft.KeyVault/vaults@2022-11-01' existing = {
  name: keyvaultName
}

module ase '../../../shared/bicep/app-services/ase/ase.bicep' = if (deployAseV3) {
  name: take('${aseName}-ASEv3-Deployment', 64)
  params: {
    name: aseName
    location: location
    tags: tags
    diagnosticWorkspaceId: logAnalyticsWsId
    subnetResourceId: subnetIdForVnetInjection
    zoneRedundant: endsWith(sku, 'AZ') ? true : false
    allowNewPrivateEndpointConnections: true
  }
}

module appInsights '../../../shared/bicep/app-insights.bicep' = {
  name: 'appInsights-Deployment'
  params: {
    name: 'appi-${webAppName}'
    location: location
    tags: tags
    workspaceResourceId: logAnalyticsWsId
  }
}

module asp '../../../shared/bicep/app-services/app-service-plan.bicep' = {
  name: take('appSvcPlan-${appServicePlanName}-Deployment', 64)
  params: {
    name: appServicePlanName
    location: location
    tags: tags
    sku: sku
    serverOS: webAppBaseOs
    diagnosticWorkspaceId: logAnalyticsWsId
    hostingEnvironmentProfileId: deployAseV3 ? ase.outputs.resourceId : ''
  }
}

module webApp '../../../shared/bicep/app-services/web-app.bicep' = {
  name: take('${webAppName}-webApp-Deployment', 64)
  params: {
    kind: webAppBaseOs == 'Linux' ? 'app,linux' : 'app'
    name:  webAppName
    location: location
    serverFarmResourceId: asp.outputs.resourceId
    diagnosticWorkspaceId: logAnalyticsWsId   
    virtualNetworkSubnetId: !deployAseV3 ? subnetIdForVnetInjection : ''
    appInsightId: appInsights.outputs.appInsResourceId
    siteConfigSelection: webAppBaseOs == 'Linux' ? 'linuxNet6' : 'windowsNet6'
    hasPrivateLink: !deployAseV3 && !empty(subnetPrivateEndpointId)
    systemAssignedIdentity: false
    userAssignedIdentities: {
      '${webAppUserAssignedManagedIdenity.outputs.id}': {}
    }
    appSettingsKeyValuePairs: redisConnStr
    slots: [
      {
        name: slotName
      }
    ]
  }
}

resource webAppExisting 'Microsoft.Web/sites@2022-03-01' existing =  {
  name: webAppName
}

resource webappConnectionstring 'Microsoft.Web/sites/config@2019-08-01' = if (!empty(sqlDbConnectionString)) {
  parent: webAppExisting
  name: 'connectionstrings'
  properties: {
    sqlDbConnectionString: {
      value: sqlDbConnectionString
      type: 'SQLAzure'
    }
  }
  dependsOn: [
    webApp
  ]
}

module webAppUserAssignedManagedIdenity '../../../shared/bicep/managed-identity.bicep' = {
  name: 'appSvcUserAssignedManagedIdenity-Deployment'
  params: {
    name: managedIdentityName
    location: location
    tags: tags
  }
}

module webAppPrivateDnsZone '../../../shared/bicep/private-dns-zone.bicep' = if (!empty(subnetPrivateEndpointId) && !deployAseV3) {
  scope: resourceGroup(vnetHubSplitTokens[2], vnetHubSplitTokens[4])
  name: take('${replace(webAppDnsZoneName, '.', '-')}-PrivateDnsZoneDeployment', 64)
  params: {
    name: webAppDnsZoneName
    virtualNetworkLinks: virtualNetworkLinks
    tags: tags
  }
}

module peWebApp '../../../shared/bicep/private-endpoint.bicep' = if (!empty(subnetPrivateEndpointId) && !deployAseV3) {
  name:  take('pe-${webAppName}-Deployment', 64)
  params: {
    name: take('pe-${webApp.outputs.name}', 64)
    location: location
    tags: tags
    privateDnsZonesId: !empty(subnetPrivateEndpointId) && !deployAseV3 ? webAppPrivateDnsZone.outputs.privateDnsZonesId : ''
    privateLinkServiceId: webApp.outputs.resourceId
    snetId: subnetPrivateEndpointId
    subresource: 'sites'
  }
}

module peWebAppSlot '../../../shared/bicep/private-endpoint.bicep' = if (!empty(subnetPrivateEndpointId) && !deployAseV3) {
  name:  take('pe-${webAppName}-slot-${slotName}-Deployment', 64)
  params: {
    name: take('pe-${webAppName}-slot-${slotName}', 64)
    location: location
    tags: tags
    privateDnsZonesId: !empty(subnetPrivateEndpointId) && !deployAseV3 ? webAppPrivateDnsZone.outputs.privateDnsZonesId : ''
    privateLinkServiceId: webApp.outputs.resourceId
    snetId: subnetPrivateEndpointId
    subresource: 'sites-${slotName}'
  }
}

module appConfigStore '../../../shared/bicep/app-configuration.bicep' = if (deployAppConfig) {
  name: take('${appConfigurationName}-Deployment', 64)
  params: {
    name: appConfigurationName
    location: location
    tags: tags
  }
}

module appConfigPrivateDnsZone '../../../shared/bicep/private-dns-zone.bicep' = if (deployAppConfig && !empty(subnetPrivateEndpointId)) {
  scope: resourceGroup(vnetHubSplitTokens[2], vnetHubSplitTokens[4])
  name: take('${replace(appConfigurationDnsZoneName, '.', '-')}-PrivateDnsZoneDeployment', 64)
  params: {
    name: appConfigurationDnsZoneName
    virtualNetworkLinks: virtualNetworkLinks
    tags: tags
  }
}

module peAzConfig '../../../shared/bicep/private-endpoint.bicep' = if (deployAppConfig && !empty(subnetPrivateEndpointId)) {
  name: take('pe-${appConfigurationName}-Deployment', 64)
  params: {
    name: take('pe-${appConfigStore.outputs.name}', 64)
    location: location
    tags: tags
    privateDnsZonesId: deployAppConfig && !empty(subnetPrivateEndpointId) ? appConfigPrivateDnsZone.outputs.privateDnsZonesId : ''
    privateLinkServiceId: appConfigStore.outputs.resourceId
    snetId: subnetPrivateEndpointId
    subresource: 'azconfig'
  }
}

module roleAssignment '../../../shared/bicep/role-assignment.bicep' = {
  name: take('roleAssgnmnt-${webAppUserAssignedManagedIdenity.outputs.id}-Deployment', 64)
  params: {
    principalId: webAppUserAssignedManagedIdenity.outputs.principalId
    roleDefinitionNameOrId: 'Key Vault Secrets User'
    scope: keyvault.id
  }
}
