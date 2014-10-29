sbawn = require "../sbawn"

class Genymotion

  constructor: ->
    @genymotionBasePath = "/Applications/Genymotion.app/Contents/MacOS"
    @applicationPackage = "com.appgyver.freshandroid"
    @applicationActivity = "com.appgyver.runtime.scanner.MainActivity"
    @apkPath = "/Users/mpa/Desktop/application.apk"
    @vmName = "steroids"

  run: (opts = {}) =>

    steroidsCli.debug "GENYMOTION", "killing previous instances of genymotion"

    @killall()
    .then(@startPlayer)
    .then(@uninstallApplication)
    .then(@installApk)
    .then(@startApplication)
    .catch (err) ->
      console.log err.message

  startPlayer: (opts = {}) =>
    new Promise (resolve, reject) =>
      steroidsCli.debug "GENYMOTION", "starting player"

      cmd = "#{@genymotionBasePath}/player"
      args = ["--vm-name", @vmName]

      @genymotionPlayerSession = sbawn
        cmd: cmd
        args: args

      @genymotionPlayerSession.on "exit", =>
        reject new Error "player start failed"


      @waitForDevice()
      .then(resolve)
      .catch (err) ->
        reject err

  waitForDevice: (opts = {}) ->
    new Promise (resolve, reject) =>
      steroidsCli.debug "GENYMOTION", "waiting for device to appear"

      cmd = "#{@genymotionBasePath}/tools/adb"
      args = ["devices", "-l"]

      @deviceListSession = sbawn
        cmd: cmd
        args: args
        stdout: if opts.stdout? then opts.stdout  else false
        stderr: if opts.stderr? then opts.stderr else false

      @deviceListSession.on "exit", =>
        unless @deviceListSession.stdout.match "model:steroids"
          steroidsCli.debug "GENYMOTION", "device not found, retrying"

          setTimeout =>
            @waitForDevice()
            .then(resolve)
            .catch (err) ->
              reject err #perkele
          , 1000
        else
          steroidsCli.debug "GENYMOTION", "device found"
          resolve()

  uninstallApplication: (opts = {}) =>
    new Promise (resolve, reject) =>
      steroidsCli.debug "GENYMOTION", "uninstalling application"

      cmd = "#{@genymotionBasePath}/tools/adb"
      args = ["uninstall", @applicationPackage]

      @uninstallSession = sbawn
        cmd: cmd
        args: args
        stdout: if opts.stdout? then opts.stdout  else false
        stderr: if opts.stderr? then opts.stderr else false

      @uninstallSession.on "exit", =>

        if @uninstallSession.stdout.match "Success"
          steroidsCli.debug "GENYMOTION", "uninstall success, continue"
          resolve()
        else if @uninstallSession.stdout.match "Failure"
          steroidsCli.debug "GENYMOTION", "uninstall failure, continue"
          resolve()
        else
          steroidsCli.debug "GENYMOTION", "uninstall not possible yet, retrying"
          setTimeout =>
            @uninstallApplication()
            .then(resolve)
            .catch (err) ->
              reject err #perkele
          , 1000



  installApk: (opts = {}) =>
    new Promise (resolve, reject) =>
      steroidsCli.debug "GENYMOTION", "installing APK"
      cmd = "#{@genymotionBasePath}/tools/adb"
      args = ["install", @apkPath]

      @installSession = sbawn
        cmd: cmd
        args: args
        stdout: if opts.stdout? then opts.stdout  else false
        stderr: if opts.stderr? then opts.stderr else false

      @installSession.on "exit", =>

        if @installSession.stdout.match "Is the system running?"
          steroidsCli.debug "GENYMOTION", "system not running yet, retrying"

          setTimeout =>
            @installApk()
            .then(resolve)
            .catch (err) ->
              reject err #perkele
          , 1000

        else if @installSession.stdout.match "protocol failure"
          steroidsCli.debug "GENYMOTION", "protocol failure"
          setTimeout =>
            @installApk()
            .then(resolve)
            .catch (err) ->
              reject err #perkele
          , 1000

        else
          resolve()

  startApplication: (opts = {}) =>
    new Promise (resolve, reject) =>
      steroidsCli.debug "GENYMOTION", "starting application"

      cmd = "#{@genymotionBasePath}/tools/adb"
      args = ["shell", "am", "start", "-n", "#{@applicationPackage}/#{@applicationActivity}"]

      @startSession = sbawn
        cmd: cmd
        args: args
        stdout: if opts.stdout? then opts.stdout  else false
        stderr: if opts.stderr? then opts.stderr else false

      @startSession.on "exit", =>
        if @startSession.stdout.match "Starting: Intent"
          steroidsCli.debug "GENYMOTION", "started application"
          resolve()
        else
          console.log @startSession.stdout
          console.log "retrying..."

          setTimeout =>
            @startApplication()
            .then(resolve)
            .catch (err) ->
              reject err #perkele
          , 1000


  killall: =>
    new Promise (resolve) ->
      killGenymotion = sbawn
        cmd: "/usr/bin/pkill"
        args: ["-9", "player"]

      killGenymotion.on "exit", ->
        console.log "Genymotion killed"
        resolve()

module.exports = Genymotion
