# Privacy policy

SaaSAllTheThings is a set of files and instructions that runs on your own machine. There is no SaaSAllTheThings service, account or server.

**What it reads.** Your app's repository: its code, configuration, documents, records and git history, so the AI assistant you use can assess and build the app. It doesn't collect personal data such as names, emails or addresses. Your git name and email are used only by git itself, in your own commits. When it scans for secrets, it reports where one appears (file and line), never the value. At session start a hook also reads the names, ids and ages of the processes on this machine, to report ones left running by an ended session. It stores nothing and sends nothing. To turn it off, set `SATT_ORPHAN_REPORT=0`.

**What it writes.** Files in your app's repository: the workflow files, the product and architecture records, assessment reports, and the code and infrastructure files the assistant builds. Commits happen only when you approve them, and the project check's logs go under `.satt/state/`, which isn't committed. Its records name people by role, never by name, and keep customer details out of the repository.

**What it sends.** Nothing to us or to any other service, apart from the release check below. SaaSAllTheThings has no telemetry or analytics. It pushes to your git remote only when you ask. Commands that reach Azure, such as a deployment, run only with your approval, under your own Azure sign-in, against your own subscriptions. It never reads a secret's value and never creates credentials.

**Downloads.** When a skill runs without a local copy of SaaSAllTheThings (for example after `npx skills add`), it downloads SaaSAllTheThings from `https://github.com/Freakling/SaaSAllTheThings` with `git clone`. That is a download from GitHub, under GitHub's own terms; no project data is uploaded. The skills CLI (`npx skills`) is a separate tool, under its own terms.

**Release check.** At session start, at most once a day, a hook reads the public list of SaaSAllTheThings's release tags from GitHub (`git ls-remote`), to tell you when the project is behind the latest release. It sends no project data; GitHub sees an ordinary request from your machine, under GitHub's terms. To turn it off, set `SATT_RELEASE_CHECK=0`, for example in `.claude/settings.local.json` › env.

**Your AI assistant.** The assistant you use (for example Claude Code) sends your conversation and the files it reads to its own provider, under that provider's terms and privacy policy. SaaSAllTheThings doesn't change what your assistant shares.

**Retention.** SaaSAllTheThings keeps nothing outside your repository. Delete the files to remove it.

**Contact.** Open an issue at https://github.com/Freakling/SaaSAllTheThings/issues.
