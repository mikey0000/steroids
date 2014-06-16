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

data_definition_path = 'config/dolandb.yaml'
raml_path            = 'www/local.raml'
cloud_json_path      = 'config/cloud.json'

db_browser_url       = 'http://dolandb-browser.devgyver.com'
configapi_url        = 'http://config-api.local.testgyver.com:3000'

class Providers
  constructor: (@options={}) ->
    @config_api = restify.createJsonClient
      url: configapi_url
    @config_api.headers["Authorization"] = Login.currentAccessToken()

  all: () =>
    console.log 'Fetching all providers...'
    @config_api.get('/available_service_providers.json', (err, req, res, obj) =>
      console.log 'Available providers:\n'
      obj.forEach (provider) ->
        console.log "  #{provider['human_name']}"
      @config_api.close()
      console.log ''
    )

  # deprekoituu
  ###
  add: (provider_name) =>
    if provider_name? and provider_name!='appgyver_sandbox'
      console.log "Only supported provider 'appgyver_sandbox'"
      process.exit(1)

    config = getConfig()

    if config.resourceProviderUid?
      console.log 'doland db provider exists already'
      process.exit 1

    data =
      providerTypeId: 6,
      name: config['bucket']
      configurationKeys:
        bucket_id: config['bucket_id']
        steroids_api_key: config['apikey']

    console.log "Adding provider '#{provider_name}'' to your app"

    @config_api.post("/app/#{@getAppId()}/service_providers.json", data, (err, req, res, obj) =>

      config.resourceProviderUid = obj['uid']
      saveConfig(config, () ->
        console.log 'done'
      )

      @config_api.close()
    )

  addWas: (provider_name) =>
    if provider_name? and provider_name!='appgyver_sandbox'
      console.log "Only supported provider 'appgyver_sandbox'"
      process.exit(1)

    config = getConfig()

    if config.resourceProviderUid?
      console.log 'doland db provider exists already'
      process.exit 1

    data =
      providerTypeId: 6,
      name: config['bucket']
      configurationKeys:
        bucket_id: config['bucket_id']
        steroids_api_key: config['apikey']

    console.log "Adding provider '#{provider_name}' to your app"

    @config_api.post("/app/#{@getAppId()}/service_providers.json", data, (err, req, res, obj) =>
      console.log err

      config.resourceProviderUid = obj['uid']
      saveConfig(config, () ->
        console.log 'done'
      )

      @config_api.close()
    )

  init: (provider_name) =>
    if provider_name? and provider_name!='appgyver_sandbox'
      console.log "Only supported provider 'appgyver_sandbox'"
      process.exit(1)

    pid = getProviderByName(provider_name)
    unless pid?
      console.log "add first provider with command 'steroids providers:add #{provider_name}'"
      process.exit(1)

    config = getConfig()

    data =
      providerTypeId: 6,
      name: config['bucket']
      configurationKeys:
        bucket_id: config['bucket_id']
        steroids_api_key: config['apikey']

    @config_api.put("/app/#{@getAppId()}/service_providers/#{pid}.json", data, (err, req, res, obj) =>

      config.resourceProviderUid = obj['uid']
      saveConfig(config, () ->
        console.log 'done'
      )

      @config_api.close()
    )
###
  addProvider: (provider_name) =>
    if provider_name? and provider_name != 'appgyver_sandbox'
      console.log "Only supported provider 'appgyver_sandbox'"
      process.exit(1)

    if providerExists(provider_name)
      console.log "Provider '#{provider_name}' is already defined"
      process.exit 1

    data =
      providerTypeId: 6
      name: 'my dolandb'

    console.log "Adding provider '#{provider_name}' to your app"

    @config_api.post("/app/#{@getAppId()}/service_providers.json", data, (err, req, res, obj) =>

      if obj['uid']
        config = {}
        config.resourceProviderUid = obj['uid']
        saveConfig(config, () ->
          console.log 'done'
        )
      else
        console.log err

      @config_api.close()
    )

  initResourceProvider: (provider_name) =>

    unless provider_name?
      console.log "resource provider not specified"
      process.exit(1)

    pid = getProviderByName(provider_name)
    unless pid?
      console.log "add first provider with command 'steroids providers:add #{provider_name}'"
      process.exit(1)

    if providerInitialized(provider_name)
      console.log "provider '#{provider_name}' already initialized"
      process.exit(1)

    console.log providerInitialized(provider_name)

    process.exit 1

    dolandb = new DolanDB
    dolandb.createBucketWithCredentials().then(
      (bucket) =>
        dolandb.createDolandbConfig("#{bucket.login}#{bucket.password}", bucket.name, bucket.datastore_bucket_id)
    ).then(
      (data) =>
        console.log "updating ..."
        @updateProviderInfo(pid)
    )

  updateProviderInfo: (pid) =>

    config = getConfig()

    data =
      providerTypeId: 6,
      name: config['bucket']
      configurationKeys:
        bucket_id: config['bucket_id']
        steroids_api_key: config['apikey']

    console.log "updating resource provider information..."

    @config_api.put("/app/#{@getAppId()}/service_providers/#{pid}.json", data, (err, req, res, obj) =>
      @config_api.close()

      config.resourceProviderUid = obj['uid']
      saveConfig(config, () ->
        console.log 'done'
      )

    )

  remove: (provider_name) =>
    # TODO

  resources: () =>
    config = getConfig()
    provider = config.resourceProviderUid

    console.log 'Listing all resources...'

    @config_api.get("/app/#{@getAppId()}/service_providers/#{provider}/resources.json", (err, req, res, obj) =>
      console.log '\nProvider: appgyver_sandbox'

      obj.forEach (resource) ->
        console.log "  #{resource.name}"
        resource.columns.forEach (column) ->
          console.log "    #{column.name}:#{column.type}"

      console.log ''
      @config_api.close()
    )

  addResource: (provider_name, params) =>
    provider = getProviderByName(provider_name)
    resource_name = params.shift()

    console.log "Adding resource '#{resource_name}' to provider '#{provider_name}'..."

    postData = createPostData(provider_name, resource_name, params)

    @askConfigApiToCreateResource(provider, postData).then(
      () =>
        @saveRamlToFile()
      , (error) ->
        console.log error
    )

  # helpers

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
        deferred.reject(JSON.parse(err.message).join(', '))
      else if noServiceProvider(err)
        deferred.reject(["service provider is not defined"])
      else
        console.log "done"
        deferred.resolve()
    )

    return deferred.promise

  getAppName: () =>
    "my awesome app"
    # read from file

  getAppId: () =>
    getFromCloudJson('id')
    #5425
    #5413
    #5282
    #5281
    #5951
    #12165

  providerExists = (name) ->
    if fs.existsSync(data_definition_path)
      getProviderByName(name)?
    else
      false

  providerInitialized = (name) ->
    config = getConfig()
    config.bucket_id?

  getProviderByName = (name) ->
    # fetch from config api
    unless name == "appgyver_sandbox"
      console.log "provider not defined: '#{name}'"
      process.exit 1

    config = getConfig()
    unless config.resourceProviderUid?
      console.log "provider not defined: '#{name}'"
      process.exit 1

    config.resourceProviderUid

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