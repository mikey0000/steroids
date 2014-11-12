TestHelper = require "../test_helper"

describe 'create', ->

  doNotRunIfMode("fast")

  describe "new app", ->

    beforeEach =>
      @testHelper = new TestHelper
      @testHelper.bootstrap()
      @testHelper.changeToWorkingDirectory()

    afterEach =>
      @testHelper.cleanUp()

    it 'should be created', =>
      session = @testHelper.run
        args: ["create", "myApp", "--type=mpa", "--language=coffee"]
        timeout: 600000

      runs =>
        fs = require "fs"

        expect( session.code ).toBe(0)
        expect( fs.existsSync "myApp" ).toBe true

    it 'should be not overwrite', =>
      fs = require "fs"

      fs.mkdirSync "importantDirectory"
      expect( fs.existsSync "importantDirectory" ).toBe true

      session = @testHelper.run
        args: ["create", "importantDirectory"]

      runs =>
        expect( session.code ).toBe(1)
        expect( session.stdout ).toMatch "already exists. Remove it to continue."
