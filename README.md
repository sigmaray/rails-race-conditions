# README

Simulate race conditions in Ruby on Rails and PostgreSQL

https://github.com/sigmaray/rails-race-conditions/tree/race-conditions

https://github.com/sigmaray/rails-race-conditions/pull/2

## How ro run with Docker
```
# Setup docker containers
docker compose build

docker compose run app bundle exec rake simulation_without_race_conditions

docker compose run app bundle exec rake simulation_with_race_conditions
```

## How ro run without Docker
```
# Setup ruby, gems, db
rvm install 3.4.6
bundle install
rails db:prepare

rake simulation_without_race_conditions

rake simulation_with_race_conditions
```
