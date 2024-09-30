# Custom-callouts Extension For Quarto

Add custom callouts to your Quarto documents.

## Installing

```bash
quarto add cbcGirard/quarto-custom-callouts
```

This will install the extension under the `_extensions` subdirectory.
If you're using version control, you will want to check in this directory.

## Using

Add to your document metadata:

```yaml
filters:
  - custom-callouts
```

See the [example](example.qmd) for details on defining callouts in the metadata and using them in the document.