sbawn = require "../sbawn"

class Genymotion

  constructor: ->
    paths = require "../paths"
    @genymotionShellPath = "/Applications/Genymotion Shell.app/Contents/MacOS/genyshell"
    @genymotionBasePath = "/Applications/Genymotion.app/Contents/MacOS"

    #@applicationPackage = "com.appgyver.freshandroid"
    @applicationPackage = "com.appgyver.runtime.scanner"
    @applicationActivity = "com.appgyver.runtime.scanner.MainActivity"
    @apkPath = paths.emulate.android.debug

    @vmName = "steroids"

  run: (opts = {}) =>

    steroidsCli.debug "GENYMOTION", "killing previous instances of genymotion"


    @startFailed = false

    @killall()
    .then(@ensurePlayer)
    .then(@startPlayer)
    .then(@uninstallApplication)
    .then(@installApk)
    .then(@startApplication)
    .then(@unlockDevice)
    .catch (err) ->
      console.log err.message


  startPlayer: (opts = {}) =>
    new Promise (resolve, reject) =>

      fs = require "fs"
      unless fs.existsSync @genymotionBasePath
        reject new Error "/Applications/Genymotion.app does not exist"
        return

      steroidsCli.debug "GENYMOTION", "starting player"

      cmd = "#{@genymotionBasePath}/player"
      args = ["--vm-name", @vmName]

      @genymotionPlayerSession = sbawn
        cmd: cmd
        args: args

      @genymotionPlayerSession.on "exit", =>
        @startFailed = true
        reject new Error "Could not start a virtual device named steroids"


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
          if @startFailed
            reject new Error "start failed"
            return

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
      steroidsCli.debug "GENYMOTION", "installing APK #{@apkPath}"
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

        else if @installSession.stdout.match "Success"
          steroidsCli.debug "GENYMOTION", "installed"
          resolve()
        else
          steroidsCli.debug "GENYMOTION", "Unknown error:"
          steroidsCli.debug "GENYMOTION", @installSession.stdout

          reject new Error "Install failed"

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

  unlockDevice: (opts = {}) =>
    new Promise (resolve, reject) =>
      steroidsCli.debug "GENYMOTION", "unlocking device"

      cmd = "#{@genymotionBasePath}/tools/adb"
      args = ["shell", "input", "keyevent", "82"]

      @unlockSession = sbawn
        cmd: cmd
        args: args
        stdout: if opts.stdout? then opts.stdout  else false
        stderr: if opts.stderr? then opts.stderr else false

      @unlockSession.on "exit", =>
        steroidsCli.debug "GENYMOTION", "unlock exit code: #{@unlockSession.code}"
        resolve()

  killall: =>
    new Promise (resolve) ->
      killGenymotion = sbawn
        cmd: "/usr/bin/pkill"
        args: ["-9", "player"]

      killGenymotion.on "exit", ->
        resolve()

module.exports = Genymotion
