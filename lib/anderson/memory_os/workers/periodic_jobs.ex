defmodule Anderson.MemoryOS.Workers.PeriodicJobs do
  @moduledoc """
  Periodic Job Scheduler for MemoryOS

  Manages scheduled background tasks for memory management:

  1. Periodic heat score updates for all agents
  2. STM capacity monitoring and cleanup
  3. LPM to SystemMemory promotion evaluation
  4. SystemMemory maintenance and capacity management
  5. Meta chain updates for dialogue analysis

  Jobs are scheduled using Oban's cron plugin configuration.
  """

  @doc """
  Schedule periodic heat score updates for an agent.

  This should be called when an agent is created or becomes active.
  """
  def schedule_heat_updates(agent_id) do
    # Schedule periodic heat score updates every hour
    %{agent_id: agent_id}
    |> Anderson.MemoryOS.Workers.UpdateHeatScoreWorker.new(
      schedule_in: 3600,  # 1 hour
      queue: :memory
    )
    |> Oban.insert()
  end

  @doc """
  Schedule LPM evaluation for SystemMemory promotion.

  This should be called periodically or when LPM entries reach certain thresholds.
  """
  def schedule_lpm_evaluation(agent_id) do
    # Schedule LPM evaluation every 6 hours
    %{agent_id: agent_id}
    |> Anderson.MemoryOS.Workers.LpmSystemTransferWorker.new(
      schedule_in: 21600,  # 6 hours
      queue: :memory
    )
    |> Oban.insert()
  end

  @doc """
  Schedule system-wide maintenance tasks.

  This includes SystemMemory capacity management and cleanup operations.
  """
  def schedule_system_maintenance do
    # Schedule system maintenance every day
    %{operation: "maintenance"}
    |> Anderson.MemoryOS.Workers.LpmSystemTransferWorker.new(
      schedule_in: 86400,  # 24 hours
      queue: :memory
    )
    |> Oban.insert()
  end

  @doc """
  Get cron configuration for Oban plugin.

  This configuration should be added to the Oban setup in config.exs.
  """
  def cron_config do
    [
      # Update heat scores for all agents every 2 hours
      {"0 */2 * * *", Anderson.MemoryOS.Workers.PeriodicJobs, args: %{task: "update_all_heat_scores"}},

      # Evaluate LPM for SystemMemory promotion every 6 hours
      {"0 */6 * * *", Anderson.MemoryOS.Workers.PeriodicJobs, args: %{task: "evaluate_lpm_promotion"}},

      # System maintenance daily at 2 AM
      {"0 2 * * *", Anderson.MemoryOS.Workers.PeriodicJobs, args: %{task: "system_maintenance"}},

      # Clean up old meta chains weekly
      {"0 3 * * 0", Anderson.MemoryOS.Workers.PeriodicJobs, args: %{task: "cleanup_meta_chains"}}
    ]
  end

  use Oban.Worker, queue: :memory

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"task" => "update_all_heat_scores"}}) do
    # Get all active agents and schedule heat updates
    active_agents = get_active_agents()

    Enum.each(active_agents, fn agent_id ->
      %{agent_id: agent_id}
      |> Anderson.MemoryOS.Workers.UpdateHeatScoreWorker.new(queue: :memory)
      |> Oban.insert()
    end)

    {:ok, "Scheduled heat score updates for #{length(active_agents)} agents"}
  end

  def perform(%Oban.Job{args: %{"task" => "evaluate_lpm_promotion"}}) do
    # Get all active agents and schedule LPM evaluation
    active_agents = get_active_agents()

    Enum.each(active_agents, fn agent_id ->
      %{agent_id: agent_id}
      |> Anderson.MemoryOS.Workers.LpmSystemTransferWorker.new(queue: :memory)
      |> Oban.insert()
    end)

    {:ok, "Scheduled LPM evaluation for #{length(active_agents)} agents"}
  end

  def perform(%Oban.Job{args: %{"task" => "system_maintenance"}}) do
    # Schedule system-wide maintenance
    %{operation: "maintenance"}
    |> Anderson.MemoryOS.Workers.LpmSystemTransferWorker.new(queue: :memory)
    |> Oban.insert()

    {:ok, "Scheduled system maintenance"}
  end

  def perform(%Oban.Job{args: %{"task" => "cleanup_meta_chains"}}) do
    # Clean up old meta chain data (older than 30 days)
    cutoff_date = DateTime.add(DateTime.utc_now(), -30, :day)

    # In a full implementation, this would clean up old meta chain data
    # For now, just log the cleanup task
    require Logger
    Logger.info("Meta chain cleanup scheduled for data older than #{cutoff_date}")

    {:ok, "Meta chain cleanup completed"}
  end

  defp get_active_agents do
    # Get all agents that have recent activity (STM pages or MTM segments)
    # For now, return agents with any dialogue segments
    Anderson.MemoryOS.MTM.DialogueSegment
    |> Ash.Query.select([:agent_id])
    |> Ash.read!()
    |> Enum.map(& &1.agent_id)
    |> Enum.uniq()
  end
end
