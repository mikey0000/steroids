steroidsGenerators = require 'generator-steroids'
Base = require "./Base"

Provider = require "../data/Provider"

class DataModuleGenerator extends Base

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
    return new Promise (resolve, reject) =>
      steroidsCli.debug "DataModuleGenerator", "Generating scaffold for resource: #{@resourceName}"

      #TODO: should be Resource.forName but Resource cannot require Provider if Provider requires Resource
      Provider.resourceForName(@resourceName).then (resource)=>
        @fields = resource.getFieldNamesSync()
        steroidsCli.debug "DataModuleGenerator", "Generating scaffold with name: #{@resourceName} modulename: #{@modulename} and fields: #{JSON.stringify(@fields)}"

        steroidsGenerators.dataModule {
          @moduleName
          @resourceName
          @fields
        }, ->
          steroidsCli.debug "ModuleGenerator", "Generated generator Module"
          resolve()


module.exports = DataModuleGenerator
