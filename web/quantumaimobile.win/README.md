# quantumaimobile.win

Static Cloudflare Pages package for `https://www.quantumaimobile.win/`.

## Structure

- `public/index.html`: landing page
- `public/architecture.html`: system architecture
- `public/runtime.html`: runtime and observability stack
- `public/mobile.html`: iOS surfaces and physical-device lane
- `public/roadmap.html`: rollout and deployment roadmap
- `public/assets/styles.css`: shared styling
- `public/assets/app.js`: nav highlighting, EN/TR language switch, meta/title sync
- `public/_headers`: security headers
- `wrangler.toml`: Cloudflare Pages config

## Deploy

```bash
cd web/quantumaimobile.win
npx wrangler whoami
npx wrangler pages deploy public --project-name quantumaimobile-win
```

Or:

```bash
cd web/quantumaimobile.win
./deploy.sh
```

## Notes

- The static package is bilingual and switches between English and Turkish in-browser.
- Production deploys publish to the `quantumaimobile-win` Pages project.
- Custom domain binding is still a separate Cloudflare Pages step even after a successful deploy.

## Domain binding

Attach these custom domains in Cloudflare Pages:

- `quantumaimobile.win`
- `www.quantumaimobile.win`

Cloudflare account id:

- `c3df6d40a60e5c69d1c94c8efeb0dd77`

Cloudflare zone id:

- `Dfe33275529c653990697ae56c01c005`
