restify = require "restify"
util = require "util"
yaml = require 'js-yaml'
Login = require "./Login"
DolanDB = require "./DolanDB"
q = require "q"
fs = require "fs"
URL = require "url"
http = require 'http'
open = require "open"
paths = require "./paths"
env = require("yeoman-generator")()
Help = require "./Help"
chalk = require "chalk"

data_definition_path = 'config/dolandb.yaml'
raml_path            = 'www/local.raml'
cloud_json_path      = 'config/cloud.json'

db_browser_url       = 'http://sandboxdb.testgyver.com/browser/projects/'
configapi_url        = 'http://config-api.testgyver.com'

#configapi_url        = 'http://config-api.local.testgyver.com:3000'
#db_browser_url       = 'http://sandboxdb.local.testgyver.com:3000/browser/projects/'

class Providers
  constructor: (@options={}) ->
    @config_api = restify.createJsonClient
      url: configapi_url
    @config_api.headers["Authorization"] = Login.currentAccessToken()
    @db_browser = restify.createJsonClient
      url: db_browser_url

  listProviders: () =>
    console.log "Fetching all providers...\n"
    @config_api.get('/available_service_providers.json', (err, req, res, obj) =>
      if err?
        Help.error()
        console.log(
          """
          Could not get list of available providers. Please check your
          Internet connection.

          In case of a service outage, more information is available at

            #{chalk.underline('http://status.appgyver.com')}

          """
          )
      else
        console.log "Available providers:\n"
        obj.forEach (provider) ->
          console.log "  #{provider.human_name}"
        console.log ""
      @config_api.close()
    )

  addProvider: (provider_name) =>
    if provider_name? and provider_name != 'appgyver_sandbox'
      console.log "Only supported provider 'appgyver_sandbox'"
      process.exit 1

    @getProviderByName(provider_name).then(
      (provider) =>
        if provider?
          console.log "Provider '#{provider_name}' is already defined"
          process.exit 1

        data =
          providerTypeId: 6    # appgyver_sandbox id specified in config api
          name: provider_name

        console.log "Adding provider '#{provider_name}' to your app"

        @config_api.post("/app/#{@getAppId()}/service_providers.json", data, (err, req, res, obj) =>

          if obj['uid']
            console.log 'done'
          else
            console.log err

          @config_api.close()
        )
      (error) =>
        errorObject = JSON.parse(error)
        Help.error()
        console.log "\nCould not add provider: #{errorObject.error}"
    )

  removeProvider: (provider_name) =>
    @getProviderByName(provider_name).then (provider) =>

      console.log "removing provider #{provider_name}"
      @config_api.del("/app/#{@getAppId()}/service_providers/#{provider}.json", data, (err, req, res, obj) =>
        console.log 'done'
        @config_api.close()
      )

  initResourceProvider: (provider_name) =>
    unless provider_name?
      console.log "resource provider not specified"
      process.exit 1

    @getProviderByName(provider_name).then (provider) =>

      unless provider?
        console.log "add first provider with command 'steroids providers:add #{provider_name}'"
        process.exit 1

      if resourceProviderInitialized(provider_name)
        console.log "resource provider '#{provider_name}' already initialized"
        process.exit 1

      console.log "provisioning database from #{provider_name}"

      dolandb = new DolanDB
      dolandb.createBucketWithCredentials().then(
        (bucket) =>
          console.log "done"
          dolandb.createDolandbConfig("#{bucket.login}#{bucket.password}", bucket.name, bucket.datastore_bucket_id)
      ).then(
        (data) =>
          @updateProviderInfo(provider)
      )

  removeResource: (resource_to_be_removed) =>
    #should loop through all providers
    @getProviderByName('appgyver_sandbox').then (provider) =>

      console.log "removing #{resource_to_be_removed}"

      console.log resource_to_be_removed

      @config_api.get("/app/#{@getAppId()}/service_providers/#{provider}/resources.json", (err, req, res, obj) =>
        @config_api.close()
        obj.forEach (resource) =>
          if resource.name == resource_to_be_removed
            @config_api.del("/app/#{@getAppId()}/service_providers/#{provider}/resources/#{resource.uid}.json", (err, req, res, obj) =>
              console.log "done"
              @config_api.close()
            )
      )

  resources: () =>
    @config_api.get("/app/#{@getAppId()}/service_providers.json", (err, req, res, obj) =>
      obj.forEach (providerObject) =>
        console.log 'Listing all resources...'

        @config_api.get("/app/#{@getAppId()}/service_providers/#{providerObject.uid}/resources.json", (err, req, res, obj) =>
          console.log "\nProvider: #{providerObject.name}"

          obj.forEach (resource) ->
            console.log "  #{resource.name}"
            resource.columns.forEach (column) ->
              console.log "    #{column.name}:#{column.type}"

          console.log ''
          @config_api.close()
        )
    )

  addResource: (provider_name, params) =>
    @getProviderByName(provider_name).then (provider) =>
      resource_name = params.shift()

      console.log "Adding resource '#{resource_name}' to provider '#{provider_name}'..."

      postData = createPostData(provider_name, resource_name, params)

      @askConfigApiToCreateResource(provider, postData).then(
        () =>
          @saveRamlToFile()
        , (error) ->
          console.log error
      )

  browseResoures: (provider_name, params) =>
    open URL.format("#{db_browser_url}#{@getAppId()}")

  scaffoldResoures: () =>
    # should iterate over providers
    @getProviderByName('appgyver_sandbox').then (provider) =>

      @config_api.get("/app/#{@getAppId()}/service_providers/#{provider}/resources.json", (err, req, res, obj) =>
        console.log "you can scaffold code skeletons by running"
        obj.forEach (resource) ->
          columns = resource.columns.map (column) -> column.name
          arg = "#{resource.name} #{columns.join(' ')}"
          console.log " yo devroids:dolan-res #{arg}"

        @config_api.close()
      )

  # mostly for debugging
  listMyProviders: () =>
    @config_api.get("/app/#{@getAppId()}/service_providers.json", (err, req, res, obj) =>
      if obj.length==0
        console.log 'no providers defined'
      else
        obj.forEach (provider) ->
          console.log provider
      @config_api.close()
    )

  # helpers

  updateProviderInfo: (provider) =>
    config = getConfig()

    data =
      providerTypeId: 6,
      name: 'appgyver_sandbox'
      configurationKeys:
        bucket_id: config['bucket_id']
        steroids_api_key: config['apikey']

    console.log "updating resource provider information..."

    @config_api.put("/app/#{@getAppId()}/service_providers/#{provider}.json", data, (err, req, res, obj) =>
      @config_api.close()
      console.log 'done'
      # restify does not close...
      process.exit 1
    )

  saveRamlToFile: () =>
    @config_api.headers["Accept"] = "text/yaml"
    url = "/app/#{@getAppId()}/raml?identification_hash=#{getIdentificationHash()}"

    console.log 'Downloading and overriding RAML from config-api...'

    @config_api.get(url, (err, req, res, obj) =>
      @config_api.close()

      saveRamlLocally res['body'], ->
        console.log 'done'
    )

  askConfigApiToCreateResource: (provider, postData) =>
    deferred = q.defer()

    url = "/app/#{@getAppId()}/service_providers/#{provider}/resources.json"

    @config_api.post(url, postData, (err, req, res, obj) =>
      @config_api.close()
      if err?
        deferred.reject(err.message)
      else if noServiceProvider(err)
        deferred.reject(["service provider is not defined"])
      else
        console.log "done"
        deferred.resolve()
    )

    return deferred.promise

  getAppId: () =>
    getFromCloudJson('id')

  providerExists = (name) ->
    if fs.existsSync(data_definition_path)
      getProviderByName(name)?
    else
      false

  updateConfig = (config) ->
    fs.writeFileSync(data_definition_path, yaml.safeDump(config))

  resourceProviderInitialized = (name) ->
    return false unless fs.existsSync(data_definition_path)
    config = getConfig()
    config.bucket_id?

  getLocalRaml = ->
    fs.readFileSync(raml_path, 'utf8')

  getProviderByName: (name) ->
    deferred = q.defer()

    @config_api.get("/app/#{@getAppId()}/service_providers.json", (err, req, res, obj) =>
      @config_api.close()
      obj.forEach (provider) ->
        if (name== "appgyver_sandbox" and provider.providerTypeId==6)
          deferred.resolve(provider.uid)
      deferred.resolve(null)

    )

    return deferred.promise

  createPostData = (provider_name, resource_name, params) ->
    config = getConfig()
    bucket = config.bucket

    validateName(resource_name)

    data =
      name: resource_name
      path: bucket+'/'+resource_name
      columns: []

    if params.length==0
      console.log "resource should have at least one column"
      process.exit 1

    params.forEach (column) ->
      validateColumn(column)
      [_name, _type] = column.split(':')
      data.columns.push { name:_name, type:_type}

    data

  getConfig = () ->
    yaml.safeLoad readConfigFromFile()

  readConfigFromFile = () ->
    try return fs.readFileSync(data_definition_path, 'utf8')
    catch e
      console.log "you must first init dolandb with command 'steroids dolandb init'"
      process.exit 1

  getIdentificationHash = ->
    getFromCloudJson('identification_hash')

  getFromCloudJson = (param) ->
    cloud_json_path = "config/cloud.json"

    unless fs.existsSync(cloud_json_path)
      console.log "application needs to be deployed before provisioning a dolandb, please run steroids deploy"
      process.exit 1

    cloud_json = fs.readFileSync(cloud_json_path, 'utf8')
    cloud_obj = JSON.parse(cloud_json)
    return cloud_obj[param]

  saveConfig = (config, cb) ->
    fs.writeFile(data_definition_path, yaml.safeDump(config), (err,data) =>
      cb()
    )

  validateName = (string) ->
    valid = /^[a-z_]*$/
    return true if string.match valid

    console.log "only lowcase alphabeths and underscore allowed: '#{string}'"
    process.exit 1

  validateColumn = (string) ->
    parts = string.split(':')
    unless parts.length==2
      console.log "column definition illegal: '#{string}'"
      process.exit 1
    validateName parts[0]
    validateType parts[1]

  validateType = (string) ->
    allowed = ["string", "integer", "boolean", "number", "date"]
    return true if string in allowed

    console.log "type '#{string}' not within allowed: #{allowed.join(', ')}"
    process.exit 1

  noServiceProvider = (err) ->
    return false unless err?
    JSON.parse(err.message).error == 'service provider not found'

  saveRamlLocally = (raml_file_content, cb) ->
    fs.writeFile(raml_path, raml_file_content, (err,data) ->
      cb()
    )

module.exports = Providers