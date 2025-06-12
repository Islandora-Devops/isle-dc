# Welcome!

If you are reading this document then you are interested in contributing to ISLE, and that's awesome! All contributions are welcome: use-cases, documentation, code, patches, bug reports, feature requests, etc. You do not need to be a programmer to speak up!

We also have a Slack channel [#isle](https://islandora.slack.com/archives/CM6F4C4VA) on the [Islandora Slack](https://islandora.slack.com). Feel free to hang out there, ask questions, and help others out if you can.

## Workflows

For guidance or assistance, jump in the Slack channel above and ask before getting started!

### Documentation

* All documentation for this project can be found within the `docs` directory.

### Request a new feature (use cases).

To request a new feature you should [open an issue](https://github.com/Islandora-Devops/isle-dc/issues). You will need a Github account to do this. If you don't have one, you can sign up [here](https://github.com). If you are able, set an Issue Label of "New Feature".

In order to help us understand the feature request, it would be great if you could provide us with a use case:

| Title (Goal)  | The title or goal of your use case                               |
--------------- |------------------------------------------------------------------|
| Primary Actor | Repository architect, implementer, repository admin, user        |
| Scope         | The scope of the project. Example: architecture, access          |
| Level         | The priority the use case should be given; High, Medium, Low     |
| Story         | Provide a [user story](http://en.wikipedia.org/wiki/User_story). |

----

**Examples**:
* Bullet
* Listed
* Examples should you want to provide them.

**Remarks**:
* Bullet
* Listed
* Remarks should you want to provide them.

### Report a bug

To report a bug you should [open an issue](https://github.com/Islandora-Devops/isle-dc/issues) summarizing the bug. If you are able, set an Issue Label to "Bug".

In order to help us understand and fix the bug please provide:

1. The steps to reproduce the bug. This includes information about e.g. the ISLE and Islandora version you were using along with version of stack components.
2. The expected behavior.
3. The actual, incorrect behavior.

Feel free to search the issue queue for existing issues (aka tickets) that already describe the problem; if there is such a ticket please add your information as a comment.

**If you want to provide a pull request along with your issue:**

That is great! In this case please send us a pull request as described in section _Create a pull request_ below.

### Participate in a Release

[TO DO] - Project currently not at this phase.

### Contribute code

Before your code changes can be accepted, you must have completed a Contributor License Agreement. See [License Agreements](#license-agreements) below.

_If you are interested in contributing code to ISLE 8 but do not know where to begin:_

In this case you should [browse open issues](https://github.com/Islandora-Devops/isle-dc/issues).

Contributions to the ISLE 8 codebase should be sent as GitHub pull requests. See section _Create a pull request_ below for details. If there is any problem with the pull request we can work through it using the commenting features of GitHub.

* For _small changes_, feel free to submit pull requests directly for those patches.
* For _larger code changes_, please use the following process. The idea behind this process is to prevent any wasted work and catch design issues early on.

    1. [Open an issue](https://github.com/Islandora-Devops/isle-dc/issues), if a similar issue does not exist already. If a similar issue does exist, then you may consider participating in the work on the existing issue.
    2. Comment on the issue with your plan for implementing the issue. Explain what pieces of the codebase you are going to touch and how everything is going to fit together.
    3. ISLE committers will work with you on the design to make sure you are on the right track.
    4. Implement your issue, create a pull request (see below), and iterate from there.

Developer questions? We have a lot of excellent developer documentation that can be found ... [TO DO]

#### Issue / Topic Branches

All Github issues should be worked on in separate git branches. The branch name should be the same as the Github issue number, including all-caps, so ISLE-153, ISLE-118, etc.

Example: `git checkout -b 7.x-ISLE-977` or `git checkout -b 7.x-1.4-ISLE-977`

### Create a pull request

Take a look at [Creating a pull request](https://help.github.com/articles/creating-a-pull-request). In a nutshell you need to:

1. [Fork](https://help.github.com/articles/fork-a-repo) a given ISLE component repository at [https://github.com/Islandora-Devops/isle-dc](https://github.com/Islandora-Devops/isle-dc) to your personal GitHub account. See [Fork a repo](https://help.github.com/articles/fork-a-repo) for detailed instructions.
2. Commit any changes to your fork.
3. Send a [pull request](https://help.github.com/articles/creating-a-pull-request) to the Islandora GitHub repository that you forked in step 1. If your pull request is related to an existing Github issue - for instance, because you reported a bug/issue earlier - then prefix the title of your pull request with the corresponding issue number (e.g. `ISLE-123: ...`). The branch name should also correspond to the Github issue number.

You may want to read [Syncing a fork](https://help.github.com/articles/syncing-a-fork) for instructions on how to keep your fork up to date with the latest changes of the upstream (official) `isle-dc` repository.

Community members who have push/merge permissions on a repository should **never** push directly to a repo, nor merge their own pull requests.

#### Release branch pull requests

TBD

## Contributor License Agreements

The Islandora Foundation requires that contributors either complete an **Individual Contributor License Agreement** or be covered by a **Corporate Contributor License Agreement**. This agreement is for your protection as a contributor as well as the protection of the Foundation and its users; it does not change your rights to use your own contributions for any other purpose.

**To complete a Contributor License Agreement (Individual or Corporate), please click [**HERE**](https://forms.gle/kS6BKhaf5LBzNvj18) to be taken to the Google Form.**
