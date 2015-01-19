TestHelper = require "../test_helper"

describe 'packager', ->

  beforeEach =>
    @testHelper = new TestHelper
    @testHelper.prepare()

  describe 'zip', =>

    beforeEach =>
      @oldDefaultTimeoutInterval = jasmine.getEnv().defaultTimeoutInterval
      jasmine.getEnv().defaultTimeoutInterval = 20000

    afterEach =>
      jasmine.getEnv().defaultTimeoutInterval = @oldDefaultTimeoutInterval
            
    it 'should be created', =>
      runs =>
        @testHelper.runInProject
          args: ["package"]

      runs =>
        Paths = require "../../src/steroids/paths"
        fs = require "fs"

        expect(fs.existsSync Paths.temporaryZip).toBe true
