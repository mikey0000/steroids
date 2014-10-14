class Logout

    run: =>
      return new Promise (resolve, reject) =>
        Login = require "./Login"

        Login.removeAuthToken()
        resolve()

module.exports = Logout
