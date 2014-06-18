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
paths = require "./paths"
env = require("yeoman-generator")()

data_definition_path = 'config/dolandb.yaml'

dolan_db_base_url    = 'http://datastorage-api.devgyver.com'
dolan_db_url         = "#{dolan_db_base_url}/v1/datastorage"


class DolanDB
  getAppName: () =>
    "my awesome app"

  getAppId: () =>
    getFromCloudJson('id')

  constructor: (@options={}) ->
    @dolandbProvisionApi = restify.createJsonClient
      url: dolan_db_base_url
    @dolandbProvisionApi.basicAuth Login.currentAccessToken(), 'X'

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

    console.log 'updating config'
    fs.writeFile(data_definition_path, yaml.safeDump(doc), (err,data) ->
      console.log 'done update...'
      deferred.resolve()
    )
    return deferred.promise

  provider: (params) =>

    com = params.shift()

    ## save for debug
    if com=='my'
      @composer.get("/app/#{@getAppId()}/service_providers.json", (err, req, res, obj) =>
        if obj.length==0
          console.log 'no providers defined'
        else
          console.log obj
        @composer.close()
      )

    ## save for debug
    if com=='remove_provider'
      id = params.shift()

      @composer.del("/app/#{@getAppId()}/service_providers/#{id}.json", data, (err, req, res, obj) =>
        console.log 'provider removed'
        @composer.close()
      )

  getFromCloudJson = (param) ->
    cloud_json_path = "config/cloud.json"

    unless fs.existsSync(cloud_json_path)
      console.log "application needs to be deployed before provisioning a dolandb, please run steroids deploy"
      process.exit 1

    cloud_json = fs.readFileSync(cloud_json_path, 'utf8')
    cloud_obj = JSON.parse(cloud_json)
    return cloud_obj[param]

module.exports = DolanDB

