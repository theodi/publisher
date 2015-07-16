require "workflow_actor"

module WorkflowActor
  # Monkey Patch to allow anyone to approve review
  # Required for issue theodi/shared#653
  def can_approve_review?(edition)
    logger.info("Authorising anyone to approve review!")
    true
  end
end
