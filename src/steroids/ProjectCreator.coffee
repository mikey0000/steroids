class ProjectCreator

  constructor: ->
    @updateLoadingInterval = 2000
    @maxStaleUpdateCount = 20

  generate: (targetDirectory) ->

    new Promise (resolve) =>
      steroidsGenerator = require "generator-steroids"
      inquirer = require "inquirer"

      appTypePrompt =
        type: "list"
        name: "appType"
        message: "Do you want to create a Multi-Page or Single-Page Application?"
        choices: [
          { name: "Multi-Page Application (Supersonic default)", value: "mpa" }
          { name: "Single-Page Application (for use with other frameworks)", value: "spa"}
        ]
        default: "mpa"

      inquirer.prompt appTypePrompt, (answers) =>

        steroidsGenerator.app {
          skipInstall: true
          projectName: targetDirectory
          appType: answers.appType
        }, resolve

  update: =>

    new Promise (resolve, reject) =>
      paths = require './paths'
      steroids_cmd = paths.steroids
      steroidsCli.debug "Running #{steroids_cmd} update"

      sbawn = require './sbawn'
      session = sbawn
        cmd: steroids_cmd
        args: ["update"]
        debug: steroidsCli.debugEnabled
        stdout: true
        stderr: true

      steroidsCli.log  "\nChecking for Steroids updates and installing project NPM dependencies. Please wait."

      session.on 'exit', ->
        steroidsCli.debug "#{session.cmd} exited with code #{session.code}"

        if session.code != 0 || session.stdout.match(/npm ERR!/)
          reject new Error "\nSomething went wrong - try running #{chalk.bold('steroids update')} manually in the project directory."

        resolve()

module.exports = ProjectCreator
