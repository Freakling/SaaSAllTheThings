# Privacy policy

SaaSAllTheThings is a set of files and instructions that runs on your own machine. There is no SaaSAllTheThings service, account or server.

**What it reads.** Only your app's repository: its code, configuration, documents, records and git history, so the AI assistant you use can assess and build the app. It doesn't collect personal data such as names, emails or addresses. Your git name and email are used only by git itself, in your own commits. When it scans for secrets, it reports where one appears (file and line), never the value.

**What it writes.** Files in your app's repository: the workflow files, the product and architecture records, assessment reports, and the code and infrastructure files the assistant builds. Commits happen only when you approve them, and the project check's logs go under `.satt/state/`, which isn't committed. Its records name people by role, never by name, and keep customer details out of the repository.

**What it sends.** Nothing to us or to any other service. SaaSAllTheThings has no telemetry or analytics. It pushes to your git remote only when you ask. Commands that reach Azure, such as a deployment, run only with your approval, under your own Azure sign-in, against your own subscriptions. It never reads a secret's value and never creates credentials.

**Downloads.** When a skill runs without a local copy of SaaSAllTheThings (for example after `npx skills add`), it downloads SaaSAllTheThings from `https://github.com/Freakling/SaaSAllTheThings` with `git clone`. That is a download from GitHub, under GitHub's own terms; no project data is uploaded. The skills CLI (`npx skills`) is a separate tool, under its own terms.

**Your AI assistant.** The assistant you use (for example Claude Code) sends your conversation and the files it reads to its own provider, under that provider's terms and privacy policy. SaaSAllTheThings doesn't change what your assistant shares.

**Retention.** SaaSAllTheThings keeps nothing outside your repository. Delete the files to remove it.

**Contact.** Open an issue at https://github.com/Freakling/SaaSAllTheThings/issues.
