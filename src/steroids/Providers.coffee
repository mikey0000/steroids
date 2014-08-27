restify = require "restify"
util = require "util"
yaml = require 'js-yaml'
Login = require "./Login"
SandboxDB = require "./SandboxDB"
SandboxScaffoldGenerator = require "./generators/sandbox/SandboxScaffold"
q = require "q"
fs = require "fs"
URL = require "url"
http = require 'http'
open = require "open"
paths = require "./paths"
env = require("yeoman-generator")()
Help = require "./Help"
chalk = require "chalk"

data_definition_path = 'config/sandboxdb.yaml'
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
        Help.connectError "Could not fetch list of available providers."
      else
        console.log "Available providers:\n"
        obj.forEach (provider) ->
          console.log "  #{provider.human_name}"
        console.log ""
      @config_api.close()
    )

  ensureSandboxProvider: =>
    deferred = q.defer()

    console.log("Ensuring that your app has the SandboxDB data provider configured...")

    @getProviderByName("appgyver_sandbox").then(
      (provider) =>
        if provider?
          # provider exists, all good
          deferred.resolve()
        else
          deferred.reject "Got empty provider, something's wrong. :("
      (error) =>
        console.log "SandboxDB data provider not found, adding it for your app..."
        data =
          providerTypeId: 6    # appgyver_sandbox id specified in config api
          name: "appgyver_sandbox"

        @config_api.post "/app/#{@getAppId()}/service_providers.json", data, (err, req, res, obj) =>
          if obj['uid']
            deferred.resolve "Provider successfully added!"
          else
            deferred.reject err

          @config_api.close()
    )

    deferred.promise

  # new method
  initDatabase: (provider_name = 'appgyver_sandbox') =>
    deferred = q.defer()

    self = this

    @getProviderByName(provider_name).then(
      (provider) =>
        console.log "SandboxDB provider was already created"
        deferred.resolve(provider)
        # TODO: deside what to do with empty provider
      (error) =>
        console.log "SandboxDB provider not found"
        # console.log error
        self.addProvider(provider_name).then (provider)->
          self.initResourceProvider(provider).then ()->
            deferred.resolve(provider)
          # TODO: remove the remove when finished
          self.removeProvider("appgyver_sandbox").then (res)->
            console.log 'pr removed'
    )
    deferred.promise

  addProvider: (provider_name, data) =>
    deferred = q.defer()

    console.log "Adding a provider"

    data = data || @_getDefaultProviderData(provider_name)

    @config_api.post "/app/#{@getAppId()}/service_providers.json", data, (err, req, res, obj) =>
      if obj['uid']
        console.log "Provider successfully added!"
        deferred.resolve obj
      else
        deferred.reject err

      @config_api.close()

    deferred.promise


  _getDefaultProviderData: (provider_name) =>
    return {
      providerTypeId: 6    # appgyver_sandbox id specified in config api
      name: provider_name
    }

  # Should be used only when multiple providers are implemented
  # TODO: Remove when not needed
  addProviderOld: (provider_name) =>
    console.log 'Adding a provider'
    if provider_name? and provider_name != 'appgyver_sandbox'
      Help.error()
      console.log "Only supported provider is 'appgyver_sandbox'"
      process.exit 1

    @getProviderByName(provider_name).then(
      (provider) =>
        if provider?
          Help.error()
          console.log "Provider '#{provider_name}' is already defined"
          process.exit 1

        data =
          providerTypeId: 6    # appgyver_sandbox id specified in config api
          name: provider_name

        console.log "Adding provider '#{provider_name}' to your app..."

        @config_api.post("/app/#{@getAppId()}/service_providers.json", data, (err, req, res, obj) =>

          if obj['uid']
            Help.success()
            console.log "Provider successfully added!"
          else
            Help.error()
            console.log err

          @config_api.close()
        )
      (error) =>
        errorObject = JSON.parse(error)
        Help.error()
        console.log "\nCould not add provider: #{errorObject.error}"
    )

  removeProvider: (provider_name) =>
    deferred = q.defer()

    @getProviderByName(provider_name).then (provider) =>

      console.log "Removing provider #{provider_name}..."
      @config_api.del("/app/#{@getAppId()}/service_providers/#{provider}.json", (err, req, res, obj) =>
        console.log 'done'
        @config_api.close()
        deferred.resolve()
      )
    deferred.promise

  initResourceProvider: (provider) =>

    # TODO: Refactor this method
    provider_name = provider.name

    deferred = q.defer()

    console.log "Provisioning a SandboxDB database for your app..."

    unless provider_name?
      deferred.reject "Resource provider not specified."

    @getProviderByName(provider_name).then (provider) =>

      if resourceProviderInitialized(provider_name)
        console.log(
          """
          SandboxDB database already provisioned and configured at

            #{chalk.bold("config/sandboxdb.yaml")}

          All good!
          """
        )
        deferred.resolve()
      else

        sandboxDB = new SandboxDB
        sandboxDB.createBucketWithCredentials().then(
          (bucket) =>
            console.log "Database provisioned, creating a local config file..."
            sandboxDB.createSandboxDBConfig("#{bucket.login}#{bucket.password}", bucket.name, bucket.datastore_bucket_id)
        ).then (data) =>
          console.log "Local config file created at #{chalk.bold("config/sandboxdb.yaml")}"
          @updateProviderInfo(provider)
          deferred.resolve()

    deferred.promise

  getResourceObjectByName: (resource_name) =>
    deferred = q.defer()
    @getProviderByName('appgyver_sandbox').then (provider) =>
      @config_api.get("/app/#{@getAppId()}/service_providers/#{provider}/resources.json", (err, req, res, obj) =>
        if err?
          deferred.reject(err)

        @config_api.close()
        obj.forEach (resourceFromBackend) =>
          if resourceFromBackend.name == resource_name
            deferred.resolve resourceFromBackend

        deferred.reject "Could not find resource #{chalk.bold(resource_name)} in your SandboxDB."
      )

    deferred.promise

  removeResource: (resource_to_be_removed) =>
    deferred = q.defer()

    console.log "Removing resource #{chalk.bold(resource_to_be_removed)}..."
    #should loop through all providers
    @getResourceObjectByName().then (resourceObject) =>
      @config_api.del("/app/#{@getAppId()}/service_providers/#{provider}/resources/#{resource.uid}.json", (err, req, res, obj) =>
        @config_api.close()

        if err?
          deferred.reject "Could not remove resource #{resourceObject.name}"

        console.log "Done."
        deferred.resolve()
      ).fail (error)=>
        console.log error

    deferred.promise

  # Usable only after support for multiple providers per app
  resources: () =>
    console.log "Listing all resources..."
    @config_api.get("/app/#{@getAppId()}/service_providers.json", (err, req, res, obj) =>
      if err?
        errorObject = JSON.parse(err)
        Help.error()
        console.log "Could not list resources. Error message: "
      else if obj.length is 0
        Help.error()
        console.log "No providers found. Add a provider to list resources."
        process.exit(1)
      else
        obj.forEach (providerObject) =>

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

  resourcesForSandbox: () =>
    console.log "Fetching list of resources for your SandboxDB..."
    @getProviderByName('appgyver_sandbox').then (providerUid) =>
      @config_api.get("/app/#{@getAppId()}/service_providers/#{providerUid}/resources.json", (err, req, res, obj) =>
        if err?
          Help.error()
          console.log(
            """
            Could not fetch list of resources for your SandboxDB. Ensure that
            you've set up your SandboxDB for this app with

              #{chalk.bold("$ steroids resources:init")}

            """
          )
        else if obj.length is 0
          Help.error()
          console.log(
            """
            No resources found for your app. You can add resources
            with the command:

              #{chalk.bold("$ steroids resources:add resourceName")}

            """
          )
        else
          console.log "Resources for your app: \n\n"
          obj.forEach (resource)->
            console.log "  #{resource.name}"
            resource.columns.forEach (column) ->
              console.log "    #{column.name}:#{column.type}"
        @config_api.close()
      )

  # only for SandboxDB
  addResource: (provider_name, params) =>
    @getProviderByName(provider_name).then(
      (provider) =>
        resource_name = params.shift()

        console.log "Adding resource #{chalk.bold(resource_name)} to SandboxDB..."

        postData = createPostData(provider_name, resource_name, params)

        @askConfigApiToCreateResource(provider, postData).then(
          () =>
            @saveRamlToFile()
          , (error) ->
            Help.error()
            console.log "Could not add resource #{chalk.bold(resource_name)}. Error: #{error}"
        )
      (error) =>
        errorObject = JSON.parse(error)
        Help.error()
        console.log "\nCould not add resource: #{errorObject.error}"
    )


  browseResoures: (provider_name, params) =>
    open URL.format("#{db_browser_url}#{@getAppId()}")

  scaffoldResource: (resource_name) =>
    deferred = q.defer()

    console.log "Creating a scaffold for resource #{chalk.bold(resource_name)}..."
    @getResourceObjectByName(resource_name).then((resourceObject)=>
      console.log "Got resource from backend..."
      @generateScaffoldForResource resourceObject
    ).fail (error)=>
      deferred.reject(error)

    deferred.promise


  generateScaffoldForResource: (resource)->
    columns = resource.columns.map (column) -> column.name
    args = "#{resource.name} #{columns.join(' ')}"

    generator = new SandboxScaffoldGenerator {args: args}

    try
      generator.generate()
    catch error
      throw error unless error.fromSteroids?

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

    console.log "Updating SandboxDB data provider information..."

    @config_api.put("/app/#{@getAppId()}/service_providers/#{provider}.json", data, (err, req, res, obj) =>
      @config_api.close()
      console.log 'Done, all good!'
      # restify does not close...
      process.exit 1
    )

  saveRamlToFile: () =>
    @config_api.headers["Accept"] = "text/yaml"
    url = "/app/#{@getAppId()}/raml?identification_hash=#{getIdentificationHash()}"

    console.log "Downloading new RAML and overwriting #{chalk.bold("config/sandboxdb.yaml")}..."

    @config_api.get(url, (err, req, res, obj) =>
      @config_api.close()

      saveRamlLocally res['body'], ->
        console.log "Done."
    )

  askConfigApiToCreateResource: (provider, postData) =>
    deferred = q.defer()

    url = "/app/#{@getAppId()}/service_providers/#{provider}/resources.json"

    @config_api.post(url, postData, (err, req, res, obj) =>
      @config_api.close()
      if err?
        deferred.reject(err.body[0])
      else if noServiceProvider(err)
        deferred.reject("Service provider is not defined.")
      else
        console.log "Done."
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

  # only gets appgyver_sandbox provider
  getProviderByName: (name) ->
    deferred = q.defer()

    @config_api.get("/app/#{@getAppId()}/service_providers.json", (err, req, res, obj) =>
      @config_api.close()
      if err?
        deferred.reject(err.message)
      else
        obj.forEach (provider) ->
          if (name == "appgyver_sandbox" and provider.providerTypeId==6)
            deferred.resolve(provider.uid)
        # errorMsg =
        #   """
        #   Provider with name #{chalk.bold(provider_name)} not found.

        #   You can list available providers with

        #     #{chalk.bold("$ steroids providers")}

        #   You can then add the provider for your app with the command

        #     #{chalk.bold("$ steroids providers:add providerName")}
        #   """

        errorMsg =
          """
          Could not find the sandbox data provider for your app. Please run

            #{chalk.bold("$ steroids resources:init")}

          which will ensure the sandbox data provider is set up correctly.

          """
        deferred.reject errorMsg
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
      Help.error()
      console.log(
        """
        Could not read file #{chalk.bold("config/sandboxdb.yaml")}. You must
        initialize your SandboxDB with

          #{chalk.bold("$ steroids sandbox resources:init")}

        """
      )
      process.exit 1

  getIdentificationHash = ->
    getFromCloudJson('identification_hash')

  getFromCloudJson = (param) ->
    cloud_json_path = "config/cloud.json"

    unless fs.existsSync(cloud_json_path)
      Help.deployRequiredForSandboxDBProvisioning()
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

    Help.error()
    console.log "Only lowcase alphabets and underscores allowed: '#{string}'"
    process.exit 1

  validateColumn = (string) ->
    parts = string.split(':')
    unless parts.length==2
      Help.error()
      console.log(
        """
        Illegal column definition: #{chalk.bold(string)}

        Columns must be of format: #{chalk.bold("columnName:columnType")}
        """
      )
      process.exit 1
    validateName parts[0]
    validateType parts[1]

  validateType = (string) ->
    allowed = ["string", "integer", "boolean", "number", "date"]
    return true if string in allowed

    Help.error()
    console.log(
      """
      Invalid column type #{chalk.bold(string)}.

      Allowed column types: #{allowed.join(', ')}
      """
    )
    process.exit 1

  noServiceProvider = (err) ->
    return false unless err?
    JSON.parse(err.message).error == 'service provider not found'

  saveRamlLocally = (raml_file_content, cb) ->
    fs.writeFile(raml_path, raml_file_content, (err,data) ->
      cb()
    )

module.exports = Providers
