fs = require "fs"
Help = require "./Help"
Q = require "q"

module.exports = class DataHelpers

  # config/cloud.json stuff
  @getAppId: () ->
    @getFromCloudJson "id"

  @getIdentificationHash = ->
    @getFromCloudJson "identification_hash"

  @getFromCloudJson: (param) ->
    cloudJsonPath = "config/cloud.json"

    unless fs.existsSync(cloudJsonPath)
      Help.deployRequiredForData()
      process.exit 1

    cloudJson = fs.readFileSync cloudJsonPath, 'utf8'
    cloudObj = JSON.parse(cloudJson)
    return cloudObj[param]

  # RAML stuff
  @getLocalRaml = (localRamlPath) ->
    fs.readFileSync localRamlPath, 'utf8'

  @saveToLocalRaml = (ramlFileContent, localRamlPath) ->
    deferred = Q.defer()

    fs.writeFile localRamlPath, ramlFileContent, (err, data) ->
      if err?
        deferred.reject err
      else
        deferred.resolve data

    deferred.promise