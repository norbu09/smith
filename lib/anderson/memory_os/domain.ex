defmodule Anderson.MemoryOS do
  use Ash.Domain

  @moduledoc """
  MemoryOS domain for memory management system in AI agents.

  This domain implements a sophisticated memory management system inspired by operating system principles,
  addressing the limitations of fixed context windows in Large Language Models (LLMs) by providing
  a hierarchical storage architecture and intelligent memory management.
  """

  resources do
    # STM (Short-Term Memory)
    resource Anderson.MemoryOS.STM.DialoguePage

    # MTM (Mid-Term Memory)
    resource Anderson.MemoryOS.MTM.DialogueSegment

    # LPM (Long-Term Personal Memory)
    resource Anderson.MemoryOS.LPM.ObjectPersona
    resource Anderson.MemoryOS.LPM.AgentPersona
    resource Anderson.MemoryOS.LPM.KnowledgeBaseEntry
    resource Anderson.MemoryOS.LPM.TraitEntry

    # System Memory
    resource Anderson.MemoryOS.SystemMemory

    # Configuration
    resource Anderson.MemoryOS.Configuration
  end
end
