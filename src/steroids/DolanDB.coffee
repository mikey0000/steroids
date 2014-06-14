restify = require "restify"
util = require "util"
yaml = require 'js-yaml'
Login = require "./Login"
q = require "q"
fs = require "fs"
URL = require "url"
http = require 'http'
open = require "open"
request = require('request-json')
exec = require('child_process').exec
ejs = require('ejs')
paths = require "./paths"
env = require("yeoman-generator")()

data_definition_path = "config/dolandb.yaml"

#dolan_db_base_url = "http://datastorage-api.local.devgyver.com:3000/"
dolan_db_base_url = 'http://datastorage-api.devgyver.com'
dolan_db_url = "#{dolan_db_base_url}/v1/datastorage"

db_browser_url = 'http://dolandb-browser.devgyver.com'
#db_browser_url = 'http://localhost:3001'

###

  NOTE:

  devroids login --authUrl="http://accounts.testgyver.com"

###

DbBrowser = request.newClient(db_browser_url)

class DolanDB
  getAppId: () =>
    5951
    #12165
    # replace this with the real thing

  constructor: (@options={}) ->
    @dolandbCredentialApi = restify.createJsonClient
      url: dolan_db_base_url
    @dolandbCredentialApi.basicAuth Login.currentAccessToken(), 'X'

    @composer = restify.createJsonClient
      url: 'http://config-api.local.testgyver.com:3000'
    @composer.headers["Authorization"] = Login.currentAccessToken()


  test: (params) =>
    ###
      workflow:
        ensure that a uniq appid in cloud.json

        dolandb init (provisions a db using dolan provision api)

        test provision (initializes a provider in config-api)
        test resource beer name:string brewery:string (inits a resource in config-api)
        test raml (gets a raml and writes it to www/local.raml)

        test sync (opens dolandb browser)

        yo devroids:dolan-res beer name brewery alcohol (generates crud app)

        update application.coffee to point to created resources
    ###

    com = params.shift()

    readConfig = () ->
      try return fs.readFileSync(data_definition_path, 'utf8')
      catch e
        console.log "you must first init dolandb with command 'steroids dolandb init'"
        process.exit 1

    if com=='provision'

      config = yaml.safeLoad(readConfig())

      if config.resourceProviderUid?
        console.log 'dolanddb provider exists already'
        process.exit 1

      data =
        providerTypeId: 6,
        name: config['bucket']
        configurationKeys:
          bucket_id: config['bucket_id']
          steroids_api_key: config['apikey']

      @composer.post("/app/#{@getAppId()}/service_providers.json", data, (err, req, res, obj) =>
        config = yaml.safeLoad(fs.readFileSync(data_definition_path, 'utf8'))
        config.resourceProviderUid = obj['uid']

        fs = require('fs')
        fs.writeFile(data_definition_path, yaml.safeDump(config), (err,data) ->
          console.log 'dolandb resource provider created'
        )
      )

    noServiceProvider = (err) ->
      return false unless err?
      JSON.parse(err.message).error == 'service provider not found'

    if com=="resource"
      resource_name = params.shift()

      config = yaml.safeLoad(fs.readFileSync(data_definition_path, 'utf8'))
      provider = config.resourceProviderUid
      bucket = config.bucket

      url = "/app/#{@getAppId()}/service_providers/#{provider}/resources.json"

      data =
        name: resource_name
        path: bucket+'/'+resource_name
        columns: []

      params.forEach (param) ->
        [k, v] = param.split(':')
        data.columns.push { name:k, type:v}

      @composer.post(url, data, (err, req, res, obj) =>
        if noServiceProvider(err)
          console.log "service provider is not defined"
          console.log "run first 'devroids dolandb test provision'"
        else
          console.log "dolandb service provider defined"
        @composer.close()
      )

    if com=="raml"
      @composer.headers["Accept"] = "text/yaml"
      url = "/app/#{@getAppId()}/raml?identification_hash=74d6cf00e52215801b6f9968e916c4558da4a79fd4026268b3e5f2cb12e7e90f"
      @composer.get(url, (err, req, res, obj) =>
        raml_file_content = res['body']

        console.log raml_file_content

        stream = fs.createWriteStream('www/local.raml')
        stream.once('open', (fd) ->
          stream.write raml_file_content
          stream.end()
        )
      )

    if com=='sync'
      raml = fs.readFileSync('www/local.raml', 'utf8')

      console.log raml

      doc = yaml.safeLoad(fs.readFileSync(data_definition_path, 'utf8'))
      if doc.browser_id?
        # browser instance exists
        DbBrowser.put("ramls/#{doc.browser_id}", {raml:{content:raml} }, (err, res, body) =>
          open URL.format("#{db_browser_url}/#browser/#{doc.browser_id}")
        )
      else
        # create a new broser instance
        post_data =
          content: raml
          bucket_id: doc.bucket_id
          application_name: 'myapp'

        DbBrowser.post('ramls', { raml:post_data }, (err, res, body) =>
          doc.browser_id = body.id
          open URL.format("#{db_browser_url}/#browser/#{doc.browser_id}")
          fs.writeFile(data_definition_path, yaml.safeDump(doc), (err,data) =>
          )
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

    if com=='delete'
      id = params.shift()

      @composer.del("/app/#{@getAppId()}/service_providers/#{id}.json", data, (err, req, res, obj) =>
        console.log obj
      )

    if com=='resources'
      provider = 'fc697f9c-f132-46b0-a058-de2bc4936266'
      url = "app/#{@getAppId}/service_providers/#{provider}/resources.json"

      @composer.get(url, (err, req, res, obj) =>
        console.log JSON.stringify(obj)
      )

    if com=="raml"
      @composer.headers["Accept"] = "text/yaml"
      url = "/app/#{@getAppId()}/raml?identification_hash=74d6cf00e52215801b6f9968e916c4558da4a79fd4026268b3e5f2cb12e7e90f"
      @composer.get(url, (err, req, res, obj) =>
        console.log res['body']
      )

    # legacy
    if com=='createxxxxx'
      data = {
        providerTypeId: 6,
        name: "dolandb",
        configurationKeys: {
          bucket_id: 270
          steroids_api_key: 'ca334e0207276b3113e5fa0e6d3009779c8b409d3208a963e856e7f793681579'
        }
      }

      @composer.post('/app/12165/service_providers.json', data, (err, req, res, obj) =>
        console.log obj
      )

    # legacy
    if com=='resource_c'
      provider = '20ddc522-b107-41c7-86a9-d1cc4c7c5efd'
      url = "/app/12165/service_providers/#{provider}/resources.json"

      resource = params.shift()

      column = { name:'name', type:'string'}
      column2 = { name:'brewery', type:'string'}

      data =
        {
          name: resource,
          path: 'db93999/'+resource
          columns: [ column, column2 ]
        }

      console.log data

      #@composer.post(url, data, (err, req, res, obj) =>
      #  console.log err
      #  console.log obj
      #)


  test3: (params) =>
    @createBucketWithCredentials(params[0])
    .then(
      (data) =>
        console.log data
        console.log "u:  "+data.body.login
        console.log "pw: "+data.body.password
        console.log "id: "+data.body.datastore_bucket_id
      , (err) =>
        console.log '.'
        console.log err
        console.log JSON.stringify(err.body)
    )

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

  initialize: (options={}) =>
    console.log 'initializing DolanDB...'

    if fs.existsSync(data_definition_path)
      console.log "file #{data_definition_path} exists!"
      return

    name = "db#{@getApplicationId()}"

    @createBucketWithCredentials(name)
    .then(
      (bucket) =>
        @createDolandbConfig("#{bucket.login}#{bucket.password}", name, bucket.datastore_bucket_id)
    ).then(
      () =>
        console.log "dolandb initialized"
        console.log "create resources with 'steroids dolandb resource', eg:"
        console.log "  steroids dolandb resource beer name:string brewery:string alcohol:integer drinkable:boolean"
        @dolandbCredentialApi.close()
      , (err) ->
        console.log JSON.stringify err
        @dolandbCredentialApi.close()
    )

  resource: (params) =>
    resource_name = params.shift()

    doc = yaml.safeLoad(fs.readFileSync(data_definition_path, 'utf8'))

    properties = {}
    params.forEach (param) ->
      [k, v] = param.split(':')
      properties[k] = v

    res = {}
    res[resource_name]  = properties

    doc.resources.push res

    fs = require('fs')
    fs.writeFile(data_definition_path, yaml.safeDump(doc), (err,data) ->
      console.log 'resource created'
    )

  scaffold: (resources) =>
    doc = yaml.safeLoad(fs.readFileSync(data_definition_path, 'utf8'))
    doc.resources.forEach( (resource) =>
      @run_scaffold_for(resource) if resources.length==0 or Object.keys(resource)[0] in resources
    )

  create_or_update: () =>
    @generate_raml_file()
    .then => @uploadRamlToBrowser()
    .then => @openRamlBrowser()

  open: (options = {}) =>
    console.log 'open'
    unless fs.existsSync(data_definition_path)
      console.log "intialize the database first with 'steroids dolandb init'"
      console.log "... define resources with 'steroids dolandb resource'"
      console.log "... and create the database using 'steroids create"
      return

    doc = yaml.safeLoad(fs.readFileSync(data_definition_path, 'utf8'))
    unless (doc.browser_id)
      console.log "run first 'steroids create"
      return

    @openRamlBrowser()

  ## helpers

  run_scaffold_for: (resource) =>
    args = create_yo_generator_args_for(resource)
    name = Object.keys(resource)[0]

    console.log "running:"
    console.log "  yo devroids:dolan-res #{args}"
    console.log ""

    env.plugins "node_modules", paths.npm
    env.lookup '*:*'
    env.run "devroids:dolan-res #{args}", () ->
      console.log "=============="
      console.log 'you'
      console.log "resource will be located in 'http://localhost/views/#{name}/index.html' "
    #exec("yo devroids:dolan-res #{args}", (error, stdout, stderr) ->
    #)

  validateName = (string) =>
    valid = /^[a-z_]*$/
    return true if string.match valid

    console.log "only lowcase alphabeths and underscore allowed: '#{string}'"
    process.exit 1

  validateType = (string) =>
    allowed = ["string", "integer", "boolean", "number", "date"]
    return true if string in allowed

    console.log "type '#{string}' not within allowed: #{allowed.join(', ')}"
    process.exit 1

  nameTakenError = (err) ->
    response = JSON.parse(err.message)
    return false if response.errors.name==undefined
    'has already been taken' in response.errors.name

  createBucketWithCredentials: (name) =>
    deferred = q.defer()

    data =
      dbName: name
      appId: 12165  ## get this from confs
      #apiKey: Login.currentAccessToken()

    @dolandbCredentialApi.post('/v1/credentials/provision', { data: data }, (err, req, res, obj) =>
      if obj.code==201
        deferred.resolve(obj.body)
      else
        deferred.reject(obj)
    )

    return deferred.promise

  createDolandbConfig: (apikey, database, bucket_id) =>
    deferred = q.defer()

    name = 'name of the app'

    doc =
      name: name
      apikey: apikey
      bucket: database
      bucket_id: bucket_id
      resources: []

    fs = require('fs')
    fs.writeFile(data_definition_path, yaml.safeDump(doc), (err,data) ->
      deferred.resolve()
    )
    return deferred.promise

  getApplicationId: () =>
    cloud_json_path = "config/cloud.json"

    unless fs.existsSync(cloud_json_path)
      console.log "application needs to be deployed before provisioning a dolandb, please run steroids deploy"
      process.exit 1

    d = fs.readFileSync(cloud_json_path, 'utf8')
    obj = JSON.parse(d)
    return obj.id

  create_yo_generator_args_for = (resource) ->
    name = Object.keys(resource)[0]
    properties = resource[name]
    resourceString = name

    for prop in Object.keys properties
      resourceString += " #{prop}"

    return resourceString

  generate_raml_file: () =>
    deferred = q.defer()
    doc = yaml.safeLoad(fs.readFileSync(data_definition_path, 'utf8'))
    doc.base_url = "#{dolan_db_url}/#{doc.bucket}"

    raml_template = fs.readFileSync(__dirname + '/_raml.ejs', 'utf8');
    raml_file_content = ejs.render(raml_template, doc)

    stream = fs.createWriteStream('www/local.raml')
    stream.once('open', (fd) ->
      stream.write raml_file_content
      stream.end()
      deferred.resolve()
    )

    return deferred.promise

  openRamlBrowser: () =>
    doc = yaml.safeLoad(fs.readFileSync(data_definition_path, 'utf8'))
    open URL.format("#{db_browser_url}/#browser/#{doc.browser_id}")

  uploadRamlToBrowser: () =>
    deferred = q.defer()
    raml = fs.readFileSync('www/local.raml', 'utf8')

    doc = yaml.safeLoad(fs.readFileSync(data_definition_path, 'utf8'))
    if doc.browser_id?
      # browser instance exists
      DbBrowser.put("ramls/#{doc.browser_id}", {raml:{content:raml} }, (err, res, body) =>
        deferred.resolve()
      )
    else
      # create a new broser instance
      post_data =
        content: raml
        bucket_id: doc.bucket_id
        application_name: 'myapp'

      DbBrowser.post('ramls', { raml:post_data }, (err, res, body) =>
        doc.browser_id = body.id
        fs.writeFile(data_definition_path, yaml.safeDump(doc), (err,data) =>
          deferred.resolve()
        )
      )
    return deferred.promise

module.exports = DolanDB

