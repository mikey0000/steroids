sbawn = require '../sbawn'
paths = require "../paths"

class Android
  StoppedError: class StoppedError extends steroidsCli.SteroidsError

  constructor: ->
    return null unless paths.androidSDK?
    @androidCmd = path.join paths.androidSDK.tools, "android"
    @emulatorCmd = path.join paths.androidSDK.tools, "emulator"
    @adbCmd = path.join paths.androidSDK.platformTools, "adb"

    @applicationPackage = "com.appgyver.runtime.scanner"
    @applicationActivity = "com.appgyver.runtime.scanner.MainActivity"

    @apkPath = paths.emulate.android.debug

    @emulatorSession = null

  run: =>
    new Promise (resolve, reject) =>

      unless paths.androidSDK?
        reject new Error """
          Cannot start Android Emulator.

              Environment variable ANDROID_SDK_HOME not set.

          Please see documentation on how to setup Android Emulator.
          """
        return
      @killall()
      .then(@restartAdbServer)
      .then(@findDevice)
      .then(@resetTimeout)
      .then(@startEmulator)
      .then(@ensureDeviceStarted)
      .then(@uninstallAPK)
      .then(@installAPK)
      .then(@startApplication)
      .then(@unlockDevice)
      resolve()

  restartAdbServer: =>
    new Promise (resolve, reject) =>

      steroidsCli.debug "ANDROID", "restarting adb server"

      killSession = sbawn
        cmd: @adbCmd
        args: ["kill-server"]

      killSession.on "exit", =>
        steroidsCli.debug "ANDROID", "adb server killed"
        startSession = sbawn
          cmd: @adbCmd
          args: ["start-server"]

        startSession.on "exit", =>
          steroidsCli.debug "ANDROID", "adb server started"
          resolve()

  findDevice: =>
    new Promise (resolve, reject) =>

      session = sbawn
        cmd: @androidCmd
        args: ["list"]

      session.on "exit", =>
        if session.stdout.match "Name: steroids"
          steroidsCli.debug "ANDROID", "found device named steroids"
          resolve()
        else
          reject new Error "Could not find an Android virtual device named steroids"

  startEmulator: =>
    new Promise (resolve, reject) =>
      steroidsCli.log "Starting Android Emulator"

      @emulatorSession = sbawn
        cmd: @emulatorCmd
        args: ["@steroids"]

      waitForEmulatorInterval = setInterval =>
        if @emulatorSession.stderr.match "HAX is working and emulator runs in fast virt mode"
          steroidsCli.log "Emulator started"
          clearInterval(waitForEmulatorInterval)

          resolve()
        else
          steroidsCli.debug "ANDROID", "waiting for emulator to start"
      , 500

  ensureDeviceStarted: =>
    new Promise (resolve, reject) =>

      session = sbawn
        cmd: @adbCmd
        args: ["devices", "-l"]

      # for some reason restarting the server helps
      unless @ensureDeviceStartedAdbRestartInterval
        @ensureDeviceStartedAdbRestartInterval = setInterval =>
          @restartAdbServer()
        , 5000

      session.on "exit", =>
        if session.stdout.match "device product:"
          clearInterval @ensureDeviceStartedAdbRestartInterval

          steroidsCli.log "Device is running"
          resolve()
        else
          steroidsCli.debug "ANDROID", "waiting for device to appear"

          setTimeout =>
            @ensureDeviceStarted()
            .then(resolve)
          , 1000

  uninstallAPK: =>
    new Promise (resolve, reject) =>

      steroidsCli.debug "ANDROID", "starting uninstall"

      uninstallSession = sbawn
        cmd: @adbCmd
        args: ["uninstall", @applicationPackage]

      uninstallSession.on "exit", =>
        steroidsCli.debug "ANDROID", "uninstall exited with"

        if uninstallSession.stdout.match("Success")
          steroidsCli.debug "ANDROID", "uninstall success"
          resolve()
        else if uninstallSession.stdout.match("Failure")
          steroidsCli.debug "ANDROID", "uninstall failure"
          resolve()
        else if uninstallSession.stdout.match("Failure [DELETE_FAILED_INTERNAL_ERROR]")
          steroidsCli.debug "ANDROID", "uninstall DELETE_FAILED_INTERNAL_ERROR"
          resolve()
        else
          steroidsCli.debug "ANDROID", "uninstall not success, retry"
          setTimeout =>
            @uninstallAPK()
            .then(resolve)
          , 1000


  installAPK: =>
    new Promise (resolve, reject) =>

      steroidsCli.log "Starting installation"

      installSession = sbawn
        cmd: @adbCmd
        args: ["install", @apkPath]

      installSession.on "exit", =>
        steroidsCli.debug "ANDROID", "installsession exited with"

        #installTimeout = setTimeout
        if installSession.stdout.match "Success"
          steroidsCli.log "Installed application"
          resolve()
        else
          steroidsCli.debug "ANDROID", "install failed with", installSession.stdout
          @restartAdbServer()
          .then(@uninstallAPK)
          .then(@installAPK)
          .then(resolve)

  startApplication: =>
    new Promise (resolve, reject) =>

      ips = steroidsCli.server.ipAddresses()
      port = steroidsCli.server.port
      encodedJSONIPs = encodeURIComponent(JSON.stringify(ips))
      encodedPort = encodeURIComponent(port)

      launchUrl = "'appgyver://?ips=#{encodedJSONIPs}\&port=#{encodedPort}'"
      args = ["shell", "am", "start", "-n", "#{@applicationPackage}/#{@applicationActivity}", "-d", launchUrl]

      session = sbawn
        cmd: @adbCmd
        args: args

      session.on "exit", =>
        if session.stdout.match "Starting: Intent"
          steroidsCli.log "Application started"
          resolve()
        else
          steroidsCli.debug "ANDROID", "application not started: ", session.stdout
          steroidsCli.debug "ANDROID", "retrying start"
          setTimeout =>
            @startApplication()
            .then(resolve)
            .catch(err) ->
              reject err # perkele

  unlockDevice: (opts = {}) =>
    new Promise (resolve, reject) =>

      steroidsCli.debug "ANDROID", "unlocking device"

      session = sbawn
        cmd: @adbCmd
        args: ["shell", "input", "keyevent", "82"]

      session.on "exit", =>
        steroidsCli.log "Device unlocked"
        steroidsCli.debug "ANDROID", "unlock exit code: #{session.code}"
        resolve()

  killall: =>
    new Promise (resolve) ->

      if steroidsCli.host.os.isOSX()
        session = sbawn
          cmd: "/usr/bin/pkill"
          args: ["-9", "emulator64-x86"]

        session.on "exit", ->
          setTimeout resolve, 500
      else
       resolve()

module.exports = Android
