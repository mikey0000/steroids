steroidsGenerators = require 'generator-steroids'

Base = require "./Base"
chalk = require "chalk"

class ModuleGenerator extends Base

  constructor: (@options) ->
    @moduleName = @options.name || 'example'

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
    return new Promise (resolve, reject) =>
      steroidsCli.debug "ModuleGenerator", "Generating generator Module"

      steroidsGenerators.module {
        @moduleName
      }, ->
        steroidsCli.debug "ModuleGenerator", "Generated generator Module"
        resolve()


module.exports = ModuleGenerator
