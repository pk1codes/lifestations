# Firebase directory

Deploy **from this directory** (`cd firebase`). Root `firebase.json` is FlutterFire metadata only.

## Setup

1. Replace `YOUR_FIREBASE_PROJECT_ID` in `.firebaserc` and `web_config.json`.
2. `npm --prefix functions install`
3. `npm --prefix scripts install`

## Commands

```bash
node --check functions/index.js
cd scripts && npm run prove:backend
cd scripts && npm run validate:333   # needs ../initial_seeds
```

Never commit Admin SDK JSON, `.env`, or webhook URLs. Set `GOOGLE_APPLICATION_CREDENTIALS` outside the repo when running Admin scripts.
