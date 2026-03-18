# @spree/cli

## 2.0.0

### Minor Changes

- Add `spree eject` command to switch from prebuilt Docker image to building from local `backend/` directory. Also update port detection to read `SPREE_PORT` from `.env`.

## 2.0.0-beta.5

### Patch Changes

- Automatically update storefront `.env.local` with the real API key during `spree init`

## 2.0.0-beta.4

### Patch Changes

- Pull latest Docker image during `spree init` to ensure fresh setups always use the newest version
- Show Docker pull progress output during `spree init` and `spree update` instead of a spinner
