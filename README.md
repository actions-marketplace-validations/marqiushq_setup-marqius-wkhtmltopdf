# wkhtmltopdf alternative for GitHub Actions: install marqius-wkhtmltopdf

**Did your workflow start failing with this error?**

```text
Package wkhtmltopdf is not available, but is referred to by another package.
This may mean that the package is missing, has been obsoleted, or
is only available from another source

E: Package 'wkhtmltopdf' has no installation candidate
```

`ubuntu-latest` is now Ubuntu 26.04, and Ubuntu 26.04 has no wkhtmltopdf package. GitHub moved `ubuntu-latest` to Ubuntu 26.04 between 19 October and 19 November 2026 ([GitHub's notice](https://github.com/actions/runner-images/issues/14748)).

**The fix:** delete the step that runs `apt-get install wkhtmltopdf`, and put this step in its place:

```yaml
- uses: marqiushq/setup-marqius-wkhtmltopdf@v1
  with:
    wkhtmltopdf-names: true
```

That is all. Your scripts, tests and libraries keep running `wkhtmltopdf` as before: `wkhtmltopdf-names: true` gives the new program that name for the rest of the job. [Why this happens, and the fix for servers and Dockerfiles](https://marqius.com/blog/wkhtmltopdf-no-installation-candidate/)

## What this is

- **A GitHub Action** that installs marqius-wkhtmltopdf on your runner, in one step.
- **marqius-wkhtmltopdf replaces wkhtmltopdf.** It takes the same command line, the same options and the same HTML templates, so your code does not change. It is maintained; wkhtmltopdf was archived in January 2023.
- **It is new, not a copy.** marqius-wkhtmltopdf was written from scratch. It is not the old wkhtmltopdf code. It is one file, with nothing else to install: no X server, no Qt, no system libraries.
- **It is free for open-source projects,** with a free Community licence that you add in four steps. Businesses need a paid licence. See [Licence](#licence).
- **It runs on** Ubuntu 22.04, 24.04 and 26.04 runners (x86-64 and ARM64), and macOS runners on Apple silicon. Windows runners are not supported yet.

## Use it

```yaml
- uses: marqiushq/setup-marqius-wkhtmltopdf@v1
- run: |
    echo '<h1>Invoice 42</h1><p>Total €1,234.50</p>' > invoice.html
    marqius-wkhtmltopdf --page-size A4 invoice.html invoice.pdf
```

The first step installs the program. The second step makes a PDF with it, using wkhtmltopdf's own options.

## Licence

### Free for open-source and personal projects

The Community licence is free for personal projects, for teaching and learning, and for open-source projects, including their CI runs and documentation builds. Add it once, and every run of your workflow uses it:

1. Open [marqius.com/licence/marqius-wkhtmltopdf](https://marqius.com/licence/marqius-wkhtmltopdf), click **Get your free key**, and sign in with Google.
2. Tick "I'll use marqius-wkhtmltopdf only for personal, teaching or open-source work", click **Get my free key**, then **Copy key**.
3. In your repository on GitHub, open **Settings**, then **Secrets and variables**, then **Actions**. Click **New repository secret**, name it `MARQIUS_LICENCE`, paste the key, and click **Add secret**.
4. Give the secret to the job that makes PDFs:

```yaml
pdf:
  runs-on: ubuntu-latest
  env:
    MARQIUS_LICENCE: ${{ secrets.MARQIUS_LICENCE }}
  steps:
    - uses: marqiushq/setup-marqius-wkhtmltopdf@v1
    - run: marqius-wkhtmltopdf licence
```

`marqius-wkhtmltopdf licence` shows the licence in force. The key is valid for a year. When it has less than 30 days left, sign in again and click **Get a new key**.

### Paid for businesses

Anything done by or for a business, including internal tools and client work, needs a paid licence. [See the plans and prices](https://marqius.com/licence/marqius-wkhtmltopdf). Add the licence the same way, as the secret `MARQIUS_LICENCE`, for one repository or for your whole organisation.

The program reads the licence on the runner and never sends it anywhere. This action does not read it.

marqius-wkhtmltopdf is commercial software from Simple AI LLC. This action is open source under the MIT licence. marqius-wkhtmltopdf is not affiliated with the wkhtmltopdf project.

## Is it safe?

Yes, and you can check each point yourself. This section is for the person who approves what runs in your workflows.

**1. It never reads your secrets.** The action does not read `GITHUB_TOKEN`, a licence, or any other secret or token. Search its two files for "secret" or "token": there is no match.

**2. It is short and open.** The whole action is two files, under the MIT licence: [setup.sh](https://github.com/marqiushq/setup-marqius-wkhtmltopdf/blob/v1.0.0/setup.sh) (218 lines of shell) and [action.yml](https://github.com/marqiushq/setup-marqius-wkhtmltopdf/blob/v1.0.0/action.yml) (62 lines). You can read both in ten minutes.

**3. It talks to one website only.** It downloads from `https://marqius.com/download/`, over HTTPS only: the number of the latest release, the program's checksum, and the program. Nothing about your repository or your code is sent. To download from your own mirror instead, inside your network, set `MARQIUS_DOWNLOAD` to its address in the job's `env`.

**4. It checks every download.** Each program has a checksum (a fingerprint of its bytes) published beside it. If the download does not match it, the step stops, installs nothing, and shows both checksums. It also checks that the program says it is the release that was asked for.

**5. You can prove who built the program.** GitHub keeps a signed record of how each release was built, by the public workflow of [marqiushq/marqius-wkhtmltopdf](https://github.com/marqiushq/marqius-wkhtmltopdf) on GitHub's own machines. Check a program with the [GitHub CLI](https://cli.github.com/):

```bash
curl -fsSLO https://marqius.com/download/marqius-wkhtmltopdf/0.12.15/marqius-wkhtmltopdf-linux-x86_64
gh attestation verify marqius-wkhtmltopdf-linux-x86_64 -R marqiushq/marqius-wkhtmltopdf
```

It ends with `✓ Verification succeeded!`. If one byte of the file had changed, it would fail. The record is kept by GitHub, not by marqius.com, so a program swapped on the website would fail this check. Releases from 0.12.11 on have the record.

To run the same check in every workflow run, add one step after the action:

```yaml
- id: marqius
  uses: marqiushq/setup-marqius-wkhtmltopdf@v1
- name: Check that GitHub built this program
  env:
    GH_TOKEN: ${{ github.token }}
    PROGRAM: ${{ steps.marqius.outputs.path }}
  run: gh attestation verify "$PROGRAM" -R marqiushq/marqius-wkhtmltopdf
```

The token is your job's own, and only GitHub's `gh` command uses it, to read GitHub's record. This action never sees it.

**6. You can pin everything.** Pin the action to a commit, and the program to a release. Then nothing changes until you change these lines:

```yaml
- uses: marqiushq/setup-marqius-wkhtmltopdf@1a2e953786932b9b94679a4aa251cf29f3b39bad # v1.0.0
  with:
    version: 0.12.15
```

**7. It changes nothing else.** It puts the program on the PATH for this job only, and replaces nothing on the runner. The names `wkhtmltopdf` and `wkhtmltoimage` are added only when you ask for them, and a wkhtmltopdf already on the runner stays where it is. The only other action it uses is GitHub's own cache action, pinned to a commit.

**8. The program does not phone home.** When it makes a PDF, it loads only what your HTML links to, as wkhtmltopdf did. A licence is checked on the runner itself, and is never sent anywhere. The program goes online for anything else only when you ask it to: `marqius-wkhtmltopdf update` looks for a new release on GitHub, and `marqius-wkhtmltopdf fonts get` downloads open fonts.

**9. It is tested on every runner it supports,** on every change and on each new release of marqius-wkhtmltopdf: Ubuntu 22.04, 24.04 and 26.04 on x86-64 and ARM64, `ubuntu-slim`, and macOS 15 and 26. [See the tests](https://github.com/marqiushq/setup-marqius-wkhtmltopdf/blob/main/.github/workflows/test.yml).

Found a security problem? Write to hello@marqius.com.

## Keep the commands your application runs

With `wkhtmltopdf-names: true`, every library and script that runs `wkhtmltopdf` runs marqius-wkhtmltopdf, for the rest of the job.

```yaml
- uses: marqiushq/setup-marqius-wkhtmltopdf@v1
  with:
    wkhtmltopdf-names: true
- run: wkhtmltopdf -V
- run: marqius-wkhtmltopdf help python-pdfkit
```

`wkhtmltopdf -V` answers as wkhtmltopdf 0.12.6 with patched Qt does, then names marqius-wkhtmltopdf. `marqius-wkhtmltopdf help python-pdfkit` shows how python-pdfkit finds the program on this runner. `marqius-wkhtmltopdf help libraries` lists the others: imgkit, django-wkhtmltopdf, Snappy, laravel-snappy, KnpSnappyBundle, phpwkhtmltopdf, CakePdf, wicked_pdf, PDFKit for Ruby, wkhtmltopdf for Node, go-wkhtmltopdf, java-wkhtmltopdf-wrapper, pdf_generator and Rotativa.AspNetCore.

**Odoo** finds it by the name wkhtmltopdf too. Odoo 18 and 19 print their reports with it as they do with wkhtmltopdf. On Odoo 20 nothing is blocked, and three documents differ in layout ([the results](https://github.com/marqiushq/wkhtmltopdf-odoo-erpnext)).

## Name the program in a setting

The output `path` is the program's full path, for a library or setting that asks for one, such as Snappy's binary or a `WKHTMLTOPDF_PATH` your application reads:

```yaml
- id: marqius
  uses: marqiushq/setup-marqius-wkhtmltopdf@v1
- shell: bash
  env:
    WKHTMLTOPDF_PATH: ${{ steps.marqius.outputs.path }}
  run: |
    echo '<p>Statement for March</p>' > statement.html
    "$WKHTMLTOPDF_PATH" statement.html statement.pdf
```

## Stay on one release

`latest` moves to each new release of marqius-wkhtmltopdf. To stay on one release until you choose to move, name it:

```yaml
- uses: marqiushq/setup-marqius-wkhtmltopdf@v1
  with:
    version: 0.12.15
```

## Inputs and outputs

| Input | Default | What it does |
|---|---|---|
| `version` | `latest` | The release to install, such as `0.12.15` |
| `wkhtmltopdf-names` | `false` | `true` also gives the program the names `wkhtmltopdf` and `wkhtmltoimage`, for the rest of the job |

| Output | What it is |
|---|---|
| `path` | The program's full path |
| `version` | The release installed |
| `cache-hit` | `true` when the program came from the Actions cache |

## Other errors this step fixes

**Ubuntu 24.04's own wkhtmltopdf leaves out headers and footers:**

```text
The switch --footer-center, is not support using unpatched qt, and will be ignored.
```

Ubuntu builds wkhtmltopdf without "patched Qt", so headers, footers with page numbers and tables of contents are missing from the PDF. marqius-wkhtmltopdf makes them.

**The `wkhtmltopdf-binary` gem on Ubuntu 26.04:**

```text
Invalid platform, must be running on Ubuntu 16.04/18.04/20.04/22.04, …
```

The gem has no build for Ubuntu 26.04. Take it out of your Gemfile and use this step. [Why, and the fix](https://marqius.com/blog/wkhtmltopdf-binary-invalid-platform/)

**Old wkhtmltopdf builds on newer systems (Heroku-24, Ubuntu 22.04 and later, Debian 12 and later):**

```text
error while loading shared libraries: libssl.so.1.1: cannot open shared object file: No such file or directory
```

marqius-wkhtmltopdf needs no system library, so this cannot happen. [The Heroku-24 guide](https://marqius.com/blog/wkhtmltopdf-libssl-so-1-1/)

## If you want to keep the old wkhtmltopdf

- **Pin the runner** to `runs-on: ubuntu-24.04`. It still has the package, but built without patched Qt, so headers, footers with page numbers and tables of contents are left out. GitHub keeps only its two newest Ubuntu images, and retires `ubuntu-22.04` on 17 April 2027 ([the notice](https://github.com/actions/runner-images/issues/14254)).
- **Download wkhtmltopdf's last build.** It was made in May 2023, for Ubuntu 22.04 at the newest. There is none for 24.04 or 26.04 ([the builds](https://github.com/wkhtmltopdf/packaging/releases/tag/0.12.6.1-3)).

Neither will be fixed again: the wkhtmltopdf project was archived in January 2023, and its last release is from 2020.

## Questions

**How do I install wkhtmltopdf in GitHub Actions?** Add the step at the top of this page. Your job gets marqius-wkhtmltopdf, which takes wkhtmltopdf's options as they are. Add `wkhtmltopdf-names: true` when your code runs `wkhtmltopdf` by name.

**Why does `apt-get install wkhtmltopdf` fail on Ubuntu 26.04?** Ubuntu 26.04 has no wkhtmltopdf package, so the step stops with `E: Package 'wkhtmltopdf' has no installation candidate`. This action works on Ubuntu 22.04, 24.04 and 26.04 alike.

**Is marqius-wkhtmltopdf a drop-in replacement for wkhtmltopdf?** Yes. It takes wkhtmltopdf's command line and options as they are, and answers `wkhtmltopdf -V` as 0.12.6 does. The [wkhtmltopdf parity suite](https://github.com/marqiushq/wkhtmltopdf-parity) compares its PDFs with wkhtmltopdf's, document by document, for every release. The [wkhtmltopdf parity check](https://github.com/marqiushq/wkhtmltopdf-parity-check) runs the same comparison on your own templates, in every pull request.

**Does it work with my Python, PHP, Ruby, .NET, Node or Go library?** Yes. It is the program those libraries start, so pdfkit, Snappy, wicked_pdf, Rotativa, the Node wrapper and go-wkhtmltopdf keep their code and settings.

**Is it safe to add to a workflow that holds secrets?** Yes. The action never reads a secret or token, downloads only from marqius.com over HTTPS, checks every download, and the program's build can be proven with `gh attestation verify`. See [Is it safe?](#is-it-safe)

**Is it free for open-source projects?** Yes. The Community licence is free for personal projects, for teaching and learning, and for open-source projects, including their CI runs and documentation builds. [Add it in four steps](#free-for-open-source-and-personal-projects).

**Does my business need a licence?** Yes. Anything done by or for a business, including internal tools and client work, needs a paid licence. [See the plans and prices](https://marqius.com/licence/marqius-wkhtmltopdf).

## Before you switch

- [wkhtmltopdf parity check](https://github.com/marqiushq/wkhtmltopdf-parity-check): your own templates through wkhtmltopdf and marqius-wkhtmltopdf in every pull request, every page compared, and the build failed on the differences you choose.
- [wkhtmltopdf parity suite](https://github.com/marqiushq/wkhtmltopdf-parity): the same comparison for every release, in public.
- [Examples](https://github.com/marqiushq/marqius-wkhtmltopdf-examples) for 14 wkhtmltopdf libraries.
- [The switching manual](https://marqius.com/download/marqius-wkhtmltopdf/replace-wkhtmltopdf.pdf) (PDF).

Questions and help: hello@marqius.com, or [open an issue](https://github.com/marqiushq/setup-marqius-wkhtmltopdf/issues).
