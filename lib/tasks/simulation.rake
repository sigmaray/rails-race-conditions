task simulation_without_race_conditions: :environment  do
  User.simulation(race_conditions: false)
end

task simulation_with_race_conditions: :environment  do
  User.simulation(race_conditions: true)
end
