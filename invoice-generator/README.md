# Invoice Studio

A professional invoice generator that runs entirely in the browser. No sign-up, no server, no monthly fees. Open `index.html` and start invoicing.

## Features
- Live A4 preview in two templates (Classic and Modern)
- 10 accent colours plus a custom colour picker
- Logo upload (automatically resized)
- Unlimited line items with quantity × rate
- Tax/VAT (custom label), discount %, shipping/fees, deposit/amount paid
- 19 currencies, formatted automatically for the viewer's locale
- "PAID" stamp toggle
- One-click **Download PDF** (A4, print-ready)
- Autosaves in the browser; **New** keeps your business details and moves to the next invoice number
- Export/import invoices as `.json` files
- Light/dark editor, works on phones

## Use
Open `index.html` in any modern browser. To download a PDF, click **Download PDF** and choose "Save as PDF".
(Tip: turn on "Background graphics" in the print dialog if colours are missing.)

## Host it free
Upload the folder to GitHub Pages, Netlify Drop or Vercel. It's one file with no build step.

## Customise
Everything is in `index.html`:
- Colours: the `COLORS` array and the `:root` CSS variables
- Currencies: the `CURRENCIES` array
- Default text: the `blank()` function

## Licence (for buyers)
Personal and commercial use are allowed, including for client projects. You may not resell or redistribute the source code as-is.
