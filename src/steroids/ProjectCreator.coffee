steroidsGenerator = require "generator-steroids"

q = require "q"

class ProjectCreator

  constructor: ->
    @updateLoadingInterval = 2000
    @maxStaleUpdateCount = 20

  generate: (targetDirectory) ->

    deferred = q.defer()

    steroidsGenerator.app({
      skipInstall: true
      projectName: targetDirectory
    }, deferred.resolve)

    return deferred.promise

  update: ->

    deferred = q.defer()

    steroids_cmd = process.argv[1]
    steroidsCli.debug "Running #{steroids_cmd} update"

    sbawn = require './sbawn'
    session = sbawn
      cmd: steroids_cmd
      args: ["update"]
      debug: steroidsCli.debugEnabled

    steroidsCli.log  "\nChecking for Steroids updates and installing project NPM dependencies. Please wait."

    staleCounter = 0
    lastLine = session.stdout.toString().split('\n').slice(-1)[0]

    loading = setInterval () ->
      latestLastLine = session.stdout.toString().split('\n').slice(-1)[0]

      if latestLastLine == lastLine
        staleCounter++

        if staleCounter > @maxStaleUpdateCount
          clearInterval(loading)
          steroidsCli.debug session.stdout
          deferred.reject(new Error "\nSetup up took too long - try running 'steroids update' manually in the project directory.")
      else
        staleCounter = 0

      process.stdout.write('.')
    , @updateLoadingInterval

    session.on 'exit', ->
      clearInterval(loading)
      steroidsCli.debug "Exit with: #{session.code}"

      if session.code != 0 || session.stdout.match(/npm ERR!/)
        steroidsCli.log session.stdout
        deferred.reject(new Error "\nSomething went wrong - try running 'steroids update' manually in the project directory.")

      deferred.resolve()

    return deferred.promise

module.exports = ProjectCreator
