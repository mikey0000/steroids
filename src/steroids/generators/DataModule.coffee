steroidsGenerators = require 'generator-steroids'
Base = require "./Base"
chalk = require "chalk"

Provider = require "../data/Provider"

class DataModuleGenerator extends Base

  constructor: (@options) ->
    @resourceName = @options.name || 'myResource'
    @moduleName = "#{@resourceName.toLowerCase()}"

  @usageParams: ->
    "<resourceName>"

  @usage: ->
    """
    Generates a CRUD scaffold for a Supersonic Data resource

    For a resource named #{chalk.bold("cars")}, the following files will be created:

        - app/cars/index.coffee (or .js)
        - app/cars/views/layout.html
        - app/cars/views/index.html
        - app/cars/views/show.html
        - app/cars/views/edit.html
        - app/cars/views/new.html
        - app/cars/views/_form.html
        - app/cars/views/_spinner.html
        - app/cars/scripts/IndexController.coffee (or .js)
        - app/cars/scripts/IndexController.coffee (or .js)
        - app/cars/scripts/NewController.coffee (or .js)
        - app/cars/scripts/ShowController.coffee (or .js)
        - app/cars/scripts/EditController.coffee (or .js)
    """

  generate: ->
    return new Promise (resolve, reject) =>
      path = require "path"
      paths = require "../paths"
      fs = require "fs"

      steroidsCli.debug "DataModuleGenerator", "Generating scaffold for resource: #{@resourceName}"

      intendedModulePath = path.join paths.application.appDir, @moduleName

      inquirer = require "inquirer"

      if fs.existsSync intendedModulePath
        reject new Error "Scaffold already exists for resource #{@resourceName}."
        return

      scriptExtPrompt =
        type: "list"
        name: "scriptExt"
        message: "Do you want your scaffold to be generated with CoffeeScript or JavaScript files?"
        choices: [
          { name: "CoffeeScript", value: "coffee" }
          { name: "JavaScript", value: "js"}
        ]
        default: "coffee"

      promptList = [
        scriptExtPrompt
      ]

      #inquirer.prompt promptList, (answers) =>
      #  @scriptExt = answers.scriptExt

      @scriptExt = 'coffee'
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
          @scriptExt
          @fields
        }, ->
          steroidsCli.debug "DataModuleGenerator", "Generated Scaffold for #{@resourceName}"
          resolve()


module.exports = DataModuleGenerator
