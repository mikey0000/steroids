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
Help = require "./Help"
chalk = require "chalk"

data_definition_path = 'config/sandboxdb.yaml'

sandbox_db_base_url    = 'http://datastorage-api.devgyver.com'
sandbox_db_url         = "#{sandbox_db_base_url}/v1/datastorage"

class SandboxDB

  getAppId: () =>
    getFromCloudJson('id')

  constructor: (@options={}) ->
    @sandboxDBProvisionApi = restify.createJsonClient
      url: sandbox_db_base_url
    @sandboxDBProvisionApi.basicAuth Login.currentAccessToken(), 'X'

  createBucketWithCredentials: () =>
    deferred = q.defer()
    data =
      appId: @getAppId()

    @sandboxDBProvisionApi.post('/v1/credentials/provision', { data: data }, (err, req, res, obj) =>
      if obj.code==201
        deferred.resolve(obj.body)
      else
        deferred.reject(obj)
    )

    return deferred.promise

  createSandboxDBConfig: (apikey, database, bucket_id) =>
    deferred = q.defer()

    doc =
      apikey: apikey
      bucket: database
      bucket_id: bucket_id

    steroidsCli.debug "Updating SandboxDB config..."
    fs.writeFile(data_definition_path, yaml.safeDump(doc), (err,data) ->
      steroidsCli.debug "Done updating SandboxDB config."
      deferred.resolve()
    )
    return deferred.promise

  getFromCloudJson = (param) ->
    cloud_json_path = "config/cloud.json"

    unless fs.existsSync(cloud_json_path)
      Help.deployRequiredForSandboxDBProvisioning()
      process.exit 1

    cloud_json = fs.readFileSync(cloud_json_path, 'utf8')
    cloud_obj = JSON.parse(cloud_json)
    return cloud_obj[param]

module.exports = SandboxDB

