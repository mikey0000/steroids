steroidsGenerators = require 'generator-steroids'

Base = require "./Base"
chalk = require "chalk"

module.exports = class ModuleGenerator extends Base

  constructor: (@options) ->
    @moduleName = @options.otherOptions?[0] || 'example'

  @usageParams: ->
    "<moduleName>"

  @usage: ->
    """
    Generates a Steroids module scaffold.

    For a module named #{chalk.bold("cars")}, the following files will be created:

        - app/cars/index.coffee
        - app/cars/views/index.html
        - app/cars/scripts/IndexController.coffee

    """

  generate: ->
    steroidsGenerators.module {
      @moduleName
    }
