# util = require "util"
# fs = require "fs"
# http = require 'http'

# env = require("yeoman-generator")()

restify = require "restify"
# yaml = require 'js-yaml'
# q = require "q"

# paths = require "./paths"
Login = require "./Login"
# DataModuleGenerator = require "./generators/DataModule"
dataHelpers = require "./dataHelpers"

raml_path            = 'www/cloud.raml'
cloud_json_path      = 'config/cloud.json'
configapi_url        = 'https://config-api.appgyver.com'

class Provider
  @ProviderError: class ProviderError extends steroidsCli.SteroidsError
  @CloudReadError: class CloudReadError extends ProviderError
  @CloudWriteError: class CloudWriteError extends ProviderError

  @config_api = restify.createJsonClient
    url: configapi_url
  @config_api.headers["Authorization"] = Login.currentAccessToken()

  @forBackend: (backend) =>
    return new Promise (resolve, reject) =>
      steroidsCli.debug "PROVIDER", "Getting a provider for backend #{backend.providerName}"

      @getAll().then (providers)=>
        steroidsCli.debug "PROVIDER", "Got some providers: #{JSON.stringify(providers)}"

        # providers.find { |p| p.providerTypeId == backend.providerTypeId }
        provider = null
        providers.forEach (p)=>
          provider = p if p.providerTypeId == backend.providerTypeId

        if provider?
          steroidsCli.debug "PROVIDER", "provider for backend #{backend.providerTypeId} already exists"
          resolve()
        else
          steroidsCli.debug "PROVIDER", "provider for backend #{backend.providerTypeId} not found, creating a new one"
          provider = new Provider
            backend: backend

          provider.create()
          .then resolve(provider)

  @getAll: =>
    return new Promise (resolve, reject) =>
      steroidsCli.debug "PROVIDER", "Getting providers from cloud"

      @config_api.get "/app/#{dataHelpers.getAppId()}/service_providers.json", (err, req, res, obj) =>
        @config_api.close() #TODO: wat

        if err?
          steroidsCli.debug "PROVIDER", "Getting providers from cloud returned failure: #{JSON.stringify(obj)}"
          reject new CloudReadError err
          return

        steroidsCli.debug "PROVIDER", "Getting providers from cloud returned success: #{JSON.stringify(obj)}"
        resolve obj

  constructor: (@options={}) ->
    @config_api = restify.createJsonClient
      url: configapi_url
    @config_api.headers["Authorization"] = Login.currentAccessToken()

    @backend = @options.backend
    @name = @backend.providerName
    @typeId = @backend.providerTypeId

  create: =>
    return new Promise (resolve, reject) =>
      steroidsCli.debug "PROVIDER", "Creating a new provider #{@name} ID: #{@typeId} to cloud"

      data =
        name: @name
        providerTypeId: @typeId
        configurationKeys: @backend.configurationKeysForProxy()

      url = "/app/#{dataHelpers.getAppId()}/service_providers.json"
      steroidsCli.debug "PROVIDER", "POSTing #{JSON.stringify(data)} to URL #{url}"
      @config_api.post url, data, (err, req, res, obj) =>
        if obj['uid']
          steroidsCli.debug "PROVIDER", "Creating a new provider #{@name} ID: #{@typeId} to cloud returned success: #{JSON.stringify(obj)}"
          resolve()
        else
          steroidsCli.debug "PROVIDER", "Creating a new provider #{@name} ID: #{@typeId} to cloud returned failure: #{JSON.stringify(obj)}"
          reject new CloudWriteError err

        @config_api.close()


module.exports = Provider
