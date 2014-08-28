fs = require "fs"
Help = require "./Help"

module.exports = class DataHelpers

  @getAppId: () ->
    @getFromCloudJson "id"

  @getIdentificationHash = ->
    @getFromCloudJson "identification_hash"

  @getFromCloudJson: (param) ->
    cloud_json_path = "config/cloud.json"

    unless fs.existsSync(cloud_json_path)
      Help.deployRequiredForData()
      process.exit 1

    cloud_json = fs.readFileSync(cloud_json_path, 'utf8')
    cloud_obj = JSON.parse(cloud_json)
    return cloud_obj[param]
