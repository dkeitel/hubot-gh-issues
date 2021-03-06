fs = require 'fs'
path = require 'path'

DEFAULT_TOKEN = process.env.HUBOT_GH_ISSUES_DEFAULT_TOKEN

module.exports = (robot, scripts) ->
  scriptsPath = path.resolve(__dirname, 'src')
  fs.exists scriptsPath, (exists) ->
    if exists
      for script in fs.readdirSync(scriptsPath)
        if scripts? and '*' not in scripts
          robot.loadFile(scriptsPath, script) if script in scripts
        else
          robot.loadFile(scriptsPath, script)

  github = require 'octonode'

  githubTokenForUser = (msg) ->
    user = robot.brain.userForId msg.envelope.user.id
    token = robot.vault.forUser(user).get(robot.vault.key)
    return token if token?
    return DEFAULT_TOKEN if DEFAULT_TOKEN?
    msg.reply "I don't know your GitHub token. \nPlease generate one with the \"repo\" scope on https://github.com/settings/tokens and set it in a private message to me with the command: \"github token set <github_personal_access_token>\""

  robot.ghissues =
    searchIssues: (msg, repo, assignee, state, labels, keyword) ->
      token = githubTokenForUser msg
      if token?
        client = github.client token
        ghsearch = client.search repo
        query = keyword
        if assignee
          query += "+assignee:" + assignee
        if repo
          query += "+repo:" + repo
        if state
          query += "+state:" + state
        for label in labels
          query += "+label:" + label
        console.log query
        ghsearch.issues { "q": query, "sort": "created", "order": "asc"}, (err, data, headers) ->
          unless err?
            reply = "Found issues #{data.total_count} in #{repo}\n"
            for issue in data.items
              reply += "##{issue.number}: #{issue.title} (#{issue.state}) - #{issue.html_url}\n"
            msg.reply reply
          else
            msg.reply "Error from GitHub API: #{err.body.message}"
            return err

    openIssue: (msg, title, body, repo, labels) ->
      token = githubTokenForUser msg
      if token?
        client = github.client token
        ghrepo = client.repo repo
        ghrepo.issue { "title": title, "body": body, "labels": labels }
        , (err, data, headers) ->
          unless err?
            msg.reply "Created issue ##{data.number} in #{repo} - #{data.html_url}"
          else
            msg.reply "Error from GitHub API: #{err.body.message}"
            return err

    closeIssue: (msg, id, repo) ->
      token = githubTokenForUser msg
      if token?
        client = github.client token
        issue = client.issue repo, id
        issue.update { state: 'closed' }, (err, data, headers) ->
          unless err?
            msg.reply "Closed issue ##{id} in #{repo} - #{data.html_url}"
          else
            msg.reply "Error from GitHub API: #{err.body.message}"
            return err

    showIssue: (msg, id, repo) ->
      token = githubTokenForUser msg
      if token?
        client = github.client token
        issue = client.issue repo, id
        issue.info (err, data, headers) ->
          unless err?
            msg.reply "Issue ##{id} in #{repo} - #{data.title} (#{data.state}) - #{data.html_url}"
          else
            msg.reply "Error from GitHub API: #{err.body.message}"
            return err

    commentOnIssue: (msg, comment, id, repo) ->
      token = githubTokenForUser msg
      if token?
        client = github.client token
        issue = client.issue repo, id
        issue.createComment { body: comment }, (err, data, headers) ->
          unless err?
            msg.reply "Added comment to issue ##{id} in #{repo} - #{data.html_url}"
          else
            msg.reply "Error from GitHub API: #{err.body.message}"
            return err
