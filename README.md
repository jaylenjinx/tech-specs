# Tech specs

Lighting plots, patches and technical specs for Sydney venues, and the Venue Spec Pack site built from them.

**Site:** https://jaylenjinx.github.io/tech-specs/

## What's here

| Folder | Contents |
|---|---|
| [`site/`](site/) | The Venue Spec Pack site: plans, 3D views, patches, focus, MA3 CSV and MVR export. Deployed to GitHub Pages on every push that changes it. |
| [`venue-specs/ma3-plugin/`](venue-specs/ma3-plugin/) | grandMA3 plugins: `PatchExport.lua` saves the show's patch as CSV; `PatchImport.lua` reads the site's MA3 CSV and sets positions and focus, optionally patching missing fixtures as generic placeholders. |
| [`venue-specs/century-archive/`](venue-specs/century-archive/) | Century Venues documents (spec PDFs, plots, drawings) by venue. The photos and videos from the same source are not in the repo. |
| [`venue-specs/sydney-venues/`](venue-specs/sydney-venues/) | Specs for other Sydney venues, plus a Vectorworks model of Petersham Town Hall's hall and stage. See its README. |
| `venue-specs/enmore-2026`, `factory-2025`, `factory-2026`, `metro-2026`, `manning`, `concourse`, `dq` | Current specs, plots and patches per Century venue. |

## Adding a venue with the builder

[`site/builder.html`](https://jaylenjinx.github.io/tech-specs/builder.html) turns a lighting plot and a patch into a new venue tab, in the browser.

1. **Patch:** a CSV or XLSX sheet, a Venue Patch Export CSV from MA3, a text-based PDF table, or an MVR. Columns are guessed from the headers and can be remapped.
2. **Plot:** a PDF (its text is read directly) or an image (read with OCR). Labels that match patch IDs, or DMX addresses, place fixtures. Plots with no ID labels fall back to the bar labels (LX1, FOH Truss) and the patch's location column.
3. **Fix:** mark the downstage edge to set the scale, then drag, add, retype or delete fixtures and name the bars.
4. **Export:** *Preview on the site* shows the draft in the real page. *Download for the repo* gives a zip to unzip in this folder: it adds `site/venues/<id>.json`, the plot image and an updated `site/venues/index.json`. Commit and push to publish.

## Petersham Town Hall model

`venue-specs/sydney-venues/Petersham Town Hall/build_petersham_vw.py` builds the model in Vectorworks 2027 from the council floor plan. The stage height (1.0 m) and proscenium height (6.5 m) are assumptions; change the constants at the top of the script and re-run it in a blank document.

Documents belong to their venues and are collected here for reference.
