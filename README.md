# README 

## Setting up the database

    sequel -m migrations $DATABASE_URL

## Running the tests

Make sure the environment variable "DATABASE_URL" is configured.

    cutest test/*/*.rb
