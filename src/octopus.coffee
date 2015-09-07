# Description:
#   Hubot interface to octopus deploy
#
# Commands:
#   hubot octo promote <project> from <env1> to <env2> - Hubot deploys the latest release of <project> on <env1> to <env2>
#   hubot octo deploy <project> version <version> to <env> - Hubot deploys the specified version of <project> to <env>
#   hubot octo status - Hubot prints a dashboard of environments and currently deployed versions.
#
# Author:
#   kneumei


_ = require('underscore')._
q = require('q')
util = require('util')

apikey = process.env.OCTOPUS_KEY
urlBase = process.env.OCTOPUS_URL_BASE

createHTTPCall = (robot, urlPath) ->
  robot.http("#{urlBase}/#{urlPath}")
  .header("X-Octopus-ApiKey", apikey)
  .header("content-type", "application/json")

deployRelease = (robot, release, environment) ->
  deferred = q.defer()
  deployment =
    Comments: "Deployed from Hubot"
    EnvironmentId: environment.Id
    ReleaseId: release.Id
    ForcePackageRedeployment: true

  createHTTPCall(robot, "/api/deployments")
  .post(JSON.stringify(deployment)) (err, res, body) ->
    if(err)
      deferred.reject err
    else
      deferred.resolve (JSON.parse body)
  deferred.promise

getItems = (robot, urlPath) ->
  deferred = q.defer()
  createHTTPCall(robot,urlPath)
  .get() (err, res, body) ->
    if err
      deferred.reject(err)
    else
      items = (JSON.parse body)
      deferred.resolve(items)
  deferred.promise

getItem = (robot, urlPath, selectFunc) ->
  deferred = q.defer()
  createHTTPCall(robot, urlPath)
  .get() (err, res, body) ->
    if err
      deferred.reject(err)
    else
      items = (JSON.parse body).Items
      deferred.resolve(selectFunc(items))
  deferred.promise

findByName = (name)->
  (items) ->_.find(items, (item) -> item.Name == name)

findByFirst = () ->
  (items) -> _.first(items)

findByVersion = (version) ->
  (items) -> _.find(items, (item)-> item.Version == version)

mostRecentRelease = (robot, project) ->
  releasesUrl = project.Links["Releases"].replace /{.*}/, ""
  getItem(robot, releasesUrl, findByFirst())
  .then (val) -> val

findRelease = (robot, project, version) ->
  releasesUrl = project.Links["Releases"].replace /{.*}/,""
  getItem(robot, releasesUrl, findByVersion(version))
  .then (val) -> val

module.exports = (robot) ->
  robot.respond /(octo promote) (.+) (from) (.+) (to) (.+)/i, (msg) ->
    projectName = msg.match[2]
    sourceEnvName = msg.match[4]
    targetEnvName = msg.match[6]
    getItem(robot, "api/projects", findByName(projectName))
    .then (project) ->
      if (!project)
        throw new Error("Could not find project #{projectName}");
      this.project = project
      getItem(robot, "api/environments", findByName(sourceEnvName))
    .then (sourceEnv) ->
      if (!sourceEnv)
        throw new Error("Could not find environment #{sourceEnvName}");
      this.sourceEnv = sourceEnv
      getItem(robot, "api/environments", findByName(targetEnvName))
    .then (targetEnv) ->
      if (!targetEnv)
        throw new Error("Could not find environment #{targetEnvName}");
      this.targetEnv = targetEnv
      mostRecentRelease(robot, this.project)
    .then (prevRelease) ->
      if (!prevRelease)
        throw new Error("Could not find previous release");
      this.prevRelease = prevRelease
      deployRelease(robot, prevRelease, targetEnv)
    .then (deployment) ->
      msg.send "Promoted #{this.prevRelease.Version} from #{sourceEnvName} to #{targetEnvName}"
    .catch (error) ->
      msg.send error
  robot.respond /(octopus|octo) status$/i, (msg) ->
    getItems(robot, "api/dashboard")
    .then (data) ->
      m = "Here, I give you amazing OcotopusDeploy stats!:"
      for proj in data.Projects
        if proj
          m = m + "\n Project: " + proj.Name
          projItems = _.filter(data.Items, (i) -> if i.ProjectId == proj.Id then i)

          if projItems && projItems.length > 0
            for item in projItems
              if item
                enviro = _.find(data.Environments, (env) -> env.Id == item.EnvironmentId)
                tabset = enviro.Name.length > "\t" ? " : \t" : " : \t\t"
                formata = "\n  > %s\t\t : %s - %s"
                formatb = "\n  > %s\t : %s - %s"
                format = if enviro.Name.length >= 5 then formatb else formata
                m = m + util.format(format, enviro.Name, item.ReleaseVersion, item.State)
          else
            m = m + "\n  > No Deployments"
      msg.send m
    .catch (error) ->
      msg.send error
  robot.respond /(octopus|octo) deploy (.+) version (.+) (to) (.+)/i, (msg) ->
    projectName = msg.match[2]
    version = msg.match[3]
    targetEnvName = msg.match[5]
    getItem(robot, "api/projects", findByName(projectName))
    .then (project) ->
      if (!project)
        throw new Error("Could not find project #{projectName}");
      this.project = project
      getItem(robot, "api/environments", findByName(targetEnvName))
    .then (targetEnv) ->
      if (!targetEnv)
        throw new Error("Could not find environment #{targetEnvName}");
      this.targetEnv = targetEnv
      findRelease(robot, this.project, version)
    .then (release) ->
      if (!release)
        throw new Error("Could not find previous release");
      this.release = release
      deployRelease(robot, release, targetEnv)
    .then (deployment) ->
      msg.send "Promoting #{this.release.Version} to #{targetEnvName}"
    .catch (error) ->
      msg.send error
