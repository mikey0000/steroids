TestHelper = require "../test_helper"

skipWhen process.env.STEROIDS_TEST_RUN_MODE, "fast"
onlyWhen process.platform, "darwin"

describe 'simulator', ->

  beforeEach =>
    @oldDefaultTimeoutInterval = jasmine.getEnv().defaultTimeoutInterval
    jasmine.getEnv().defaultTimeoutInterval = 20000

  afterEach =>
    jasmine.getEnv().defaultTimeoutInterval = @oldDefaultTimeoutInterval

  describe 'start', =>

    afterEach =>
      if @testRunDone
        TestHelper.run
          cmd: "pkill"
          args: ["ios-sim"]

        @session.kill()

    rightHereRightNow =>
      @testHelper = new TestHelper
      @testHelper.prepare()
      @testRunDone = false

    it 'starts the run', =>
      # this can not be in rightHereRightNow, because there is no jasmine
      @session = @testHelper.runInProject
        args: ["emulate", "ios", "--debug"]
        waitsFor: 100

      running = false
      waitsFor =>
        running = @session.stdout.match "ios-sim/bin/ios-sim"

      runs ->
        expect( running ).toBeTruthy()

    it 'starts with iPhone-6 as the default device', =>
      correctDevice = false
      waitsFor =>
        correctDevice = @session.stdout.match "--devicetypeid,com.apple.CoreSimulator.SimDeviceType.iPhone-6"

      runs ->
        expect( correctDevice ).toBeTruthy()

    it 'starts the session', =>
      started = false
      waitsFor =>
        started = @session.stdout.match "\nSession started"

      runs ->
        expect( started ).toBeTruthy()

      @testRunDone = true


  describe 'options', =>

    beforeEach =>
      @testHelper = new TestHelper
      @testHelper.prepare()

    afterEach =>
      if @testRunDone
        TestHelper.run
          cmd: "pkill"
          args: ["ios-sim"]

        TestHelper.run
          cmd: "pkill"
          args: ["iOS Simulator"]

    it 'launches an iPad-2', =>
      session = @testHelper.runInProject
        args: ["emulate", "ios", "--device=iPad-2", "--debug"]
        waitsFor: 100

      startsIpad2 = false
      waitsFor =>
        startsIpad2 = session.stdout.match "--devicetypeid,com.apple.CoreSimulator.SimDeviceType.iPad-2"

      runs ->
        expect( startsIpad2 ).toBeTruthy()
        session.kill()
        @testRunDone = true
