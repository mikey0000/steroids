TestHelper = require "./test_helper"

describe 'deploy', ->

  doNotRunIfMode("fast")

  afterEach ->
    if @testRunDone
      console.log "DONNNEEE"
      @session.kill()

  rightHereRightNow =>
    @testHelper = new TestHelper
    @testHelper.prepare()

    @testRunDone = false

  it "starts the deployment and makes", =>
    @session = @testHelper.runInProject
      args: ["deploy", "--debug"]

    started = false
    waitsFor =>
      started = @session.stdout.match("Making with hooks")

    runs ->
      expect( started ).toBeTruthy()

  it "creates dist/__appgyver_settings.json", =>
    settingsCreated = false
    waitsFor =>
      settingsCreated = @session.stdout.match("Creating dist/__appgyver_settings.json")

    runs ->
      expect( settingsCreated ).toBeTruthy()

  it "creates dist/config.ios.xml", =>
    iosConfigCreated = false
    waitsFor =>
      iosConfigCreated = @session.stdout.match("Creating dist/config.ios.xml...")

    runs ->
      expect( iosConfigCreated ).toBeTruthy()

  it "packages", =>
    packaged = false
    waitsFor =>
      packaged = @session.stdout.match("package exited with code 0")

    runs ->
      expect( packaged ).toBeTruthy()

  it "starts uploading to cloud", =>
    startsUploading = false
    waitsFor =>
      startsUploading = @session.stdout.match("Uploading Application to cloud")

    runs ->
      expect( startsUploading ).toBeTruthy()

  it "receives APPJSON", =>
    appJsonReceived = false
    waitsFor =>
      appJsonReceived = @session.stdout.match("RECEIVED APPJSON SYNC RESPONSE")

    runs ->
      expect( appJsonReceived ).toBeTruthy()

  it "opens URL to share.appgyver.com", =>
    urlOpened = false
    waitsFor =>
      urlOpened = @session.stdout.match("Opening URL https://share.appgyver.com/")

    runs ->
      expect( urlOpened ).toBeTruthy()

  it "completes deployment", =>
    deploymentCompleted = false
    waitsFor =>
      deploymentCompleted = @session.stdout.match("Deployment complete")

    runs ->
      expect( deploymentCompleted ).toBeTruthy()

  it "says that we are still working on the full team support", =>
    teamSupportAnnounced = false
    waitsFor =>
      teamSupportAnnounced = @session.stdout.match("We are working on full team support")

    runs ->
      expect( teamSupportAnnounced ).toBeTruthy()

  it "kills the testrun", =>
    @testRunDone = true
