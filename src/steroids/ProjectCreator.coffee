steroidsGenerator = require "generator-steroids"

class ProjectCreator

  constructor: ->
    @updateLoadingInterval = 2000
    @maxStaleUpdateCount = 20

  generate: (targetDirectory) ->

    new Promise (resolve, reject) ->
      steroidsGenerator.app({
        skipInstall: true
        projectName: targetDirectory
      }, resolve)

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
          reject new Error "\nSomething went wrong - try running 'steroids update' manually in the project directory."

        resolve()

module.exports = ProjectCreator
