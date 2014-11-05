restify = require "restify"

Login = require "../Login"

Resource = require "./Resource"
dataHelpers = require "./Helpers"

ramlPath = 'config/cloud.raml'
configApiBaseUrl = 'https://config-api.appgyver.com'

class Provider
  @ProviderError: class ProviderError extends steroidsCli.SteroidsError
  @CloudReadError: class CloudReadError extends ProviderError
  @CloudWriteError: class CloudWriteError extends ProviderError

  @apiClient = restify.createJsonClient
    url: configApiBaseUrl
  @apiClient.headers["Authorization"] = Login.currentAccessToken()

  @forBackend: (backend) =>
    return new Promise (resolve, reject) =>
      steroidsCli.debug "PROVIDER", "Getting a provider for backend #{backend.providerName}"

      @getAll().then (providers)=>
        steroidsCli.debug "PROVIDER", "Got some providers: #{JSON.stringify(providers)}"

        # provider = providers.find (p)=> p.providerTypeId == backend.providerTypeId
        provider = null
        providers.forEach (p)=>
          provider = p if p.typeId == backend.providerTypeId

        if provider?
          steroidsCli.debug "PROVIDER", "provider for backend #{backend.providerTypeId} already exists"
          resolve()
        else
          steroidsCli.debug "PROVIDER", "provider for backend #{backend.providerTypeId} not found, creating a new one"
          provider = new Provider
            backend: backend

          provider.create().then =>
            steroidsCli.debug "PROVIDER", "provider for backend #{backend.providerTypeId} created"
            resolve(provider)

  @forResource: (name) =>
    return new Promise (resolve, reject) =>
      steroidsCli.debug "PROVIDER", "Getting a provider for resource #{name}"

      @getAll().then (providers)=>
        steroidsCli.debug "PROVIDER", "Got some providers. amount: #{providers.length}"

        for provider in providers
          steroidsCli.debug "PROVIDER", "Getting resources for provider #{provider.name}"
          provider.getResources().then (resources)=>
            steroidsCli.debug "PROVIDER", "Got some resources: #{JSON.stringify(resources)}"
            for resource in resources
              if resource.name == name
                steroidsCli.debug "PROVIDER", "Found resource #{name} from provider #{provider.name} UID: #{provider.uid}"
                resolve(provider)
                return

            reject new ProviderError "Could not find provider for resource by resource name: #{name}"

  #TODO: should be Resource.forName but Resource cannot require Provider if Provider requires Resource
  @resourceForName: (name)=>
    return new Promise (resolve, reject) =>
      steroidsCli.debug "PROVIDER", "Getting resource for name #{name} from cloud"

      @forResource(name)
      .then (provider)=>
        provider.getResources()
      .then (resources)=>
        for resource in resources
          if resource.name == name
            resolve(resource)
            return

        reject new ProviderError "Could not find resource for name: #{name}"

  @readRamlFromCloud: =>
    return new Promise (resolve, reject) =>
      steroidsCli.debug "PROVIDER", "getting current data configuration from cloud"

      url = "/app/#{dataHelpers.getAppId()}/raml.yaml?identification_hash=#{dataHelpers.getIdentificationHash()}"

      steroidsCli.debug "PROVIDER", "GETting from URL: #{url}"
      @apiClient.get url, (err, req, res, obj) =>
        @apiClient.close()

        if err?
          steroidsCli.debug "PROVIDER", "Getting current data configuration from cloud returned failure: #{err}"
          reject new CloudReadError err
          return

        if res.statusCode != 200
          steroidsCli.debug "PROVIDER", "Getting current data configuration from cloud returned failure: #{res['body']}"
          reject new CloudReadError res['body']
          return

        steroidsCli.debug "PROVIDER", "Getting current data configuration from cloud returned success"
        resolve(res['body'])

  @writeRamlToFile: (raml)=>
    return new Promise (resolve, reject) =>
      steroidsCli.debug "PROVIDER", "writing current data configuration to file: #{ramlPath}"

      dataHelpers.overwriteFile(ramlPath, raml).then =>
        steroidsCli.debug "PROVIDER", "Wrote current data configuration to file: #{ramlPath}"
        resolve()

  @getAll: =>
    return new Promise (resolve, reject) =>
      steroidsCli.debug "PROVIDER", "Getting providers from cloud"

      @apiClient.get "/app/#{dataHelpers.getAppId()}/service_providers.json", (err, req, res, obj) =>
        @apiClient.close() #TODO: wat

        if err?
          steroidsCli.debug "PROVIDER", "Getting providers from cloud returned failure: #{JSON.stringify(obj)}"
          reject new CloudReadError err
          return

        steroidsCli.debug "PROVIDER", "Getting providers from cloud returned success: #{JSON.stringify(obj)}"
        result = []
        obj.forEach (p)=>
          result.push @fromCloudObject(p)
        resolve result

  @fromCloudObject: (obj)=>
    steroidsCli.debug "PROVIDER", "Constructing a new provider from object: #{JSON.stringify(obj)}"
    provider = new Provider()
    provider.fromCloudObject(obj)

    return provider

  constructor: (@options={}) ->
    @apiClient = Provider.apiClient

    #TODO Provider.fromBackend(backend)
    @backend = @options.backend
    @name = @backend?.providerName
    @typeId = @backend?.providerTypeId

  create: =>
    return new Promise (resolve, reject) =>
      steroidsCli.debug "PROVIDER", "Creating a new provider #{@name} ID: #{@typeId} to cloud"

      data =
        name: @name
        providerTypeId: @typeId
        configurationKeys: @backend.configurationKeysForProxy()

      url = "/app/#{dataHelpers.getAppId()}/service_providers.json"
      steroidsCli.debug "PROVIDER", "POSTing #{JSON.stringify(data)} to URL #{url}"
      @apiClient.post url, data, (err, req, res, obj) =>
        if obj.uid
          steroidsCli.debug "PROVIDER", "Creating a new provider #{@name} ID: #{@typeId} to cloud returned success: #{JSON.stringify(obj)}"

          @fromCloudObject(obj)
          resolve()
        else
          steroidsCli.debug "PROVIDER", "Creating a new provider #{@name} ID: #{@typeId} to cloud returned failure: #{JSON.stringify(obj)}"
          reject new CloudWriteError err

        @apiClient.close()

  fromCloudObject: (obj)=>
    steroidsCli.debug "PROVIDER", "Updating attributes for provider from object: #{JSON.stringify(obj)}"
    @name = obj.name
    @uid = obj.uid
    @typeId = obj.providerTypeId
    @configurationKeys = obj.configurationKeys

  getResources: =>
    return new Promise (resolve, reject) =>
      steroidsCli.debug "PROVIDER", "Getting resources for provider #{@name} ID: #{@typeId} from cloud"

      url = "/app/#{dataHelpers.getAppId()}/service_providers/#{@uid}/resources.json"

      steroidsCli.debug "PROVIDER", "GETting from URL: #{url}"
      @apiClient.get url, (err, req, res, obj) =>
        @apiClient.close()

        if err?
          steroidsCli.debug "PROVIDER", "Getting resources for provider #{@name} ID: #{@typeId} from cloud returned failure: #{err} #{JSON.stringify(obj)}"
          reject new CloudReadError err
          return

        steroidsCli.debug "PROVIDER", "Getting resources for provider #{@name} ID: #{@typeId} from cloud returned success: #{JSON.stringify(obj)}"
        result = []
        for resourceobj in obj
          result.push Resource.fromCloudObject(resourceobj)

        resolve(result)


module.exports = Provider
