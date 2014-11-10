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

        - app/cars/index.coffee (or .js)
        - app/cars/views/index.html
        - app/cars/scripts/IndexController.coffee (or .js)

    """

  generate: ->
    return new Promise (resolve, reject) =>
      steroidsCli.debug "ModuleGenerator", "Generating generator Module"

      steroidsGenerator = require "generator-steroids"
      inquirer = require "inquirer"

      scriptExtPrompt =
        type: "list"
        name: "scriptExt"
        message: "Do you want your module to be generated with CoffeeScript or JavaScript files?"
        choices: [
          { name: "CoffeeScript", value: "coffee" }
          { name: "JavaScript", value: "js"}
        ]
        default: "coffee"

      promptList = [
        scriptExtPrompt
      ]

      inquirer.prompt promptList, (answers) =>

        steroidsGenerator.module {
          scriptExt: answers.scriptExt
          moduleName: @moduleName
        }, ->
          steroidsCli.debug "ModuleGenerator", "Generated Module #{@moduleName}"
          resolve()


module.exports = ModuleGenerator
