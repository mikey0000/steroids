steroidsGenerators = require 'generator-steroids'
Base = require "./Base"

module.exports = class DataModuleGenerator extends Base

  constructor: ({ resourceName, fields }) ->
    @resourceName = resourceName || 'myResource'
    @fields = fields || []
    @moduleName = "#{@resourceName}s"

  @usageParams: ->
    "<resourceName> <fields...>"

  @usage: ->
    """
    Generates a CRUD scaffold for your SandboxDB resource.
    """

  generate: ->
    steroidsGenerators.dataModule {
      @moduleName
      @resourceName
      @fields
    }
