
TestHelper = require "./test_helper"

describe 'usages', ->

  describe 'steroids', ->
    it "gives usage information when no params are given", ->
      session = TestHelper.run
        args: [""]

      runs =>
        expect( session.stdout ).toMatch("Creates a new application from the default template")

  describe 'extended usage', ->
    it "gives all the usages", =>
      @session = TestHelper.run
        args: ["--help"]

      runs =>
        expect( @session.stdout ).toMatch("xtended usage information")
        expect( @session.stdout ).toMatch("--no-qrcode")

    it "has emulate", =>
      expect( @session.stdout ).toMatch("steroids emulate")
      expect( @session.stdout ).toMatch("assuming that it is installed")

    it "has log", =>
      expect( @session.stdout ).toMatch("steroids log")
      expect( @session.stdout ).toMatch("but does not filter")

    it "has generator", =>
      expect( @session.stdout ).toMatch("Generator usage:")
      expect( @session.stdout ).toMatch("the following files will")

  describe 'create', ->
    it "gives usage information when no params are given", ->
      session = TestHelper.run
        args: ["create"]

      runs =>
        expect( session.stdout ).toMatch(/Usage: steroids create <directoryName>/)

  describe 'generate', ->

    beforeEach =>
      @testHelper = new TestHelper
      @testHelper.prepare()

    it "gives usage information when no params are given", =>

      session = @testHelper.runInProject
        args: ["generate"]

      runs =>
        expect( session.stdout ).toMatch(/Usage: steroids generate module <moduleName>/)
