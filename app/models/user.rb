class User < ApplicationRecord
  # Initial balance for the first user
  INITIAL_USER_BALANCE_1 = 100

  # Initial balance for the second user
  INITIAL_USER_BALANCE_2 = 50

  # Sum of initial balances for verification
  INITIAL_USER_BALANCE_SUM = INITIAL_USER_BALANCE_1 + INITIAL_USER_BALANCE_2

  validates :balance, numericality: { greater_than_or_equal_to: 0 }

  class << self
    # Runs a simulation to test for race conditions in money transfers
    #
    # @param race_conditions [Boolean] whether to simulate without proper locking
    # @return [void]
    # @example
    #   User.simulation(race_conditions: false)
    #
    def simulation(race_conditions: false)
      prepare_db  # Reset database to initial state

      # Simulation parameters - increase for better chance of race conditions
      processes = 10
      iterations = 10

      pids = [] # Array to store child process IDs

      processes.times do |i|
        pids << fork do  # Create a new child process
          p "Started process ##{i}]"

          # Ensure each process has its own database connection
          ActiveRecord::Base.connection_pool.with_connection do
            t_start = Time.now
            iterations.times do |j|
              t_now = Time.now
              p "Started new iteration (process##{i} iteration##{j})"
              seconds = (t_now - t_start).round(2)
              p "Total time in seconds: #{seconds}"

              # Transfer money from first user to second user
              transfer_money_and_sum(
                from_user_id: User.first.id,
                to_user_id: User.second.id,
                amount: rand(1..INITIAL_USER_BALANCE_SUM),
                race_conditions:
              )

              # Transfer money from second user to first user
              transfer_money_and_sum(
                from_user_id: User.second.id,
                to_user_id: User.first.id,
                amount: rand(1..INITIAL_USER_BALANCE_SUM),
                race_conditions:
              )
            end
          end

          exit! 0 # Exit child process successfully
        end
      end

      # Wait for all child processes to complete
      pids.each { |pid| Process.wait(pid) }

      # Check if any incorrect sums were recorded (indicating race conditions)
      wrong_sums = Sum.where.not(value: INITIAL_USER_BALANCE_SUM).pluck(:value).as_json
      if wrong_sums.blank?
        p "✓ No race conditions happened"
      else
        p "!!! Race conditions happened"
        p "Wrong sums:"
        p wrong_sums # Display all incorrect sum values
      end
    end

    private

    # Calculates and stores the sum of balances for the first two users
    #
    # @return [void]
    #
    def record_balance_sum
      # ------------------------------
      # Original ActiveRecord approach (commented out) - vulnerable to race conditions
      # sum = User.first.balance + User.second.balance
      # Sum.create!(value: sum)

      # ------------------------------
      # Raw SQL approach - still vulnerable because it uses separate SELECT statements
      # even though it's a single query, the SELECTs can see different states

      sql = <<~SQL
        INSERT INTO sums(value, created_at, updated_at) VALUES (
          (
            (SELECT balance FROM users ORDER BY id ASC LIMIT 1) +
            (SELECT balance FROM users ORDER BY id ASC LIMIT 1 OFFSET 1)
          ),
          NOW(),
          NOW()
        ) RETURNING value;
      SQL
      result = ActiveRecord::Base.connection.execute(sql)
      sum = result[0]["value"] # Extract the calculated sum from result

      # Log if race condition detected (sum doesn't match expected total)
      if sum != INITIAL_USER_BALANCE_SUM
        p "!!! race condition (sum: #{sum})"
      end
    end

    # Transfers money between users and records the sum of balances
    #
    # @param from_user_id [Integer] id of the user to transfer money from
    # @param to_user_id [Integer] id of the user to transfer money to
    # @param amount [Integer] amount of money to transfer
    # @param race_conditions [Boolean] whether to use locking to prevent race conditions
    # @return [void]
    # @example
    #   transfer_money_and_sum(from_user_id: 1, to_user_id: 2, amount: 10, race_conditions: true)
    #
    def transfer_money_and_sum(from_user_id:, to_user_id:, amount:, race_conditions: false)
      # Wrap the entire operation in a database transaction
      User.transaction do
        # Fetch users with or without locking based on race_conditions flag
        from_user = if race_conditions
                      # Without locking - vulnerable to race conditions
                      User.find(from_user_id)
        else
                      # With locking - prevents race conditions using SELECT FOR UPDATE
                      User.lock.find(from_user_id)
        end

        to_user = if race_conditions
                    User.find(to_user_id)
        else
                    User.lock.find(to_user_id)
        end

        if from_user.balance >= amount
          from_user.update!(balance: from_user.balance - amount)

          to_user.update!(balance: to_user.balance + amount)

          # Record the current sum of balances
          record_balance_sum
        else
          # p "Not enough money"
        end
      end
    rescue ActiveRecord::Deadlocked
      # Suppress deadlock exceptions
      # p "deadlock"
    end

    # Prepares the database for simulation by clearing db tables and creating test records
    #
    # @note Deletes all Sum and User records, then creates two initial users
    # @return [void]
    #
    def prepare_db
      # Clear existing data
      Sum.delete_all
      User.delete_all

      # Create two initial users with predefined balances
      User.create!(name: "User1", balance: INITIAL_USER_BALANCE_1)
      User.create!(name: "User2", balance: INITIAL_USER_BALANCE_2)
    end
  end
end
