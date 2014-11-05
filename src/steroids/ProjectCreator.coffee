class ProjectCreator

  constructor: ->

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
          skipInstall: false
          projectName: targetDirectory
          appType: answers.appType
        }, resolve

module.exports = ProjectCreator
