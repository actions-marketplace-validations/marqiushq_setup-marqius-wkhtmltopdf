# wkhtmltopdf alternative: install marqius-wkhtmltopdf

**Install wkhtmltopdf in GitHub Actions the way that still works: as marqius-wkhtmltopdf, its maintained drop-in replacement.** One step puts it on Linux and macOS runners. It reads wkhtmltopdf's command line as it is, so your HTML to PDF jobs keep their templates, their options and the libraries that call wkhtmltopdf, from pdfkit and wicked_pdf to Snappy, Rotativa and Odoo.

```yaml
- uses: marqiushq/setup-marqius-wkhtmltopdf@v1
- run: |
    echo '<h1>Invoice 42</h1><p>Total €1,234.50</p>' > invoice.html
    marqius-wkhtmltopdf --page-size A4 invoice.html invoice.pdf
```

- **Installs where wkhtmltopdf no longer does.** Ubuntu 26.04 has no wkhtmltopdf package, wkhtmltopdf's own builds stop at Ubuntu 22.04, and its project is archived: its last release, 0.12.6, came out in 2020.
- **One file, nothing else.** No X server, no Qt, no shared libraries to install: the errors "cannot connect to X server" and "error while loading shared libraries" do not arise.
- **The full feature set.** Headers and footers with page numbers, tables of contents and outlines work as they did in wkhtmltopdf with patched Qt, which Ubuntu's own wkhtmltopdf package lacks.
- **Many times faster.** The [wkhtmltopdf parity suite](https://github.com/marqiushq/wkhtmltopdf-parity) measures both programs on the same documents for every release, misses included.
- **Checked and cached.** Each run checks the build against the checksum published beside it on marqius.com, and the Actions cache keeps it for the next run.
- **Nothing replaced.** Nothing already on the runner changes. The names wkhtmltopdf and wkhtmltoimage are added for the job only when you ask for them.

Linux runners on x86-64 and ARM64, and macOS runners on Apple silicon, need no `apt-get`, `brew install wkhtmltopdf` or `.deb` download. Windows runners are not supported yet.

## Keep the commands your application runs

With `wkhtmltopdf-names: true`, libraries and scripts that run `wkhtmltopdf` run marqius-wkhtmltopdf for the rest of the job. A wkhtmltopdf already on the runner stays where it is.

```yaml
- uses: marqiushq/setup-marqius-wkhtmltopdf@v1
  with:
    wkhtmltopdf-names: true
- run: wkhtmltopdf -V
- run: marqius-wkhtmltopdf help python-pdfkit
```

`wkhtmltopdf -V` answers as wkhtmltopdf 0.12.6 with patched Qt does, then names marqius-wkhtmltopdf. `marqius-wkhtmltopdf help python-pdfkit` shows how python-pdfkit finds the program, with this runner's paths, and `marqius-wkhtmltopdf help libraries` lists the others: imgkit, django-wkhtmltopdf, Snappy, laravel-snappy, KnpSnappyBundle, phpwkhtmltopdf, CakePdf, wicked_pdf, PDFKit for Ruby, wkhtmltopdf for Node, go-wkhtmltopdf, java-wkhtmltopdf-wrapper, pdf_generator and Rotativa.AspNetCore.

**Odoo** finds it under the name wkhtmltopdf too, and Odoo 19 and 20 print their reports with it as they do with wkhtmltopdf, so the report tests of your Odoo modules run on any runner.

## Name the program in a setting

The output `path` is the program's full path, for libraries and settings that take one, such as Snappy's binary or a `WKHTMLTOPDF_PATH` your application reads:

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

`latest` moves to each new release of marqius-wkhtmltopdf. To stay on one until you choose to move:

```yaml
- uses: marqiushq/setup-marqius-wkhtmltopdf@v1
  with:
    version: 0.12.9
```

## Inputs and outputs

| Input | Default | What it is |
|---|---|---|
| `version` | `latest` | The release to install, such as `0.12.9` |
| `wkhtmltopdf-names` | `false` | `true` also gives it the names `wkhtmltopdf` and `wkhtmltoimage` for the rest of the job, through `marqius-wkhtmltopdf install` |

| Output | What it is |
|---|---|
| `path` | The full path of the program |
| `version` | The release installed |
| `cache-hit` | `true` when the program came from the Actions cache |

## Questions

**How do I install wkhtmltopdf in GitHub Actions?** Add the step at the top of this page. Your job gets marqius-wkhtmltopdf, which reads wkhtmltopdf's options as they are; add `wkhtmltopdf-names: true` when your code runs `wkhtmltopdf` by name.

**Why does `apt-get install wkhtmltopdf` fail on Ubuntu 26.04?** Ubuntu 26.04 has no wkhtmltopdf package, so a workflow that installs it with `apt-get` stops working on `ubuntu-26.04`, and on `ubuntu-latest` once that moves to 26.04. The wkhtmltopdf builds with patched Qt that many workflows download stop at Ubuntu 22.04. This action works on 22.04, 24.04 and 26.04 alike.

**Is marqius-wkhtmltopdf a drop-in replacement for wkhtmltopdf?** It reads wkhtmltopdf's command line and options as they are and answers `wkhtmltopdf -V` as 0.12.6 does. The [wkhtmltopdf parity suite](https://github.com/marqiushq/wkhtmltopdf-parity) shows how closely its PDFs match wkhtmltopdf's, document by document, and the [wkhtmltopdf parity check](https://github.com/marqiushq/wkhtmltopdf-parity-check) runs the same comparison on your own templates in every pull request.

**Is it a wkhtmltopdf alternative for Python, PHP, Ruby, .NET, Node and Go?** Yes: it is the program those libraries start, so pdfkit, Snappy, wicked_pdf, Rotativa, the Node wrapper and go-wkhtmltopdf keep their code and settings.

**What does it cost?** It is free for 30 days from its first run, then licensed: see the licence below.

## Licence

marqius-wkhtmltopdf is commercial software from Simple AI LLC, with a 30-day free trial counted from its first run. After the trial, without a licence, each page carries one line saying the copy is unlicensed; it never stops making PDFs. Keep your licence in a secret named `MARQIUS_LICENCE`, for the repository or the organisation, and give it to the job:

```yaml
pdf:
  runs-on: ubuntu-latest
  env:
    MARQIUS_LICENCE: ${{ secrets.MARQIUS_LICENCE }}
  steps:
    - uses: marqiushq/setup-marqius-wkhtmltopdf@v1
    - run: marqius-wkhtmltopdf licence
```

`marqius-wkhtmltopdf licence` shows the licence in force. [Plans and licences](https://marqius.com/wkhtmltopdf/) · [Licence terms](https://marqius.com/licence/marqius-wkhtmltopdf)

This action is open source under the MIT licence. marqius-wkhtmltopdf is not affiliated with the wkhtmltopdf project.

## What it sends

Only its download requests to marqius.com: which release is the latest, the checksum and, when the cache does not have it, the build. They name this action, and nothing about your repository or your code. A mirror inside your firewall, with the files of marqius.com/download/marqius-wkhtmltopdf laid out the same way, can stand in for marqius.com: set `MARQIUS_DOWNLOAD` to its address in the step's `env`.

## Before you switch

- [wkhtmltopdf parity check](https://github.com/marqiushq/wkhtmltopdf-parity-check): your own templates through wkhtmltopdf and marqius-wkhtmltopdf in every pull request, every page compared, and the build failed on the differences you choose.
- [wkhtmltopdf parity suite](https://github.com/marqiushq/wkhtmltopdf-parity): the same comparison for every release, in public.
- [Integration examples](https://github.com/marqiushq/marqius-wkhtmltopdf-examples) for 14 wkhtmltopdf libraries.
- [The switching manual](https://marqius.com/download/marqius-wkhtmltopdf/replace-wkhtmltopdf.pdf) (PDF).

Questions and help: hello@marqius.com, or [an issue](https://github.com/marqiushq/setup-marqius-wkhtmltopdf/issues).
