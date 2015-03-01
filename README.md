# README 

## Setting up the database

Open a bash session (`heroku run bash`) and run the migrations:

    sequel -m migrations $DATABASE_URL

Setting up a user is manual:

    sequel -I . -r models $DATABASE_URL
    > Author.create(:name => "name", :password => "password")

## Running the application

Make sure all environment variables listed in `.env.sample` are set. Then run
`rackup` or `foreman start`.

## Running the tests

Make sure the environment variable "DATABASE_URL" is configured.

    cutest test/*/*.rb
