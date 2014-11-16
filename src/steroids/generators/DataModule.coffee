steroidsGenerators = require 'generator-steroids'
Base = require "./Base"

Provider = require "../data/Provider"

class DataModuleGenerator extends Base

  constructor: (@options) ->
    @resourceName = @options.name || 'myResource'
    @moduleName = "#{@resourceName.toLowerCase()}"

  @usageParams: ->
    "<resourceName> <fields...>"

  @usage: ->
    """
    Generates a CRUD scaffold for a Supersonic Data resource.
    """

  generate: ->
    return new Promise (resolve, reject) =>
      path = require "path"
      paths = require "../paths"
      fs = require "fs"

      steroidsCli.debug "DataModuleGenerator", "Generating scaffold for resource: #{@resourceName}"

      intendedModulePath = path.join paths.application.appDir, @moduleName

      if fs.existsSync intendedModulePath
        reject new Error "Scaffold already exists for resource #{@resourceName}."
        return

      #TODO: should be Resource.forName but Resource cannot require Provider if Provider requires Resource
      Provider.resourceForName(@resourceName).then (resource)=>

        @fields = resource.getFieldNamesSync()

        if @fields.length == 0
          reject new Error "No fields defined for resource #{@resourceName}."
          return

        steroidsCli.debug "DataModuleGenerator", "Generating scaffold with name: #{@resourceName} modulename: #{@modulename} and fields: #{JSON.stringify(@fields)}"

        steroidsGenerators.dataModule {
          @moduleName
          @resourceName
          @fields
        }, ->
          steroidsCli.debug "DataModuleGenerator", "Generated Scaffold for #{@resourceName}"
          resolve()


module.exports = DataModuleGenerator
