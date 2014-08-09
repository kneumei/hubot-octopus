# Description:
#   Hubot interface to octopus deploy
#
# Commands:
#   hubot octo promote <project> from <env1> to <env2> - Hubot deploys the latest release of <project> on <env1> to <env2>
#
# Author:
#   kneumei


_ = require('underscore')._
q = require('q')

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

	createHTTPCall(robot, "/api/deployments")
		.post(JSON.stringify(deployment)) (err, res, body) ->
			if(err)
				deferred.reject err
			else
				deferred.resolve (JSON.parse body) 
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

mostRecentRelease = (robot, project) ->
	releasesUrl = project.Links["Releases"].replace /{.*}/, ""
	getItem(robot, releasesUrl, findByFirst())
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
