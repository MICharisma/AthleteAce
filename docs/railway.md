# Deploy AthleteAce on Railway

Use the AthleteAce Railway project's `staging` environment for the first deployment.
Run Rails with `RAILS_ENV=production` in that environment. The application has no
separate Rails staging environment.

## Configure the services

Create a Postgres service and an `athleteace-staging` web service. Use the repository's
Dockerfile. It fetches the public seed catalog and importer at the commits recorded
by the application's submodules. When either submodule changes, update its Dockerfile
commit too. The private UGC backup repository is not required to boot the application.

Set these web-service variables:

| Variable | Value |
|---|---|
| `RAILS_ENV` | `production` |
| `RAILWAY_RUN_UID` | `0` |
| `PORT` | `3000` |
| `HTTP_PORT` | `80` |
| `SOLID_QUEUE_IN_PUMA` | `true` |
| `SKIP_SEEDS` | `1` |
| `SECRET_KEY_BASE` | A staging-only secret stored in Doppler `athleteace/stg` |
| `BUNDLE_GITHUB__COM` | `x-access-token:<read-only Rizz repository token>` from Doppler |
| `RIZZ_ENDPOINT` | The Rizz staging HTTPS origin |
| `RIZZ_SCOPE` | `athleteace.staging` |
| `RIZZ_API_TOKEN` | The separate AthleteAce client credential provisioned in Rizz |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` |
| `CACHE_DATABASE_URL` | `postgresql://${{Postgres.PGUSER}}:${{Postgres.PGPASSWORD}}@${{Postgres.PGHOST}}:${{Postgres.PGPORT}}/athleteace_staging_cache` |
| `QUEUE_DATABASE_URL` | `postgresql://${{Postgres.PGUSER}}:${{Postgres.PGPASSWORD}}@${{Postgres.PGHOST}}:${{Postgres.PGPORT}}/athleteace_staging_queue` |
| `CABLE_DATABASE_URL` | `postgresql://${{Postgres.PGUSER}}:${{Postgres.PGPASSWORD}}@${{Postgres.PGHOST}}:${{Postgres.PGPORT}}/athleteace_staging_cable` |

Set the Postgres service's `POSTGRES_DB` to `athleteace_staging`. Use separate
databases on the same server for the primary data, cache, queue, and cable schemas.
The Postgres role must be able to create the three additional databases.

Mount a persistent web-service volume at `/rails/storage`. `RAILWAY_RUN_UID=0` lets
the application write to Railway's root-owned volume, as described in
[Railway's volume permissions](https://docs.railway.com/volumes#permissions).
Route the public Railway
domain to port `80`. Set the health check to `/up` and the pre-deploy command to
`./bin/rails db:prepare`. `SKIP_SEEDS=1` leaves seed ingestion disabled while Rails
creates and migrates all four databases. After Rizz is ready and the consumer
connection is verified, run `SKIP_SEEDS=0 bin/rails db:seed` explicitly.

## Check the first deployment

Deploy the reviewed setup branch. Require a successful image build, database
creation and migration, and a `200` response from `/up`. A failed build, nonzero pre-deploy
exit, or another health response means the deployment failed. Check the home page
before importing seeds. After ingestion, check a seeded Figure or Team page.

Configure Google sign-in using [the Google sign-in instructions](google-sign-in.md).
Store `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` in Doppler `athleteace/stg`,
copy them to the Railway staging service, and register its HTTPS
`/aces/auth/google_oauth2/callback` redirect URL with Google. Google sign-in remains
disabled until both variables are present. Email confirmation also needs the
[production mail settings](play-learning.md).

The private Rizz client gem is pinned to its reviewed commit in the Gemfile. Keep
`SKIP_SEEDS=1` until Rizz is healthy, the AthleteAce credential works, and the Rizz
place catalog has been loaded. After importing seeds, use `rizz:sync_places` and
`rizz:sync_figures` to adopt the Rizz codes.
