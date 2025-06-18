defmodule Smith.MemoryOS do
  use Ash.Domain

  @moduledoc """
  MemoryOS domain for memory management system in AI agents.

  This domain implements a sophisticated memory management system inspired by operating system principles,
  addressing the limitations of fixed context windows in Large Language Models (LLMs) by providing
  a hierarchical storage architecture and intelligent memory management.
  """

  resources do
    # STM (Short-Term Memory)
    resource Smith.MemoryOS.STM.DialoguePage

    # MTM (Mid-Term Memory)
    resource Smith.MemoryOS.MTM.DialogueSegment

    # LPM (Long-Term Personal Memory)
    resource Smith.MemoryOS.LPM.ObjectPersona
    resource Smith.MemoryOS.LPM.AgentPersona
    resource Smith.MemoryOS.LPM.KnowledgeBaseEntry
    resource Smith.MemoryOS.LPM.TraitEntry

    # System Memory
    resource Smith.MemoryOS.SystemMemory

    # Configuration
    resource Smith.MemoryOS.Configuration
  end
end
