restify = require "restify"
util = require "util"
yaml = require 'js-yaml'
Login = require "./Login"
q = require "q"
fs = require "fs"
URL = require "url"
http = require 'http'
open = require "open"
exec = require('child_process').exec
ejs = require('ejs')
paths = require "./paths"
env = require("yeoman-generator")()

data_definition_path = 'config/dolandb.yaml'
raml_path            = 'www/local.raml'
cloud_json_path      = 'config/cloud.json'

dolan_db_base_url    = 'http://datastorage-api.devgyver.com'
dolan_db_url         = "#{dolan_db_base_url}/v1/datastorage"
db_browser_url       = 'http://dolandb-browser.devgyver.com'
configapi_url        = 'http://config-api.local.testgyver.com:3000'

#dolan_db_base_url = "http://datastorage-api.local.devgyver.com:3001/"
#db_browser_url = 'http://localhost:3001'

###

  NOTE:

  devroids login --authUrl="http://accounts.testgyver.com"

###

# not needed anymore
request = require('request-json')
DbBrowser = request.newClient(db_browser_url)

#
# TODO:
#   add REMOVE RESOURCE
#

class DolanDB
  getAppName: () =>
    "my awesome app"

  getAppId: () =>
    getFromCloudJson('id')
    #5425
    #5413
    #5282
    #5281
    #5951
    #12165

  constructor: (@options={}) ->
    @dolandbProvisionApi = restify.createJsonClient
      url: dolan_db_base_url
    @dolandbProvisionApi.basicAuth Login.currentAccessToken(), 'X'

    @composer = restify.createJsonClient
      url: configapi_url
    @composer.headers["Authorization"] = Login.currentAccessToken()

    @db_browser = restify.createJsonClient
      url: db_browser_url

  getConfig = () ->
    yaml.safeLoad readConfigFromFile()

  readConfigFromFile = () ->
    try return fs.readFileSync(data_definition_path, 'utf8')
    catch e
      console.log "you must first init dolandb with command 'steroids dolandb init'"
      process.exit 1

  noServiceProvider = (err) ->
    return false unless err?
    JSON.parse(err.message).error == 'service provider not found'

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

  getLocalRaml = ->
    fs.readFileSync(raml_path, 'utf8')

  saveRamlLocally = (raml_file_content, cb) ->
    fs.writeFile(raml_path, raml_file_content, (err,data) ->
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

  saveConfig = (config, cb) ->
    fs.writeFile(data_definition_path, yaml.safeDump(config), (err,data) =>
      cb()
    )

  updateConfig = (config) ->
    fs.writeFileSync(data_definition_path, yaml.safeDump(config))


  provider: (params) =>
    ###
      workflow:
        ensure that a uniq appid in cloud.json

        dolandb init (provisions a db using dolan provision api)

        provider initialize
            initializes a dolan db-provider in config-api
        provider resource beer name:string brewery:string
            initializes a resource in config-api
        provider raml
            gets a raml and writes it to www/local.raml

        provider sync
            opens (and syncs) dolandb browser

        yo devroids:dolan-res beer name brewery alcohol
          generates a crud app

        update application.coffee to point to created resources

      other:

        provider resources
            lists your defined resources
        provider remove_resouce <name>
            removes the resource
        provider scaffold
            shows commands to scaffold code templates
        provider my
            shows defined providers
        provider remove_provider <id>
            removes provider with <id>
        provider all
            show all existing providers

    ###

    com = params.shift()

    if com=='initialize'

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

      @composer.post("/app/#{@getAppId()}/service_providers.json", data, (err, req, res, obj) =>
        config.resourceProviderUid = obj['uid']

        saveConfig(config, () ->
          console.log 'dolandb resource provider created'
        )

        @composer.close()
      )

    if com=="remove_resource"
      resource_to_be_removed = params.shift()

      config = getConfig()
      provider = config.resourceProviderUid

      @composer.get("/app/#{@getAppId()}/service_providers/#{provider}/resources.json", (err, req, res, obj) =>
        @composer.close()
        obj.forEach (resource) =>
          if resource.name == resource_to_be_removed
            @composer.del("/app/#{@getAppId()}/service_providers/#{provider}/resources/#{resource.uid}.json", (err, req, res, obj) =>
              console.log "#{resource_to_be_removed} removed"
              @composer.close()
            )
      )

      url = "/app/#{@getAppId()}/service_providers/#{provider}/resources.json"



    if com=="resource"
      resource_name = params.shift()
      validateName(resource_name)

      config = getConfig()

      provider = config.resourceProviderUid
      bucket = config.bucket

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

      url = "/app/#{@getAppId()}/service_providers/#{provider}/resources.json"

      @composer.post(url, data, (err, req, res, obj) =>
        if err?
          JSON.parse(err.message).forEach (message) ->
            console.log
        else if noServiceProvider(err)
          console.log "service provider is not defined"
          console.log "run first 'devroids dolandb test provision'"
        else
          console.log "resource #{resource_name} defined"
          scaffold = "you can scaffold code skeleton by running 'yo devroids:dolan-res #{resource_name} #{params.join(' ')}'"
          console.log scaffold
          ## perhaps raml should be synched???
        @composer.close()
      )

    if com=="raml"
      @composer.headers["Accept"] = "text/yaml"
      url = "/app/#{@getAppId()}/raml?identification_hash=#{getIdentificationHash()}"

      @composer.get(url, (err, req, res, obj) =>
        @composer.close()

        saveRamlLocally res['body'], ->
          console.log 'raml saved'
      )

    if com=='sync'
      raml = getLocalRaml()
      config = getConfig()

      if config.browser_id?
        # browser instance exists
        @db_browser.put("/ramls/#{config.browser_id}", { raml: { content:raml } }, (err, req, res, obj) =>
          @db_browser.close()
          open URL.format("#{db_browser_url}/#browser/#{config.browser_id}")
        )

      else
        # create a new browser instance
        post_data =
          content: raml
          bucket_id: config.bucket_id
          application_name: @getAppName()

        @db_browser.post('/ramls', { raml: post_data }, (err, req, res, obj) =>
          @db_browser.close()

          config.browser_id = obj.id
          open URL.format("#{db_browser_url}/#browser/#{config.browser_id}")
          updateConfig(config)
        )

    if com=='all'
      @composer.get('/available_service_providers.json', (err, req, res, obj) =>
        console.log obj
        @composer.close()
      )

    if com=='my'
      @composer.get("/app/#{@getAppId()}/service_providers.json", (err, req, res, obj) =>
        if obj.length==0
          console.log 'no providers defined'
        else
          console.log obj
        @composer.close()
      )

    if com=='remove_provider'
      id = params.shift()

      @composer.del("/app/#{@getAppId()}/service_providers/#{id}.json", data, (err, req, res, obj) =>
        console.log 'provider removed'
        @composer.close()
      )

    if com=='resources'
      config = getConfig()
      provider = config.resourceProviderUid

      @composer.get("/app/#{@getAppId()}/service_providers/#{provider}/resources.json", (err, req, res, obj) =>
        obj.forEach (resource) ->
          console.log resource.name
          resource.columns.forEach (column) ->
            console.log " #{column.name}:#{column.type}"

        @composer.close()
      )

    if com=='scaffold'
      config = getConfig()
      provider = config.resourceProviderUid

      @composer.get("/app/#{@getAppId()}/service_providers/#{provider}/resources.json", (err, req, res, obj) =>
        console.log "you can scaffold code skeletons by running"
        obj.forEach (resource) ->
          columns = resource.columns.map (column) -> column.name
          arg = "#{resource.name} #{columns.join(' ')}"
          console.log " yo devroids:dolan-res #{arg}"

        @composer.close()
      )

  initialize: (options={}) =>
    console.log 'initializing DolanDB...'

    unless fs.existsSync(cloud_json_path)
      console.log "you should deploy the project first by giving command 'steroids deploy'"
      return

    if fs.existsSync(data_definition_path)
      console.log "file #{data_definition_path} exists!"
      return

    @createBucketWithCredentials()
    .then(
      (bucket) =>
        @createDolandbConfig("#{bucket.login}#{bucket.password}", bucket.name, bucket.datastore_bucket_id)
    ).then(
      () =>
        console.log "dolandb initialized"
        console.log "continue with defining provider and resources..."
        @dolandbProvisionApi.close()
      , (err) ->
        # better error?
        console.log JSON.stringify err
        @dolandbProvisionApi.close()
    )

  createBucketWithCredentials: () =>
    deferred = q.defer()

    data =
      appId: @getAppId()

    @dolandbProvisionApi.post('/v1/credentials/provision', { data: data }, (err, req, res, obj) =>
      if obj.code==201
        deferred.resolve(obj.body)
      else
        deferred.reject(obj)
    )

    return deferred.promise

  createDolandbConfig: (apikey, database, bucket_id) =>
    deferred = q.defer()

    doc =
      name: @getAppName()
      apikey: apikey
      bucket: database
      bucket_id: bucket_id

    fs.writeFile(data_definition_path, yaml.safeDump(doc), (err,data) ->
      deferred.resolve()
    )
    return deferred.promise

## old ->

  test2: () =>
    env.plugins "node_modules", paths.npm
    env.lookup '*:*'
    env.run "devroids:dolan-res", () ->
    #env.run "devroids:app lol", () ->
      console.log 'ME'

  drop: () =>
    fs.unlink(data_definition_path, () ->
      # destroy db credentials
      console.log 'database dropped'
    )

module.exports = DolanDB

