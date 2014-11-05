steroidsGenerators = require 'generator-steroids'
Base = require "./Base"

Provider = require "../data/Provider"

module.exports = class DataModuleGenerator extends Base

  constructor: (@options) ->
    @resourceName = @options.name || 'myResource'
    @moduleName = "#{@resourceName}s"

  @usageParams: ->
    "<resourceName> <fields...>"

  @usage: ->
    """
    Generates a CRUD scaffold for your SandboxDB resource.
    """

  generate: ->
    steroidsCli.debug "DATAMODULEGENERATOR", "Generating scaffold for resource: #{@resourceName}"

    #TODO: should be Resource.forName but Resource cannot require Provider if Provider requires Resource
    Provider.resourceForName(@resourceName).then (resource)=>
      @fields = resource.getFieldNamesSync()
      steroidsCli.debug "DATAMODULEGENERATOR", "Generating scaffold with name: #{@resourceName} modulename: #{@modulename} and fields: #{JSON.stringify(@fields)}"

      steroidsGenerators.dataModule {
        @moduleName
        @resourceName
        @fields
      }
