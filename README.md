# Set up marqius-wkhtmltopdf

**HTML to PDF in GitHub Actions, with a maintained wkhtmltopdf alternative.** This action installs marqius-wkhtmltopdf, the drop-in replacement for wkhtmltopdf, on Linux and macOS runners in one step. It reads wkhtmltopdf's command line as it is, so the invoices, statements and reports your pipeline makes keep their templates, their options and the code that calls them.

```yaml
- uses: marqiushq/setup-marqius-wkhtmltopdf@v1
- run: |
    echo '<h1>Invoice 42</h1><p>Total €1,234.50</p>' > invoice.html
    marqius-wkhtmltopdf --page-size A4 invoice.html invoice.pdf
```

- **Linux and macOS runners.** Linux on x86-64 and ARM64, macOS on Apple silicon. Windows runners are not supported yet.
- **Checked every time.** Before it runs, the build is checked against the checksum published beside it on marqius.com, whether it was just downloaded or came from the cache.
- **Quick after the first run.** The build is kept in the Actions cache, so later runs start without downloading it.
- **Nothing replaced.** Nothing already on the runner changes. The names wkhtmltopdf and wkhtmltoimage are added for the job only when you ask for them.

## Why teams move their pipelines

wkhtmltopdf is no longer maintained, and the runners are leaving it behind. Ubuntu 26.04 has no wkhtmltopdf package, so a workflow that installs it with `apt-get` stops working on `ubuntu-26.04`, and on `ubuntu-latest` once that moves to 26.04. marqius-wkhtmltopdf is maintained, a single file with nothing else to install, and many times faster than wkhtmltopdf. The [wkhtmltopdf parity suite](https://github.com/marqiushq/wkhtmltopdf-parity) measures both programs on every release, misses included.

## Keep the commands your application runs

With `wkhtmltopdf-names: true`, libraries and scripts that run `wkhtmltopdf` run marqius-wkhtmltopdf for the rest of the job. A wkhtmltopdf already on the runner stays where it is.

```yaml
- uses: marqiushq/setup-marqius-wkhtmltopdf@v1
  with:
    wkhtmltopdf-names: true
- run: wkhtmltopdf -V
- run: marqius-wkhtmltopdf help python-pdfkit
```

`wkhtmltopdf -V` answers as wkhtmltopdf 0.12.6 does, then names marqius-wkhtmltopdf. `marqius-wkhtmltopdf help python-pdfkit` shows how python-pdfkit finds the program, with this runner's paths, and `marqius-wkhtmltopdf help libraries` lists the other libraries it knows, from Snappy and wicked_pdf to Rotativa.

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
